import importlib.util
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


if __name__ == "__main__":
    unittest.main()
