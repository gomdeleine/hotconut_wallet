# Hotconut

[![Flutter](https://img.shields.io/badge/Flutter-3.29-blue?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-X11-green.svg)](https://github.com/gomdeleine/hotconut_wallet/blob/main/LICENSE)

<p align="center">
  <img src="./assets/readme/wallet.png" alt="Hotconut Logo" width="96"/>
</p>

<p align="center">
  A personal fork of a watch-only Bitcoin wallet — build and use at your own risk
</p>

## Important Notice

**This is a personal fork, not a product.**

- Built and maintained for **my own use**. There is **no plan** to publish on the App Store or Google Play.
- **Build from source** on your own device if you want to try it. No official binaries are provided.
- **No warranty, no support, no liability.** Use at your own risk, especially on mainnet. I am not responsible for loss of funds, bugs, or any other damages.
- **Not affiliated with Nonce Lab.** This is an unofficial fork of [Coconut Wallet](https://github.com/noncelab/coconut_wallet). "Coconut Wallet" is a trademark of Nonce Lab, Inc.

## About This Fork

Hotconut is a local fork of [Coconut Wallet](https://github.com/noncelab/coconut_wallet). The name blends **hot** (for the experimental on-device hot wallet) and **coconut** — a nod to its upstream roots, not an affiliation with Nonce Lab.

Changes in this fork (experimental, unmaintained for others):

- **Hot wallet (experimental)** — optional on-device signing; not part of upstream's watch-only model. Use with extreme caution.
- **Privacy-oriented** — Firebase / analytics-related code removed or disabled compared to upstream.
- Other tweaks for personal workflow; no stability or security guarantees.

## Architecture & Documentation

For system design, security model, supported hardware wallets, and feature list, see the upstream project:

- [Coconut Wallet README](https://github.com/noncelab/coconut_wallet/blob/main/README.md) — architecture, features, air-gapped signing flow
- [Coconut Vault](https://github.com/noncelab/coconut_vault) — offline signer (recommended pairing for watch-only use)
- [coconut_lib](https://github.com/noncelab/coconut_lib) — Bitcoin wallet library

This fork inherits most of that design. Differences are listed in [About This Fork](#about-this-fork) above.

## Build & Run

You are expected to build and run this yourself; see [Important Notice](#important-notice) above.

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.29+)
- Dart 3.7+

```bash
flutter --version
flutter pub get
```

### Code Generation

```bash
dart run build_runner build --delete-conflicting-outputs
dart run realm generate
flutter pub run slang
```

### Environment Variables

Network config lives in `mainnet.env`, `regtest.env`, and `testnet.env` in the project root.
Edit the values there for local development or release builds.

### Run

```bash
# Debug (recommended for development)
flutter run --flavor regtest

# Release (no keystore required — uses debug signing)
flutter build apk --flavor regtest --release
```

### Flavors

| Flavor | Description |
|--------|-------------|
| `mainnet` | Bitcoin mainnet |
| `regtest` | Testnet for learning and development |

### IDE Configuration

**VS Code** — `.vscode/launch.json`:

```json
{
  "name": "hotconut (debug)",
  "request": "launch",
  "type": "dart",
  "args": ["--flavor", "regtest"]
}
```

## License & Attribution

This project is licensed under the **X11 Consortium License (MIT/X)**, the same license as [Coconut Wallet](https://github.com/noncelab/coconut_wallet/blob/main/LICENSE).

- The original copyright and license notice from Nonce Lab, Inc. are preserved in [LICENSE](LICENSE).
- Modifications in this fork are also distributed under the same license, **provided as-is with no warranty**.
- Per the upstream license: the name **Nonce Lab** must not be used for promotion without written permission, and **"Coconut Wallet"** is a trademark of Nonce Lab, Inc. This project is **Hotconut**, an independent fork — not Coconut Wallet and not endorsed by Nonce Lab.
