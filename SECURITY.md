# Security policy

## Reporting a vulnerability

Report it in private through GitHub:
[Report a vulnerability](https://github.com/MotherSphere/stellar-blade-coop/security/advisories/new). Only the
maintainers can read the report. Do not open a public issue or post it on Discord or Nexus Mods.

Please include:

- the mod version (the `[StellarCoop] Loaded version` line in `UE4SS.log`);
- the steps that show the problem;
- the part of `UE4SS.log` or `coop-link.log` around it;
- what an attacker could do with it.

We reply in the advisory within 7 days. A fix ships in the next release. The advisory is published once that release
is out, with credit to the reporter unless they ask to stay anonymous.

## Supported versions

Only the latest release on the [Releases](https://github.com/MotherSphere/stellar-blade-coop/releases) page gets
security fixes.

## Scope

In scope:

- `StellarCoop.dll` and the Lua scripts in `mod/StellarCoop/`;
- the messages two games exchange over the Steam link, including what a player in the same online session or lobby
  can send to another player's game;
- `tools/install.py` and the release zips.

Out of scope, report these to their owners:

- Stellar Blade itself (SHIFT UP);
- UE4SS ([RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS/security));
- Steam (Valve).

Test only with your own games and accounts. Do not test against other players without their consent.
