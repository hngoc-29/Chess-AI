# 🔧 BÁO CÁO FIX BUGS TRAINING PIPELINE

## Ngày: 2026-07-02
## File: AI/src/colab_selfplay_pipeline.py

---

## ✅ BUGS ĐÃ FIX THÀNH CÔNG

### 1. **CRITICAL: Function Signature Sai** (Line 456)
**Vấn đề:**
```python
# SAI - Khai báo 3 giá trị
def load_generation_samples(path: Path) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    ...
    return states, moves, values, draw_mask  # Nhưng return 4 giá trị!
```

**Fix:**
```python
# ĐÚNG - Khai báo 4 giá trị
def load_generation_samples(path: Path) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Load samples from a self-play generation file.

    Returns:
        states: (N, 20, 8, 8) board states
        moves: (N,) move indices
        values: (N,) position values
        draw_mask: (N,) binary mask indicating draws
    """
```

**Impact:** Type hints giờ đúng, IDE sẽ không warning

---

### 2. **CRITICAL: Unpacking Sai Số Lượng Giá Trị** (Line 589)
**Vấn đề:**
```python
# SAI - Expect 3 giá trị nhưng function trả về 4
states, _, _ = load_generation_samples(path)
```

**Lỗi xảy ra:**
```
[Pipeline] skipping replay /kaggle/working/chess_outputs/selfplay_gen_1.bin: 
too many values to unpack (expected 3)
```

**Hậu quả nghiêm trọng:**
- ❌ **TẤT CẢ** replay files bị skip (43/43 generations)
- ❌ **KHÔNG có experience replay** - model chỉ học từ generation hiện tại
- ❌ Model không thể học từ past experience
- ❌ Training kém hiệu quả nghiêm trọng

**Fix:**
```python
# ĐÚNG - Unpack 4 giá trị
states, _, _, _ = load_generation_samples(path)  # FIXED: unpack 4 values (states, moves, values, draw_mask)
```

**Impact:** 
- ✅ Replay buffer giờ hoạt động đúng
- ✅ Experience replay được enable
- ✅ Model có thể học từ 10 generations gần nhất (min_samples=20000)

---

## ⚠️ VẤN ĐỀ CÒN TỒN TẠI (Cần điều tra thêm)

### 3. **Draw Rate = 0.0% Liên Tục**

**Quan sát từ log:**
```
Gen 1-43: draw=0.0% (không thay đổi suốt 43 generations)
```

**Nguyên nhân có thể:**

#### A. Self-play không tạo ra draws
- Chess games thực tế có ~30-40% draws ở level cao
- 0% draws là **bất thường**
- Có thể config `resign_thresh=0.95` quá thấp → games kết thúc sớm

#### B. Draw detection logic
```python
# Line 486: Detect draws khi value = 0.0 CHÍNH XÁC
draws = (values == 0.0)
```

**Vấn đề:**
- Self-play code có thể không assign value=0.0 cho draws
- Hoặc draws được mark bằng giá trị khác
- Cần kiểm tra self-play output format

#### C. Resignation threshold
```python
# Config hiện tại
resign_thresh = 0.95  # Resign khi value < -0.95
min_resign_ply = 25
```

**Khuyến nghị:**
- Tăng `resign_thresh = 0.98` để giảm early resignation
- Tăng `min_resign_ply = 40` để games chơi lâu hơn
- Hoặc disable resignation hoàn toàn để observe draw rate tự nhiên

---

### 4. **Value Loss = 0.0000 từ Gen 2 Trở Đi**

**Quan sát từ log:**
```
Gen 1: value=46.3633 (cao)
Gen 2: value=0.0000 (collapse!)
Gen 3-43: value=0.0000 (không phục hồi)
```

**Nguyên nhân có thể:**

#### A. Value Head Collapse
```python
# Code đã có detection và reinit (lines 778-785)
if (epoch + 1) % 2 == 0:
    if detect_value_collapse(model, device):
        print(f"[WARNING] Value head collapse detected at epoch {epoch+1}")
        reinit_value_head(model)
```

**Vấn đề:** 
- Detection chỉ chạy mỗi 2 epochs
- Có thể collapse xảy ra giữa các lần check
- Reinit có thể không đủ mạnh

