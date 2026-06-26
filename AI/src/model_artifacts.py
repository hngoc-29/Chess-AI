import json
from pathlib import Path
from typing import Dict, List, Optional


def validate_training_inputs(states: List[object], moves: List[object]) -> None:
    if not states or not moves:
        raise ValueError("Training data is empty")
    if len(states) != len(moves):
        raise ValueError(f"Training data length mismatch: states={len(states)}, moves={len(moves)}")


def write_model_output_summary(
    output_dir: Path,
    generation: int,
    artifacts: Dict[str, Path],
    replay_path: Optional[Path] = None,
    checkpoint_path: Optional[Path] = None,
) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    summary_path = output_dir / f"model_output_summary_gen_{generation}.json"
    payload = {
        "generation": generation,
        "replay_path": str(replay_path) if replay_path is not None else None,
        "checkpoint_path": str(checkpoint_path) if checkpoint_path is not None else None,
        "artifacts": {name: str(path) for name, path in artifacts.items()},
    }
    summary_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
    return summary_path
