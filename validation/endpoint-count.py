#!/usr/bin/env python3
"""Count *ready, addressed* backends across Kubernetes EndpointSlices.

Input: ``kubectl get endpointslices -l ... -o json`` on stdin.
Output: one decimal integer.  Handles ``endpoints: null`` emitted by
Kubernetes for a slice without endpoints, as well as missing/empty arrays.
Malformed input is a visible failure, never silently interpreted as zero.
"""

import json
import sys


def backend_count(document: object) -> int:
    if not isinstance(document, dict):
        raise ValueError("the kubectl response must be a JSON object")
    items = document.get("items")
    if items is None:
        items = []
    if not isinstance(items, list):
        raise ValueError("items must be a list or null")

    total = 0
    for item in items:
        if not isinstance(item, dict):
            raise ValueError("EndpointSlice item must be an object")
        endpoints = item.get("endpoints")
        if endpoints is None:
            endpoints = []
        if not isinstance(endpoints, list):
            raise ValueError("endpoints must be a list or null")
        for endpoint in endpoints:
            if not isinstance(endpoint, dict):
                raise ValueError("endpoint must be an object")
            addresses = endpoint.get("addresses")
            if addresses is None:
                addresses = []
            if not isinstance(addresses, list):
                raise ValueError("addresses must be a list or null")
            conditions = endpoint.get("conditions")
            if conditions is None:
                conditions = {}
            if not isinstance(conditions, dict):
                raise ValueError("conditions must be an object or null")
            if addresses and conditions.get("ready") is not False:
                total += 1
    return total


def main() -> int:
    try:
        data = json.load(sys.stdin)
        print(backend_count(data))
        return 0
    except (json.JSONDecodeError, TypeError, ValueError) as exc:
        print(f"EndpointSlice JSON parsing error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
