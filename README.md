# w_policejob

Sheriff and law enforcement roleplay job for **Wraith Framework RedM**.

## Key Features

- Sheriff office duty toggles and built-in Police Armory via `w_inventory`.
- Server-validated handcuffing (`ishandcuffed` metadata), escorting, searching, seizing cash, jailing, and unjailing.
- Blood, shell casing, and DNA evidence tools.
- Placeable law enforcement props (`/pobject`).

## Installation

1. Place `w_policejob` in `resources/[wraith]/w_policejob`.
2. Add `ensure w_policejob` to `server.cfg` after `w_lib`, `w_core`, and `w_inventory`.

## Commands & Exports

- **Commands:** `/cuff`, `/escort`, `/jail`, `/unjail`, `/seizecash`, `/callsign`, `/sc`, `/pobject`, `/takedna`, `/clearblood`, `/clearcasings`
- **Export:** `exports.w_policejob:IsHandcuffed()`

## Documentation & Links

- **Developer Docs:** https://wraith-core.github.io/docs/#/resources/economy-jobs
- **txAdmin Recipe:** https://github.com/Wraith-Core/txAdminRecipe

## License

GPL-3.0 — see [LICENSE](LICENSE).
