# Synchrose executor terminology: evidence notes

Reviewed: **22 November 2026 (Asia/Saigon)**. Research reads web pages, documentation, and public source text only. No executor, installer, test script, or remote Lua was run. This date records this review; it does not make an older benchmark current.

## Definitions supported by primary sources

| Term | Definition suitable for Synchrose | Evidence and scope |
| --- | --- | --- |
| Executor | Third-party software providing a script execution environment and additional APIs for Roblox. Function compatibility, permission context, detection, and software trust are separate questions. | The [original UNC project](https://github.com/unified-naming-convention/NamingStandard) describes standardizing APIs across executors. [Roblox Support](https://en.help.roblox.com/hc/en-us/articles/203312450-Cheating-and-Exploiting) describes account and malware risks associated with exploiting. Neither source endorses a product. |
| UNC | **Unified Naming Convention**: a community specification for common executor function names and behavior, intended to make scripts portable between implementations. “UNC score” usually means the result of an environment checker against part of that specification. | [UNC README](https://github.com/unified-naming-convention/NamingStandard#readme); project retired, repository archived **4 May 2024**. |
| sUNC | **senS’ Unified Naming Convention**: a separate test project checking executor functions against its expected behavior. Its function coverage has diverged from the original UNC. | [Official introduction](https://docs.sunc.io/About/what-is-sunc/), [coverage notes](https://docs.sunc.io/). A score describes that suite and run; it is not a Roblox certification. |
| debUNC | **debunk Unified Naming Convention**, the project’s own expansion: an open-source executor function test suite with documented custom functions and detailed outcome categories. | [alyssagithub/debUNC README](https://github.com/alyssagithub/debUNC#readme), [test source](https://github.com/alyssagithub/debUNC/blob/main/debUNC.luau). User’s “debunc” corresponds to this project; do not rename it “deUNC.” |
| Myriad | **Myriad General Validity Test**: an open-source suite for executor standards, functionality, and mitigation checks. Standards and Vulnerabilities are distinct result types. | [Official repository](https://github.com/Standard-2/Myriad#readme), [Standards docs](https://github.com/Standard-2/Myriad/blob/main/docs/api/standards/index.md), [result schema](https://github.com/Standard-2/Myriad/blob/main/docs/web-api/results.md). Some checks require its testing experience. |
| Thread identity / executor level | The numeric security context of the running Luau thread, related to permissions/capabilities. A reported identity is not a compatibility percentage, performance benchmark, or trust certificate. | [sUNC Reflection](https://docs.sunc.io/Reflection/), [getthreadidentity](https://docs.sunc.io/Reflection/getthreadidentity/), [setthreadidentity](https://docs.sunc.io/Reflection/setthreadidentity/). Avoid a universal “higher number means better” ranking. |
| Executor identification | The executor’s reported name and version, commonly returned by `identifyexecutor`. This differs from thread identity. | [Function reference](https://docs.sunc.io/Miscellaneous/identifyexecutor/). The [library documentation](https://docs.sunc.io/Miscellaneous/) explicitly says this must not be relied on as a secure identifier. |

## Claim ledger and corrections

1. **Verified in source: original UNC does more than check whether names exist.** Its [`UNCCheckEnv.lua`](https://github.com/unified-naming-convention/NamingStandard/blob/main/UNCCheckEnv.lua) runs assertion callbacks, including behavioral checks for `clonefunction`, `hookfunction`, and `cloneref`. Some entries have no test. Its summary is passes divided by passes plus failures; missing aliases are reported separately. Rewrite “UNC only checks presence” as “the original environment checker has limited coverage and is no longer maintained.”

2. **Verified project documentation; authenticity mechanism is attributed to its owner:** [sUNC v2 result docs](https://docs.sunc.io/About/test-results/) require the official testing game, describe result links redirecting to Rubiš, and say game servers sign results so altered data is marked unverified. Prefer a full linked report with its verification indicator over a screenshot. Signature verification concerns the result’s provenance/integrity; treating it as evidence that an installer is safe would be an unsupported inference.

3. **Verified scope distinction: “100% Myriad” is ambiguous without a category.** The [primary schema](https://github.com/Standard-2/Myriad/blob/main/docs/web-api/results.md) separates Standards (`s`: tested, passed, failed, excluded) from Vulnerabilities (`v`: secured, vulnerable, ambiguous, excluded, rating). [Voxlis’ Solara page](https://voxlis.net/roblox/windows/solara) explicitly calls its listed Myriad value a vulnerability audit. Do not translate that value into universal API support or malware-free status. Keep suite versions, product versions, platform, timestamp, result category, and failed/skipped/excluded checks with a cited result.

4. **Verified version sensitivity:** Myriad’s [changelog](https://github.com/Standard-2/Myriad/blob/main/CHANGELOG.md) records removing the identity escalation vulnerability check in 1.8.0 and later framework changes. Current Standards source still includes [getthreadidentity](https://github.com/Standard-2/Myriad/blob/main/src/tests/standards/checks/Reflection/getthreadidentity.luau). Avoid presenting a historic check as an unchanging feature of every release.

5. **Verified project structure, not independent superiority:** debUNC’s README has confirmed results tied to a suite version, executor versions, and passed/failed/skipped/missing counts. Its author criticizes other suites, but “best,” “strictest,” and “largest” are advocacy/comparison claims, not established measurements. Explain its scope without repeating those superlatives as fact.

6. **Inference from differing specifications and result schemas:** scores across UNC, sUNC, debUNC, and Myriad are not directly interchangeable. Each uses its own checks, versions, exclusions, and environment assumptions. Passing the included checks cannot establish compatibility with every script or the absence of untested vulnerabilities.

7. **Verified limit on software-safety claims:** [ScriptDumper](https://scriptdumper.com/) describes sandbox analysis of script behavior, attempted calls, decoded layers, and captured files, while explicitly disclaiming guaranteed results. A clean script report does not authenticate an executor download or establish the behavior of code not exercised during the scan.

8. **Primary platform risk statement:** [Roblox Support](https://en.help.roblox.com/hc/en-us/articles/203312450-Cheating-and-Exploiting) says exploiting violates its terms and warns that exploit downloads can be malware/phishing. API pass rates and claimed thread levels do not answer these separate account/software risk questions.

## Requested source review

| Source | What was available | Appropriate use |
| --- | --- | --- |
| [Voxlis](https://voxlis.net/wiki/roblox) | Listing, individual pages, and its current public [directory JSON feed](https://voxlis.net/api/directory/roblox), identified in the live page's linked application bundle. | Real catalog input with source attribution and source timestamps. Product figures are volatile secondary claims; this research does not independently verify their benchmark runs or endorse downloads. See the migration notes below. |
| [bypass.tools](https://bypass.tools/executors) | Initial rendered text omitted the listing. Follow-up inspection of its linked application bundle identified the public [executors JSON feed](https://bypass.tools/api/executors), which returned 40 entries. | Real catalog input replacing Inject.today. Preserve its WEAO synchronization attribution so copied upstream claims are not presented as independent measurements. See the migration notes below. |
| [RobloxScripts](https://robloxscripts.com/script/myriad-validity-test-an-open-source-executor-test-suite) | Myriad listing published 13 Nov, approved 16 Nov, and updated 17 Nov 2026; links the project and identifies Standards/Vulnerabilities. | Discovery. Trace the definition to Standard-2’s repository; a listing is not a security audit or endorsement. |
| [ScriptDumper](https://scriptdumper.com/) | First-party description of its scanner and its limits. | Explain what a scan can show and why a clean result is not a guarantee. No scan was submitted in this research. |
| [r/robloxhackers wiki](https://www.reddit.com/r/robloxhackers/wiki/index/) | Community wiki accessible. Its [Staying Safe page](https://www.reddit.com/r/robloxhackers/wiki/index/staying_safe/) still includes retired Script-Ware/Synapse X workflows and unattributed product allegations. The false-positives subpage returned HTTP 429. | Community reports are investigation leads. Check post dates, evidence, official source ownership, and relevance to the current build. Do not repeat old product allegations or old setup instructions as current facts. |

## Verified catalog interface migration

These are public routes used by each site's current frontend, observed on 22 November 2026. They are verified observations, not a promise of a stable third-party API contract. No authentication, challenge solving, private endpoint discovery, or executor code execution was involved. Standard browser request headers read the public assets; Python's default user-agent received a 403 from Voxlis.

### Voxlis

The live [catalog page](https://voxlis.net/wiki/roblox) linked [`/assets/index-CXq6zZa8.js`](https://voxlis.net/assets/index-CXq6zZa8.js). That bundle defines the directory endpoint, requires an array at `response.cards`, and constructs its single-product query with `?slug=`.

| Route | Observed result | Purpose |
| --- | --- | --- |
| [`GET /api/directory/roblox`](https://voxlis.net/api/directory/roblox) | HTTP 200, JSON, 19 product cards / 20 platform variants in the reviewed response. | Load the complete catalog in one request. |
| [`GET /api/directory/roblox?slug=delta`](https://voxlis.net/api/directory/roblox?slug=delta) | HTTP 200, JSON, one matching card plus `comparisonCards`. | Optional detail lookup; `delta` is an observed slug, not a guessed route. |
| [`GET /public/data/roblox`](https://voxlis.net/public/data/roblox) | HTTP 404, JSON error. | Retired catalog root; remove its use as the data source. |
| [`GET /public/data/roblox/prices.json`](https://voxlis.net/public/data/roblox/prices.json) | HTTP 404, JSON error. | Retired pricing catalog used by Synchrose's old bridge. |

The directory response has these top-level fields: `cards`, `metadata`, `counts`, `sources`, `workingVersions`, `recentBuilds`, `stale`, `checkedAt`, and `fetchedAt`. The observed `sources` object has availability booleans for `status`, `pricing`, and `sunc`; it is not a list of independent evidentiary sources. Retain the upstream `checkedAt`, `fetchedAt`, and `stale` separately from Synchrose's local receipt time. The reviewed response reported `checkedAt: 2026-11-21T18:46:54.000Z` and `fetchedAt: 2026-11-21T18:47:07.137Z`.

Actionable card schema and mapping:

- Shared product fields include `slug`, `title`, `description`, `tags`, `badges`, `profileImage`, and `screenshots`. `variants[]` supplies per-platform/per-type `id`, `platform`, `type`, `typeLabel`, `status`, `version`, `pricing`, `sunc`, optional `myriad`, `review`, and website/Discord/link arrays. Keep distinct platform observations rather than copying a card's first-variant result across every platform. The Delta card has both iOS and Android variants with different sUNC results and test dates.
- An `id` such as `windows:executor` repeats across products. Form source identity with the product slug plus variant identifier, platform, and/or type.
- `status` was `updated` or `outdated` in the reviewed payload; preserve it as a provider report. `platformStatuses` summarizes those reports. `version` commonly contains a targeted Roblox build, including `version-...` desktop strings and mobile app build numbers. Do not label it a current executor release version. `pricing.available` describes pricing availability and is not working status.
- `pricing` includes `label`, `purchaseUrl`, `free`, `available`, `access`, optional `msrpLabel`, and `tiers[]` with duration, lifetime, currency, price, and MSRP fields. Values and purchase links remain source claims.
- `sunc` includes numeric-or-null `score`, `label`, optional `metadata` containing suite `version`, `durationSeconds`, historical `executor`, and `testedAt`, plus `passedFunctions`. External tools explicitly use `score: null` with label `External`; preserve missing/not-applicable values. Do not substitute a historical test executor string for the current product release.
- `myriad.audit` includes `kind`, `id`, `url`, historical `executorVersion`, `generated`, `checked`, `secured`, `vulnerable`, `ambiguous`, `excluded`, `rating`, `vulnerabilities`, and `unclear`. Observed `kind: "v"` identifies a **Vulnerabilities** result; display that category with its actual report URL and date. Preserve ambiguous/excluded checks rather than implying a complete security guarantee.
- `review` is inline Markdown on cards/variants, so the app can obtain provider notes from the current directory response. It no longer needs guessed per-folder `review.md`, `info.json`, or `points.json` catalog reads. Treat review statements as attributed Voxlis commentary and render through the existing safe Markdown path.
- `updateHistory`, `pendingReleases`, `averageUptimePercent`, and `averageUpdateTimeSeconds` describe source-tracked Roblox update periods. Their `detectedAt`, `updatedAt`, and `periodEndedAt` timestamps are distinct from benchmark dates. These are not anti-cheat detection evidence.

With `Origin: https://mxsynry.github.io`, both current directory GET responses lacked `Access-Control-Allow-Origin`; the public API returned `Cache-Control: no-cache` and an ETag. Browser clients therefore need Synchrose's fixed server-side bridge rather than a direct cross-origin fetch. Do not extend that bridge into an arbitrary URL proxy. Voxlis's `verified` badge is described in its own `metadata.badges` as a documented/verified more-info page; it does not authenticate an installer.

### bypass.tools

The live [executors page](https://bypass.tools/executors) linked [`/assets/index-CIz_IMa9.js`](https://bypass.tools/assets/index-CIz_IMa9.js). Its application calls [`GET /api/executors`](https://bypass.tools/api/executors), which returned a JSON array of 40 entries. This is the real catalog replacement for Inject.today, not just a reference link.

Observed fields: `id`, `name`, `logo_url`, `version`, `price`, `purchase_url`, `website_url`, `download_url`, `status`, `category`, `features`, `weao_id`, `weao_synced`, `is_recommended`, `discord_url`, `description`, `owner`, `screenshots`, `rbx_version`, `sunc_scrap`, `sunc_key`, click counters, `created_at`, and `updated_at`.

- `category` distinguishes Android, iOS, Mac, and Windows Executors from Windows External Exploits. Normalize platform and product type from that field. Observed status strings were `Working` and `Not Working`.
- `features` is a comma-separated string; individual tokens may include `sUNC NN%`. Extract a percentage only from an explicitly numeric score token. A bare `UNC` or `sUNC` capability token does not supply a score.
- Keep `rbx_version` separate from the listing's `version`, and retain `updated_at` as the listing update time, not a benchmark date. All 40 reviewed rows set `weao_synced: true` and have a `weao_id`; these reports share WEAO upstream data and do not constitute a second independent measurement of each fact.
- `sunc_scrap` and `sunc_key` are result-reference fields. The linked frontend's details modal requests `/api/executors/{id}/sunc`; its response was not verified in this research, so do not invent that endpoint's schema or a direct result-link format from these tokens.
- The parent integration investigation observed no `Access-Control-Allow-Origin` on the catalog response. Use a fixed bridge route, schema validation, and a visible source failure state. A recommendation flag, working status, download link, or synchronized score is not a malware verdict.

## Editorial recommendation

Keep Synchrose a readable reference: define the terms, identify what each test measures, distinguish reported identity from effective permissions, and separate compatibility evidence from malware/detection claims. Link primary docs next to technical definitions. Label community resources by their role rather than calling every listing “trusted.” Avoid fixed executor rankings, unsupported detection statuses, hard-coded benchmark percentages, download endorsements, or runnable remote-script examples without a current, attributable reason to include them.
