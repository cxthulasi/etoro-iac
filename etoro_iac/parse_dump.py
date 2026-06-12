#!/usr/bin/env python3
"""
Convert the JSON dump from the conversation into HCL locals entries.

Reads stdin, expects JSON objects (one per group) possibly concatenated.
Emits HCL list-of-objects suitable for inclusion in a locals block.
"""

import json
import re
import sys


def parse_objects(text):
    """Parse a stream of JSON objects from text, handling concatenation."""
    decoder = json.JSONDecoder()
    text = text.strip()
    objects = []
    pos = 0
    while pos < len(text):
        # Skip whitespace
        while pos < len(text) and text[pos] in " \t\n\r":
            pos += 1
        if pos >= len(text):
            break
        obj, end = decoder.raw_decode(text, pos)
        objects.append(obj)
        pos = end
    return objects


def to_hcl(objects):
    """Emit HCL list-of-objects with one entry per group."""
    lines = []
    for o in objects:
        env = o["deployment_environment_name"]
        cluster = o["k8s_cluster_name"]
        ns = o["k8s_namespace_name"]
        lines.append(
            f'    {{ env = "{env}", cluster = "{cluster}", namespace = "{ns}" }},'
        )
    return "\n".join(lines)


if __name__ == "__main__":
    text = sys.stdin.read()
    objs = parse_objects(text)
    sys.stderr.write(f"Parsed {len(objs)} entries\n")
    print(to_hcl(objs))
