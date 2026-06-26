import importlib.util
import tempfile
from pathlib import Path
import unittest


class ResolveModelPathsTest(unittest.TestCase):
    def test_defaults_are_project_relative(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        module_path = repo_root / "AI" / "src" / "Convert_pth_to_pt.py"
        spec = importlib.util.spec_from_file_location("convert_pth_to_pt", module_path)
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)

        paths = module.resolve_model_paths(repo_root / "AI")
        self.assertEqual(paths["pth_model_path"], repo_root / "AI" / "data" / "best_model.pth")
        self.assertEqual(paths["pt_output_path"], repo_root / "AI" / "data" / "best_model_traced.pt")

    def test_resolve_best_model_path_falls_back_to_repo_data(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        module_path = repo_root / "AI" / "src" / "colab_selfplay_pipeline.py"
        spec = importlib.util.spec_from_file_location("colab_selfplay_pipeline", module_path)
        module = importlib.util.module_from_spec(spec)
        assert spec.loader is not None
        spec.loader.exec_module(module)

        with tempfile.TemporaryDirectory() as tmpdir:
            workspace = Path(tmpdir)
            project_root = workspace / "ChessAI"
            ai_root = project_root / "AI"
            (project_root / "data").mkdir(parents=True, exist_ok=True)
            model_path = project_root / "data" / "best_model_traced.pt"
            model_path.write_bytes(b"fake-model")
            drive_root = workspace / "drive"
            drive_root.mkdir(parents=True, exist_ok=True)

            resolved = module.resolve_best_model_path(ai_root, drive_root)
            self.assertEqual(resolved, model_path)


if __name__ == "__main__":
    unittest.main()
