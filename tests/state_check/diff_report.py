import json
import sys
from pathlib import Path


def summarize(changes):
    summary = {"Create": 0, "Modify": 0, "Delete": 0, "NoChange": 0}
    for change in changes:
        change_type = change.get("changeType", "Unknown")
        summary[change_type] = summary.get(change_type, 0) + 1
    return summary


def main(path: str):
    data = json.loads(Path(path).read_text())
    changes = data.get("changes", [])
    summary = summarize(changes)

    print("What-if summary:")
    for k, v in summary.items():
        print(f"  {k}: {v}")

    if summary.get("Create", 0) or summary.get("Modify", 0) or summary.get("Delete", 0):
        print("\nDifferences detected. See detailed what-if output for specifics.")
        sys.exit(1)
    else:
        print("\nNo changes detected; RG matches Bicep.")
        sys.exit(0)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python tests/state_check/diff_report.py tests/state_check/what-if.json")
        sys.exit(2)
    main(sys.argv[1])
