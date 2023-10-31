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

    # if match := re.search(r'^Plan: (\d+) to add, (\d+) to change, (\d+) to destroy', plan, re.MULTILINE):
    #     output('to_add', match[1])
    #     output('to_change', match[2])
    #     output('to_destroy', match[3])



    # Regular expression pattern
    pattern = r'^Plan: (\d+) to add, (\d+) to change, (\d+) to destroy'

    # Find all matches in the plan
    matches = re.finditer(pattern, plan, re.MULTILINE)

    output('to_add', sum(int(match[0]) for match in matches))
    output('to_change', sum(int(match[1]) for match in matches))
    output('to_destroy', sum(int(match[2]) for match in matches))

if __name__ == '__main__':
    sys.exit(main())
