# Security policy

## Supported versions

Security fixes are made for the latest release of each project. If you are on an older version,
the fix will be in a new release and the upgrade notes will say if anything changes for you.

## Reporting a vulnerability

Please report vulnerabilities privately, not in a public issue, pull request or discussion.

1. **Preferred:** open the repository's **Security** tab and choose
   **Report a vulnerability** ([how private reporting works](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately)).
2. **Or** email [muhittincamdali@gmail.com](mailto:muhittincamdali@gmail.com) with
   "Security" in the subject.

Include what you can of the following:

- the affected repository and version (tag or commit),
- what an attacker can do and under which conditions,
- steps or a small file that reproduces it,
- any fix or mitigation you already have in mind.

## What happens next

- You get a reply within 7 days confirming that the report arrived.
- I confirm the issue, work on a fix and agree a disclosure date with you. Fixes are released as
  soon as they are ready, together with a GitHub security advisory.
- You are credited in the advisory unless you prefer not to be.

Please give a reasonable amount of time to fix the issue before disclosing it publicly.

## Scope for sizeledger

sizeledger reads the `.app`, `.ipa` or `.xcarchive` you point it at: file sizes, the ZIP
directory of an `.ipa`, the app's Info.plist and the headers of Mach-O files. It writes only the
report you ask for with `--out`, makes no network requests, does not extract archives to disk and
never runs code from the app. Inputs are untrusted, so reports that fit this policy include, for
example: a crafted `.ipa` or Mach-O file that makes sizeledger crash, hang, use unbounded memory,
read outside the file, or write anywhere but the `--out` file; and file names or Info.plist values
that put terminal escape sequences or Markdown links into the printed report.
