import json
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import torch

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "AI" / "src"))

from model_artifacts import validate_training_inputs, write_model_output_summary
import colab_selfplay_pipeline as pipeline
import Convert_pth_to_pt


class TrainingHelpersTest(unittest.TestCase):
    def test_validate_training_inputs_rejects_empty_or_mismatched_data(self) -> None:
        with self.assertRaises(ValueError):
            validate_training_inputs([], [])

        with self.assertRaises(ValueError):
            validate_training_inputs([1, 2, 3], [1, 2])

    def test_chess_policy_net_returns_policy_and_value(self) -> None:
        model = pipeline.ChessPolicyNet()
        sample = torch.randn(2, 12, 8, 8)
        policy_logits, value_logit = model(sample)
        self.assertEqual(policy_logits.shape, (2, 4096))
        self.assertEqual(value_logit.shape, (2, 1))

    def test_load_generation_samples_preserves_values(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            path = Path(tmpdir) / "samples.bin"
            payload = np.zeros(770, dtype=np.float32)
            payload[768] = 123.0
            payload[769] = 0.42
            payload.tofile(path)
            states, moves, values = pipeline.load_generation_samples(path)
            self.assertEqual(states.shape, (1, 12, 8, 8))
            self.assertEqual(moves.shape, (1,))
            self.assertEqual(values.shape, (1,))
            self.assertAlmostEqual(float(values[0]), 0.42)

    def test_convert_writes_torchscript_from_dual_head_checkpoint(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            project_root = Path(tmpdir)
            data_dir = project_root / "data"
            data_dir.mkdir(parents=True, exist_ok=True)
            checkpoint_path = data_dir / "best_model.pth"
            torch.save(pipeline.ChessPolicyNet().state_dict(), checkpoint_path)

            Convert_pth_to_pt.convert(project_root=project_root)

            self.assertTrue((data_dir / "best_model_traced.pt").exists())

    def test_write_model_output_summary_creates_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            output_dir = Path(tmpdir)
            summary_path = write_model_output_summary(
                output_dir=output_dir,
                generation=2,
                artifacts={
                    "generation_model": output_dir / "model_gen_2.pt",
                    "best_model": output_dir / "best_model_traced.pt",
                },
                replay_path=output_dir / "selfplay_gen_2.bin",
                checkpoint_path=output_dir / "checkpoint_gen_2.pt",
            )
            self.assertTrue(summary_path.exists())
            data = json.loads(summary_path.read_text(encoding="utf-8"))
            self.assertEqual(data["generation"], 2)
            self.assertEqual(data["artifacts"]["generation_model"], str(output_dir / "model_gen_2.pt"))
            self.assertEqual(data["artifacts"]["best_model"], str(output_dir / "best_model_traced.pt"))


if __name__ == "__main__":
    unittest.main()
