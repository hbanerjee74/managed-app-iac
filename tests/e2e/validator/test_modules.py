import json
import os
from pathlib import Path

import pytest

from tests.e2e.validator.compare_expectation import compare_expected_actual


EXPECTED_DIR = Path("tests/e2e/validator/expected/modules")


def _load(path: Path):
    return json.loads(path.read_text())


@pytest.fixture(scope="session")
def actual_path():
    path = os.environ.get("ACTUAL_PATH")
    if not path:
        pytest.skip("Set ACTUAL_PATH to run module-level comparisons")
    return Path(path)


@pytest.fixture(scope="session")
def actual_data(actual_path):
    return _load(actual_path)


def _compare_expected_file(actual_data, expected_file: Path):
    compare_expected_actual(expected_file, actual_data)


@pytest.mark.parametrize(
    "expected_file",
    sorted(EXPECTED_DIR.glob("*.json")),
    ids=lambda p: p.stem,
)
def test_module_expectations(actual_data, expected_file):
    _compare_expected_file(actual_data, expected_file)

