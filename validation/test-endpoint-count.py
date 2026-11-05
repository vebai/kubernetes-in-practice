#!/usr/bin/env python3
"""Regression tests for EndpointSlice counter, runnable without Kubernetes."""

import json
from pathlib import Path
import subprocess
import sys

COUNTER = Path(__file__).with_name("endpoint-count.py")


def test(name: str, payload: object, expected: int) -> None:
    proc = subprocess.run(
        [sys.executable, str(COUNTER)],
        input=json.dumps(payload),
        text=True,
        capture_output=True,
        check=False,
    )
    assert proc.returncode == 0, f"{name}: exit={proc.returncode}: {proc.stderr}"
    assert proc.stdout.strip() == str(expected), f"{name}: got {proc.stdout!r}, expected {expected}"
    print(f"PASS: EndpointSlice parser: {name} -> {expected}")


cases = {
    "no slices": ({"apiVersion": "v1", "items": []}, 0),
    "null items": ({"items": None}, 0),
    "missing endpoints": ({"items": [{"metadata": {"name": "flask-app"}}]}, 0),
    "null endpoints (regression)": ({"items": [{"endpoints": None}]}, 0),
    "empty endpoints": ({"items": [{"endpoints": []}]}, 0),
    "ready backends": ({"items": [{"endpoints": [
        {"addresses": ["10.244.0.5"], "conditions": {"ready": True}},
        {"addresses": ["10.244.0.6"], "conditions": {"ready": True}},
        {"addresses": ["10.244.0.9"], "conditions": {"ready": True}},
    ]}]}, 3),
    "unready excluded": ({"items": [{"endpoints": [
        {"addresses": ["10.0.0.1"], "conditions": {"ready": False}},
        {"addresses": ["10.0.0.2"], "conditions": {"ready": True}},
    ]}]}, 1),
    "null conditions permitted": ({"items": [{"endpoints": [{"addresses": ["10.0.0.3"], "conditions": None}]}]}, 1),
    "addressless excluded": ({"items": [{"endpoints": [{"addresses": [], "conditions": {"ready": True}}]}]}, 0),
    "multiple slices": ({"items": [{"endpoints": [{"addresses": ["10.0.0.1"]}]},
                                      {"endpoints": [{"addresses": ["10.0.0.2"]}]}]}, 2),
}

for case, (payload, expected) in cases.items():
    test(case, payload, expected)

malformed = subprocess.run(
    [sys.executable, str(COUNTER)], input='{"items":[{"endpoints":{}}]}',
    text=True, capture_output=True, check=False,
)
assert malformed.returncode == 2 and "parsing error" in malformed.stderr
print("PASS: EndpointSlice parser: malformed data produces visible failure")

print(f"ENDPOINTSLICE PARSER TESTS: {len(cases) + 1} PASSED")