#### B. Draw Adjustment Quá Mạnh
```python
# Lines 489-505: Draw adjustment
BASE_DRAW_PENALTY = -0.4
noise = np.random.uniform(-0.02, 0.02, size=n_draws)
values[draws] = (BASE_DRAW_PENALTY + material_adj + noise)
```

**Vấn đề:**
- Nếu 99%+ samples là draws (do không có decisive games)
- Tất cả values → -0.4 ± 0.05
- Value head học predict constant → loss = 0

#### C. Weighted Loss Numerical Instability
```python
# Lines 732-736: Weighted loss
is_decisive = (vb.abs() > 0.5)
sample_weights = torch.where(is_decisive,
                            torch.tensor(100.0, device=device),  # 100x weight!
                            torch.tensor(1.0, device=device))
value_loss = (sample_weights * (value_pred - vb.float()) ** 2).mean()
```

**Vấn đề:**
- 100x weight cho decisive positions có thể quá cao
- Gradient explosion/vanishing
- Value head không học được

---

## 🎯 KHUYẾN NGHỊ TIẾP THEO

### High Priority (Cần fix ngay)

1. **Test Replay Buffer Hoạt Động**
   ```bash
   # Run 1 generation và check log
   # Phải thấy: "[Pipeline] loading replay from gen_X, gen_Y, ..."
   # Không còn: "[Pipeline] skipping replay ..."
   ```

2. **Giảm Weighted Loss**
   ```python
   # Thay vì 100x, thử 10x hoặc 5x
   sample_weights = torch.where(is_decisive,
                               torch.tensor(10.0, device=device),  # Giảm từ 100x
                               torch.tensor(1.0, device=device))
   ```

3. **Tăng Value Head Capacity**
   - Check architecture của value head
   - Có thể cần thêm layers hoặc neurons
   - Check learning rate riêng cho value head

4. **Investigate Self-play Draw Detection**
   ```bash
   # Tìm self-play code
   find AI/ -name "*.py" -exec grep -l "resign\|draw\|game_result" {} \;
   
   # Check xem draws được save như thế nào
   # Có phải value=0.0 không?
   ```

### Medium Priority

5. **Add Detailed Logging**
   ```python
   # Thêm vào load_generation_samples
   print(f"[DataLoad] {path.name}: {n_draws} draws ({n_draws/len(values):.1%}), "
         f"values range [{values.min():.3f}, {values.max():.3f}]")
   ```

6. **Monitor Value Distribution**
   ```python
   # Thêm vào training loop
   if epoch == 0:
       print(f"[Debug] Value distribution: min={values.min():.3f}, "
             f"max={values.max():.3f}, mean={values.mean():.3f}, "
             f"std={values.std():.3f}")
   ```

### Low Priority

7. **Tune Hyperparameters**
   - Learning rate scheduling
   - Batch size optimization
   - Epochs per generation

---

## 📊 EXPECTED IMPROVEMENTS SAU KHI FIX

### Trước khi fix:
```
Gen 2-43:
- Replay: 0 files loaded (all skipped)
- Draw: 0.0%
- Value loss: 0.0000
- Training: Only on current generation (2600 samples)
```

### Sau khi fix:
```
Expected:
- Replay: 5-10 files loaded (~20,000-26,000 samples)
- Draw: 10-40% (natural chess draw rate)
- Value loss: 0.01-0.5 (healthy range)
- Training: On aggregated experience from multiple generations
```

---

## 🔍 CODE REVIEW CHECKLIST

- [x] Function signature đúng với return values
- [x] Tất cả unpacking đúng số lượng giá trị
- [ ] Self-play draw detection đúng format
- [ ] Value head architecture đủ mạnh
- [ ] Weighted loss không quá extreme
- [ ] Logging đầy đủ để debug
- [ ] Hyperparameters hợp lý

---

## 📝 CHANGES SUMMARY

**Files Modified:**
- `AI/src/colab_selfplay_pipeline.py`
  - Line 456: Fixed function signature (3→4 return values)
  - Line 589: Fixed unpacking (3→4 values)

**Status:** ✅ CRITICAL BUGS FIXED - Ready for testing

**Next Steps:** 
1. Run training với fixed code
2. Monitor replay buffer logs
3. Check draw rate và value loss
4. Investigate remaining issues nếu còn
