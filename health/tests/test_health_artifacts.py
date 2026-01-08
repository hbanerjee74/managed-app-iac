"""Health artifact checks (opt-in)."""
import os
from pathlib import Path
import pytest

ARTIFACTS_DIR = Path(__file__).parent.parent.parent / 'artifacts'
HEALTH_ARTIFACTS = (
    'waf-health.zip',
    'appservice-plan-health.zip',
)


@pytest.mark.skipif(
    os.getenv('HEALTH_VALIDATE_ARTIFACTS', 'false').lower() != 'true',
    reason="Set HEALTH_VALIDATE_ARTIFACTS=true to validate health artifacts."
)
def test_health_artifacts_present():
    """Test that health app artifacts are present for packaging."""
    assert ARTIFACTS_DIR.exists(), f"Artifacts folder not found: {ARTIFACTS_DIR}"
    missing = [name for name in HEALTH_ARTIFACTS if not (ARTIFACTS_DIR / name).exists()]
    assert not missing, f"Missing health artifacts: {missing}"
