import json
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT / "AI" / "src"))

from model_artifacts import validate_training_inputs, write_model_output_summary


class TrainingHelpersTest(unittest.TestCase):
    def test_validate_training_inputs_rejects_empty_or_mismatched_data(self) -> None:
        with self.assertRaises(ValueError):
            validate_training_inputs([], [])

        with self.assertRaises(ValueError):
            validate_training_inputs([1, 2, 3], [1, 2])

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
