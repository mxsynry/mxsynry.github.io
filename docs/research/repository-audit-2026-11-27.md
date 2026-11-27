# Repository text and code-pattern audit

Reviewed on 27 November 2026, starting from commit `6dfe1eb`.

The initial audit scanned 322 tracked text and source files, including bundled Monaco
files and archived scripts. Generated source maps and binary media were outside
the code review. Flagged characters and execution patterns were inspected;
archived Roblox scripts and their remote payloads were not executed.

## Changes

- Removed the decorative Japanese prefix from Synchrose's status label.
- Replaced 26 archived preset/menu display strings containing stacked accents,
  stylized letter substitutions or private-use icons with readable text. Preset
  IDs, stats, URLs and executable Lua were unchanged.
- Added `npm run check:text` to flag hidden formatting controls, private-use
  characters, stacked combining marks and unexpected non-Latin source text.
  GitHub Actions runs it alongside the existing checks.

Monaco's translations, language grammars and Unicode tables are intentional
library data. They remain intact. Song filenames, normal punctuation, currency
symbols, rating stars and other functional interface symbols are also retained.
The text check excludes bundled/generated files and the generated file index;
the audit reviewed their Unicode findings separately.

## Remaining execution paths

The maintained website code had no matches for `eval`, `new Function`, `atob`,
credential-shaped literals or webhook endpoints in the scanned patterns.
Those checks cannot establish that every dependency or program is safe.

Several archived Lua scripts intentionally download and execute remote code.
Examples include `Bloxy_Paradox-Rewrite.lua`, `Ryu_Decaying_Winter.luau`,
`Vanity.luau` and the legacy UNC test scripts. Their downloaded content was not
audited here.

`storage/other-stuff/reversed_jadexyz.lua` contacts a Protector service, checks a
key/device/user combination and executes a server-supplied response. That
behavior is recorded in the file's header. It remains an archived loader. The website does not execute it.

`storage/other-stuff/DOC.md` contains old enforcement-ban claims and deletion
commands. Its claims were not verified in this code/text audit, and none of
those commands were run.

The audit identifies concrete text issues and execution paths. It does not
infer authorship from writing style or certify remote downloads.
