# Phân Tích Điểm Bất Thường Trong Training Log

## 1. ❌ CRITICAL: draw=0.0% suốt quá trình training

**Triệu chứng:**
- Từ gen 1→45+, `draw=0.0%` không bao giờ thay đổi
- Trong cờ vua self-play, tỷ lệ hòa thường 20-40%

**Nguyên nhân (colab_selfplay_pipeline.py:486-538):**
```python
draws = (values == 0.0)              # Line 486: Detect draws TRƯỚC khi xử lý
# ... 50 dòng code xử lý ...
values[draws] = BASE_DRAW_PENALTY + material_adj  # Line 533: Transform draws → -0.4
```

- `load_generation_samples()` detect draws với `values == 0.0`
- Sau đó apply draw penalty, biến tất cả draw values thành ~-0.4
- Khi `train_policy_model()` tính `draw_rate`, nó check processed data → không còn giá trị nào = 0.0
- **Kết quả: draw_rate luôn = 0%**

**Hệ quả cascading:**
1. Dynamic value_weight (line 738-740) phụ thuộc vào draw_rate → luôn = 1.5
2. Model không học được phân biệt draw vs win/loss
3. MCTS exploration bị sai lệch

---

## 2. ❌ Value Loss Collapse → 0.0000

**Triệu chứng:**
- Gen 9: `value=0.0027 → 0.0000 → 0.0000 → 0.0000`
- Gen 18-27: `value=0.0000` liên tục
- Gen 10: spike `0.0192 → 0.2281 → 0.0192 → 0.0192` (không ổn định)

**Nguyên nhân:**
1. **Weighted value loss (line 730-735)** cho 100x weight cho decisive positions (|value|>0.5)
   - Draw positions (value=-0.4) chỉ có weight=1.0
   - Model học predict gần mean của data → collapse
2. **Không có value noise** trong training
3. **Không có value collapse detection** trong training loop

**Hệ quả:**
- Value head predict cùng 1 giá trị cho mọi position
- MCTS evaluation không reliable
- Model không học được position evaluation

---

## 3. ⚠️ Sample Count Stuck at 20800

**Triệu chứng:**
- Gen 1-8: samples tăng (2452 → 5036 → ... → 20626)
- Gen 9+: cố định 20800

**Nguyên nhân (colab_selfplay_pipeline.py:561-565):**
```python
MAX_REPLAY_SAMPLES = 200_000
if states_np.shape[0] > MAX_REPLAY_SAMPLES:
    states_np = states_np[-MAX_REPLAY_SAMPLES:]  # Keep latest 200k
```

- `select_replay_files()` giới hạn `max_files=10` generations gần nhất
- 10 games × ~2600 samples/game ≈ 26000 samples
- Một số samples bị filter → stabilize ở ~20800

**Đánh giá:** Behavior này là **EXPECTED** - replay buffer window để tránh overfitting data cũ

---

## 4. ❌ vw=1.5 Không Đổi

**Triệu chứng:**
- Dynamic value_weight luôn = 1.5 suốt 45+ generations

**Nguyên nhân (line 738-740, 758-759, 790-792):**
```python
_vw = 3.0 if draw_rate > 0.85 else (2.0 if draw_rate > 0.70 else 1.5)
```

- Phụ thuộc vào `draw_rate`
- `draw_rate` luôn = 0% (do Bug #1)
- **→ vw luôn = 1.5 (branch cuối cùng)**

**Hệ quả:**
- Value loss không được weighted đủ khi có nhiều draws
- Model không ưu tiên học value head khi cần

---

## 5. ❌ Value Loss Instability

**Triệu chứng:**
- Gen 10: `0.0192 → 0.2281 → 0.0192 → 0.0192`
- Gen 17: `0.1537 → 0.1537 → 0.1537 → 0.2241`
- Gen 29: `0.0000 → 0.0000 → 0.0388 → 0.0963`

**Nguyên nhân:**
- Value head đang oscillate giữa các local minima
- Không có regularization/noise trong value predictions
- Weighted loss (100x cho decisive) gây gradient spikes

---

## 🔧 GIẢI PHÁP

### Fix #1: Đúng Draw Detection (CRITICAL)

**File:** `colab_selfplay_pipeline.py:480-570`

```python
def load_generation_samples(path: Path) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    # ... existing code ...
    draws = (values == 0.0)  # Detect TRƯỚC
    n_draws = int(draws.sum())
    
    if n_draws > 0:
        # Apply penalty
        values[draws] = BASE_DRAW_PENALTY + material_adj
    
    values = np.clip(values, -1.0, 1.0)
    
    # CRITICAL: Return draw mask
    draw_mask = draws.astype(np.float32)
    return states, moves, values, draw_mask  # <-- Thêm draw_mask
```

**Update signature:**
- `load_replay_buffer()` → return `(x, y, v, draw_masks)`
- `train_policy_model()` → receive `draw_masks`, tính `draw_rate = draw_masks.mean()`

### Fix #2: Value Collapse Prevention

**A. Thêm value noise (line ~490):**
```python
if n_draws > 0:
    # Add small noise to prevent collapse
    noise = np.random.uniform(-0.02, 0.02, size=n_draws).astype(np.float32)
    values[draws] = BASE_DRAW_PENALTY + material_adj + noise
```

**B. Check collapse trong training loop:**
```python
def detect_value_collapse_in_training(model, device):
    """Check if value head predicts constant"""
    with torch.no_grad():
        test_positions = torch.randn(100, 20, 8, 8, device=device)
        _, values = model(test_positions)
        value_std = values.std().item()
        return value_std < 0.01  # Collapsed if std < 0.01
```

### Fix #3: Dynamic Value Weight Independence

**Tạo draw_rate từ draw_mask thay vì từ processed values:**

```python
# In train_policy_model()
draw_rate = draw_masks.mean().item()  # Đúng draw rate
_vw = 3.0 if draw_rate > 0.85 else (2.0 if draw_rate > 0.70 else 1.5)
```

### Fix #4: Add Value Head Monitoring

```python
# After each epoch
if (epoch + 1) % 2 == 0:  # Check every 2 epochs
    if detect_value_collapse_in_training(model, device):
        print(f"[WARNING] Value head collapse detected at epoch {epoch+1}")
        reinit_value_head(model)
        print("[FIX] Value head reinitialized")
```

---

## 📊 Expected Behavior After Fixes

1. **draw_rate**: 20-40% (realistic chess)
2. **vw**: Dynamic (1.5 → 2.0 → 3.0 theo draw_rate)
3. **value_loss**: Ổn định, không collapse về 0
4. **Model**: Học được phân biệt draw/win/loss
5. **MCTS**: Evaluation reliable hơn

---

## 🎯 Priority

1. **CRITICAL**: Fix #1 (draw detection) - ảnh hưởng toàn bộ pipeline
2. **HIGH**: Fix #2 (value collapse) - model không học được
3. **MEDIUM**: Fix #3 (dynamic vw) - phụ thuộc Fix #1
4. **LOW**: Fix #4 (monitoring) - early warning system

---

**Status:** Issues identified ✓ | Fixes designed ✓ | Implementation: IN PROGRESS
