import json
import re
from pathlib import Path

# Special placeholder to assert presence without caring about value
ANY_VALUE = "__ANY__"


def _pattern_to_regex(pattern: str) -> re.Pattern:
    """Convert placeholder strings into regex patterns.

    Supported placeholders:
    - <number>: lowercase alnum of that length (e.g., <16>)
    - <guid>: GUID with hyphens (case-insensitive)
    """

    def repl(match: re.Match) -> str:
        token = match.group(1).lower()
        if token.isdigit():
            length = int(token)
            return rf"[a-z0-9]{{{length}}}"
        if token == "guid":
            return r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"
        return re.escape(match.group(0))

    escaped = re.escape(pattern)
    regex_str = re.sub(r"<([^>]+)>", repl, escaped)
    return re.compile(rf"^{regex_str}$")


def _match_value(expected, actual) -> bool:
    if expected == ANY_VALUE:
        return actual is not None
    if isinstance(expected, str):
        if actual is None:
            return False
        # allow placeholder patterns in expected
        placeholder = re.search(r"<\d+>", expected)
        placeholder_guid = re.search(r"<guid>", expected, flags=re.IGNORECASE)
        if placeholder:
            return bool(_pattern_to_regex(expected).match(actual))
        if placeholder_guid:
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
        # every expected element must match at least one actual element
        remaining = list(actual)
        for exp_item in expected:
            matched = False
            for i, act_item in enumerate(remaining):
                if _match_value(exp_item, act_item):
                    matched = True
                    # remove matched element to keep multiplicity honest
                    remaining.pop(i)
                    break
            if not matched:
                return False
        return True
    return expected == actual


def compare_expected_actual(expected_path: Path, actual_path):
    expected = json.loads(expected_path.read_text())
    if isinstance(actual_path, Path):
        actual = json.loads(actual_path.read_text())
    else:
        actual = actual_path
    mismatches = []

    def check(field, exp, act):
        if not _match_value(exp, act):
            mismatches.append(field)

    # top-level quick checks
    for key in ("resourceGroup", "location", "tags"):
        if key in expected:
            check(key, expected[key], actual.get(key))

    if "names" in expected:
        check("names", expected.get("names"), actual.get("names", {}))

    if "network" in expected:
        check("network", expected.get("network"), actual.get("network", {}))

    # Resource-level comparisons
    if "resources" in expected:
        exp_resources = expected.get("resources", [])
        remaining = list(actual.get("resources", []))
        missing = []

        for exp_res in exp_resources:
            exp_type = exp_res.get("type")
            exp_name = exp_res.get("name")
            matched_index = None
            for i, act in enumerate(remaining):
                if act.get("type") != exp_type:
                    continue
                if exp_name is not None and not _match_value(exp_name, act.get("name")):
                    continue
                # check remaining fields (location, properties, etc.)
                ok = True
                for key, val in exp_res.items():
                    if key in ("type", "name"):
                        continue
                    if not _match_value(val, act.get(key)):
                        ok = False
                        break
                if ok:
                    matched_index = i
                    break
            if matched_index is None:
                missing.append(f"resource:{exp_type}:{exp_name}")
            else:
                remaining.pop(matched_index)

        mismatches.extend(missing)

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

