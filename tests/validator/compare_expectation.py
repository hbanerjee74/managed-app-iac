import json
import re
from pathlib import Path


def _pattern_to_regex(pattern: str) -> re.Pattern:
    """
    Convert placeholder strings like 'vd-vnet-platform-<16>' or 'vdstephemeral<8>'
    into regex patterns matching lowercase alnum segments of that length.
    """
    def repl(match: re.Match) -> str:
        length = int(match.group(1))
        return rf"[a-z0-9]{{{length}}}"

    escaped = re.escape(pattern)
    regex_str = re.sub(r"<(\d+)>", repl, escaped)
    return re.compile(rf"^{regex_str}$")


def _match_value(expected, actual) -> bool:
    if isinstance(expected, str):
        # allow placeholder patterns in expected
        placeholder = re.search(r"<\d+>", expected)
        if placeholder:
            return bool(_pattern_to_regex(expected).match(actual))
        return expected == actual
    if isinstance(expected, dict):
        if not isinstance(actual, dict):
            return False
        for k, v in expected.items():
            if k not in actual:
                return False
            if not _match_value(v, actual[k]):
                return False
        return True
    if isinstance(expected, list):
        if not isinstance(actual, list):
            return False
        return set(expected) <= set(actual)  # expected subset
    return expected == actual


def compare_expected_actual(expected_path: Path, actual_path: Path):
    expected = json.loads(expected_path.read_text())
    actual = json.loads(actual_path.read_text())
    mismatches = []

    def check(field, exp, act):
        if not _match_value(exp, act):
            mismatches.append(field)

    # top-level quick checks
    for key in ("resourceGroup", "location", "tags"):
        if key in expected:
            check(key, expected[key], actual.get(key))

    if "names" in expected:
        check("names", expected["names"], actual.get("names", {}))

    if "network" in expected:
        check("network", expected["network"], actual.get("network", {}))

    if mismatches:
        raise AssertionError(f"Mismatches for fields: {mismatches}")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Compare expected vs actual JSON with placeholders.")
    parser.add_argument("expected", type=Path)
    parser.add_argument("actual", type=Path)
    args = parser.parse_args()
    compare_expected_actual(args.expected, args.actual)
    print("Match: OK")
