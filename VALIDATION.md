# Validation for this prepared source snapshot

- Upstream base: 845f332d083502fab39be49869052966103b564a.
- Runtime ES5 lint: passed.
- Synthetic device adapter tests: 11 passed, including explicit Netflix app-control targeting, single callback completion, and no HDMI/Art launch in that request.
- Upstream source/resource checks: passed.
- Upstream public-source scanner: passed before packaging; final tracked-file scan repeated.
- Public native templates: generated with synthetic owner IDs and compiled for .NET Core 3.1 with zero warnings/errors. No generated files or binaries included.
- Windows runner: PowerShell parser check passed; parameterized public runner not deployed to the TV.
- Known personal addresses, account path, private launcher ID: scanned and removed from public files.
- Browser acceptance suite, POSIX signing/tool suite, hosted CI: not run for this preparation. No UI layout changes made.
- Owner observations and remaining physical checks: docs/ls03b-owner-report.md.

Only tracked source files belong in the upload/archive. Do not upload node_modules, .local, outputs, certificates, device logs, generated helper builds or personal signed packages.
