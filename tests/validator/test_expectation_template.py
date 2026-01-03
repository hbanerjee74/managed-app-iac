import os
from pathlib import Path

import pytest

from tests.validator.compare_expectation import compare_expected_actual


TEMPLATE = Path("tests/validator/expected/dev_expectation.template.json")


def test_template_exists():
    assert TEMPLATE.exists(), "Expectation template missing"


@pytest.mark.skipif(
    not os.environ.get("ACTUAL_EXPECTATION_PATH"),
    reason="Set ACTUAL_EXPECTATION_PATH to run expectation comparison",
)
def test_compare_actual_against_template():
    actual_path = Path(os.environ["ACTUAL_EXPECTATION_PATH"])
    compare_expected_actual(TEMPLATE, actual_path)
