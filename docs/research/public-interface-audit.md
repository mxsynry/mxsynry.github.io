# Public interface audit

Reviewed: 21 July 2026

## Scope

This audit covers official documentation, public source repositories, indexed page content and interfaces exposed by ordinary public navigation. It does not guess undisclosed paths, bypass access controls, evade rate limits or probe private endpoints.

## RDD deployments

| Host | Confirmed route | Publicly observable interface |
|---|---|---|
| WEAO | `https://rdd.weao.gg/` | Player/Studio binary types, Windows/Mac, channel and version hash, compression, exploit selector, launcher controls, shareable query parameters |
| Pulsery | `https://pulsery.gg/rdd` | Deployment UI with platform/type, compression, source manifest, executor matching, channel and version target |
| Inject.today | `https://inject.today/rdd` | Public RDD route confirmed; content is client-rendered and was not available in the text index used for this audit |
| Latte upstream | `https://rdd.latte.to/` | MIT-licensed static browser RDD and public source repository |

## API findings

- WEAO publishes an API reference and requires the documented `WEAO-3PService` user-agent.
- Voxlis publishes static JSON and Markdown data through its public GitHub repository.
- No separate official public API reference for Pulsery or Inject.today was found in the reviewed public pages or indexed sources.
- An RDD route is a user-facing application route. It should not be described as a public API unless the operator documents a supported machine interface.

## Safe next step

Request supported endpoint documentation from Pulsery and Inject.today. If the site operators authorize integration, record the allowed routes, authentication, rate limits, schemas, caching rules, attribution and deprecation policy in `source-audit.json` before writing an adapter.
