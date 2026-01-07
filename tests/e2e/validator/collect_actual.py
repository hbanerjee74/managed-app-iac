"""Stub for post-deploy validator that captures the deployed state into JSON.

This script will later query Azure resources (LAW, KV, Storage, ACR, App GW, etc.)
and serialize key configuration fields so tests can diff against an expected JSON.
"""

def collect_actual():
    """Placeholder for future Azure SDK calls."""
    return {}


if __name__ == "__main__":
    print(collect_actual())

