# -*- coding: utf-8 -*-
"""
model_artifacts.py
Utility helpers imported by colab_selfplay_pipeline.py.

Provides:
  - validate_training_inputs()   : sanity-check states/moves/values before training
  - write_model_output_summary() : write a JSON summary of each generation's artifacts
"""

import json
import time
from pathlib import Path
from typing import Any, Dict, List, Optional


# ── validate_training_inputs ─────────────────────────────────────────────────

def validate_training_inputs(
    states: List,
    moves:  List,
    values: List,
) -> None:
    """Sanity-check replay-buffer tensors before passing them to the trainer.

    Raises ValueError with a descriptive message if anything looks wrong.
    The lists are expected to come from numpy array .tolist() calls so
    individual elements may be plain Python ints/floats.

    Checks:
      1. All three lists have the same length.
      2. Length > 0.
      3. Every move index is in [0, 4287] (NUM_ACTIONS = 4288).
      4. Every value is in [-1.0, 1.0].
    """
    n = len(states)

    if len(moves) != n or len(values) != n:
        raise ValueError(
            f"[Validate] Length mismatch: states={n}, moves={len(moves)}, values={len(values)}"
        )

    if n == 0:
        raise ValueError("[Validate] Empty training batch — no samples found in replay buffer.")

    NUM_ACTIONS = 4288

    bad_moves = [
        (i, int(m)) for i, m in enumerate(moves)
        if not (0 <= int(m) < NUM_ACTIONS)
    ]
    if bad_moves:
        sample = bad_moves[:5]
        raise ValueError(
            f"[Validate] {len(bad_moves)} move index(es) out of [0, {NUM_ACTIONS}) range. "
            f"First few: {sample}"
        )

    bad_values = [
        (i, float(v)) for i, v in enumerate(values)
        if not (-1.0 <= float(v) <= 1.0)
    ]
    if bad_values:
        sample = bad_values[:5]
        raise ValueError(
            f"[Validate] {len(bad_values)} value(s) out of [-1.0, 1.0] range. "
            f"First few: {sample}"
        )

    print(
        f"[Validate] ✓ {n} samples — moves ∈ [0,{NUM_ACTIONS}), values ∈ [-1,1]"
    )


# ── write_model_output_summary ───────────────────────────────────────────────

def write_model_output_summary(
    output_dir: Path,
    generation: int,
    artifacts: Dict[str, Any],
    replay_path: Optional[Path] = None,
    checkpoint_path: Optional[Path] = None,
    arena_result: Optional[Dict[str, Any]] = None,
) -> Path:
    """Write a JSON summary of all artifacts produced by one self-play generation.

    The file is written to:
        output_dir / model_output_summary_gen_{generation}.json

    Returns the path of the written file.
    """
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    def _size_mb(p: Any) -> Optional[float]:
        p = Path(p) if p is not None else None
        if p is not None and p.exists():
            return round(p.stat().st_size / 1e6, 2)
        return None

    def _str(p: Any) -> Optional[str]:
        return str(p) if p is not None else None

    summary: Dict[str, Any] = {
        "generation": generation,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "artifacts": {
            name: {
                "path": _str(path),
                "size_mb": _size_mb(path),
                "exists": Path(path).exists() if path is not None else False,
            }
            for name, path in artifacts.items()
        },
    }

    if replay_path is not None:
        summary["replay"] = {
            "path": _str(replay_path),
            "size_mb": _size_mb(replay_path),
        }

    if checkpoint_path is not None:
        summary["checkpoint"] = {
            "path": _str(checkpoint_path),
            "size_mb": _size_mb(checkpoint_path),
        }

    if arena_result is not None:
        summary["arena"] = arena_result

    out_path = output_dir / f"model_output_summary_gen_{generation}.json"
    with out_path.open("w", encoding="utf-8") as fh:
        json.dump(summary, fh, indent=2)

    print(f"[Artifacts] ✓ summary gen {generation} → {out_path}")
    return out_path
