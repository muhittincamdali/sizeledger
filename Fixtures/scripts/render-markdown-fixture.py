#!/usr/bin/env python3
"""Renders each case of Fixtures/markdown/escaping.json with GitHub's Markdown API.

    SIZELEDGER_UPDATE_SNAPSHOTS=1 swift test --filter MarkdownEscapingTests   # text and code
    python3 Fixtures/scripts/render-markdown-fixture.py                       # row and html

For every case the table row built from `text` and `code` is sent to `gh api markdown` in gfm
mode, with this repository as context so @mentions and #references would resolve, and the
row's HTML is stored. The script exits with status 1 when GitHub turned a value into a link, math,
mention, image or extra cell; MarkdownEscapingTests checks the same on every test run.
"""
import json
import os
import re
import subprocess
import sys

FIXTURE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "markdown", "escaping.json"
)
CONTEXT = "muhittincamdali/sizeledger"
BODY = re.compile(r"<tbody>\s*(.*?)\s*</tbody>", re.S)
MARKUP = ["<a ", "<img", "user-mention", "issue-link", "<script", "<br", "math-renderer", "<math"]


def render(markdown):
    result = subprocess.run(
        [
            "gh",
            "api",
            "-X",
            "POST",
            "/markdown",
            "-f",
            "mode=gfm",
            "-f",
            f"context={CONTEXT}",
            "-F",
            "text=@-",
        ],
        input=markdown,
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout


def main():
    with open(FIXTURE, encoding="utf-8") as handle:
        fixture = json.load(handle)
    problems = []
    for case in fixture["cases"]:
        if "text" not in case or "code" not in case:
            sys.exit(
                f"{case['name']}: no text or code; run the tests with SIZELEDGER_UPDATE_SNAPSHOTS=1 first"
            )
        row = f"| {case['text']} | {case['code']} | end |"
        html = render("| Text | Code | End |\n| --- | --- | --- |\n" + row + "\n")
        match = BODY.search(html)
        case["row"] = row
        case["html"] = match.group(1) if match else html.strip()
        cells = case["html"].count("<td")
        found = [markup for markup in MARKUP if markup in case["html"]]
        if cells != 3 or "<td>end</td>" not in case["html"] or found:
            problems.append(f"{case['name']}: {cells} cells, markup {found}")
    with open(FIXTURE, "w", encoding="utf-8") as handle:
        json.dump(fixture, handle, ensure_ascii=True, indent=2, sort_keys=True)
        handle.write("\n")
    for problem in problems:
        print(problem, file=sys.stderr)
    print(f"{len(fixture['cases'])} cases rendered, {len(problems)} problems")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
