"""
Create plan summary actions outputs

Creates the outputs:
- to_add
- to_change
- to_destroy

Usage:
    plan_summary
"""

from __future__ import annotations

import re
import sys
from github_actions.commands import output


def main() -> None:
    """Entrypoint for terraform-backend"""

    with open(sys.argv[1]) as f:
        plan = f.read()

    # Regular expression pattern
    pattern = r'^Plan: (\d+) to add, (\d+) to change, (\d+) to destroy'

    # Find all matches in the plan
    matches = re.finditer(pattern, plan, re.MULTILINE)

    output('to_add', str(sum(int(match.group(1)) for match in matches)))
    output('to_change', str(sum(int(match.group(2)) for match in matches)))
    output('to_destroy', str(sum(int(match.group(3)) for match in matches)))

if __name__ == '__main__':
    sys.exit(main())
