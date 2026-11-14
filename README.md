# City Run — PC demo, launcher & license portal

This repository contains the original Godot 4.3 City Run prototype, a Windows launcher, and a Node.js checkout/license API.

## Current game scope
- Procedural 3D street, buildings, lit windows, street lamps and trees.
- Drivable red car, ambient traffic, third-person character and one parcel-delivery mission.
- Controls: WASD, mouse, E, Esc.
- This is an early prototype, not a GTA V copy or a finished AAA game.

## Build the Windows demo
GitHub Actions → **Build City Run PC Demo** → Run workflow. On success, download `CityRun-PC-Demo-with-Launcher`. The ZIP contains `Launcher/CityRunLauncher.exe` and `Game/CityRun.exe` plus the PCK if Godot exports one. Keep both folders side by side.

## Run the payment portal
Requires Node.js 20+ and a Stripe account.

1. Copy `.env.example` to `.env` and set `BASE_URL` to the public HTTPS domain.
2. Set `STRIPE_SECRET_KEY` to a Stripe **test** secret first; never commit `.env`.
3. Set `PRICE_CENTS` and `CURRENCY` (default: `23300` and `rub` = 233 ₽ (RUB uses two minor-unit digits in Stripe)).
4. Configure a Stripe webhook at `https://YOUR_DOMAIN/api/stripe/webhook` for `checkout.session.completed`, then set `STRIPE_WEBHOOK_SECRET`.
5. Run `npm install && npm start`.

The checkout page is disabled until Stripe is configured. The Windows launcher asks for a license key and HTTPS API URL, calls `/api/activate`, and only starts the game after the server accepts the key. The machine identifier is generated once and stored locally in the user data folder. A license is issued only after Stripe's signed webhook confirms `payment_status=paid`. The order page polls for the key. `/api/activate` binds a key to one machine ID. Before release, set the actual public HTTPS API URL as the launcher default in `cityrun-launcher/main.gd` (replace `https://YOUR-DOMAIN`). The launcher currently lets the user enter this URL manually. For production, replace the JSON store with a transactional database, add rate limiting, HTTPS, backups, monitoring, privacy/terms/refund pages and a tested deployment target. Do not expose server secrets in client code or GitHub.

## Deployment notes
The game build is a GitHub Actions artifact. The payment API requires a Node-capable server (for example a VPS or Node hosting); static website hosting alone cannot run this backend. Configure persistent storage for `LICENSES_DB`.

## Security
Never store card data. Stripe Checkout handles payment details. Do not put secret keys in source control. Start with Stripe test mode and perform real payments only after legal, tax, refund and provider setup.
