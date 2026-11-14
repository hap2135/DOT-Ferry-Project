# DOT-Ferry-Project
Columbia University DOT Ferry Project

Firmware for the [Circuit Dojo nRF9151 Feather](https://docs.circuitdojo.com/nrf9151-feather/overview.html).

## Layout

```
firmware/
  app/            Zephyr / nRF Connect SDK application
    CMakeLists.txt
    prj.conf      Kconfig options
    src/main.c
```

## Board target

```
circuitdojo_feather_nrf9151/nrf9151/ns
```

## One-time SDK setup (Windows) — nRF Connect for VS Code

This project uses **nRF Connect for VS Code** (not Circuit Dojo's Zephyr Tools).
It follows the [Circuit Dojo nRF Connect guide](https://docs.circuitdojo.com/nrf9151-feather/using-vscode.html).
The SDK lives **outside** this repo, e.g. `C:
cs` (toolchain) and `C:
fed` (workspace).

1. Install VS Code, then the **nRF Connect for VS Code Extension Pack**. VS Code
   will suggest it when you open this repo (see `.vscode/extensions.json`).
2. Command Palette, then **nRF Connect: Manage Toolchains**. Install toolchain **v3.0.1**.
   Do **not** install an SDK via *Manage SDKs*: stock NCS lacks the nRF9151 Feather
   board. It comes from nfed (next step).
3. Command Palette, then **nRF Connect: West Init**. Choose **Custom repository**:
   - URL: `https://github.com/circuitdojo/nrf9160-feather-examples-and-drivers.git`
     (Circuit Dojo's "nfed" workspace, which also covers the nRF9151)
   - Revision: `v3.0.x` (as specified in Circuit Dojo's docs)
   - Location: `C:\nfed` (no spaces, outside this repo)
4. Command Palette, then **nRF Connect: West Update**. This downloads NCS v3.0.x and Zephyr.
   It takes a while.

## Build

> **Clone this repo to a path with no spaces** (e.g. `C:\DOT-Ferry-Project`).
> Zephyr's sysbuild fails on paths like `C:\Nordic DOT`.

1. In the nRF Connect sidebar, **Open an existing application**, then select `firmware/app`.
2. **Add build configuration**:
   - SDK: the nfed workspace from step 3
   - Toolchain: v3.0.1
   - Board target: `circuitdojo_feather_nrf9151/nrf9151/ns`
   - Sysbuild: enabled (default)
3. Click **Build**.

CLI equivalent, from an **nRF Connect terminal** (so the toolchain env is active):

```sh
cd firmware/app
west build -b circuitdojo_feather_nrf9151/nrf9151/ns -p -d build/circuitdojo_feather_nrf9151 --sysbuild
```

## Flash

The Feather has an on-board **CMSIS-DAP** debugger over USB. The nRF Connect
extension's built-in Flash action expects a J-Link / nrfutil probe, so it
won't work with this board. Use **probe-rs** instead.

Install probe-rs once (PowerShell):

```powershell
irm https://github.com/probe-rs/probe-rs/releases/latest/download/probe-rs-tools-installer.ps1 | iex
```

Flash from `firmware/app`:

```sh
probe-rs download --chip nRF9151_xxAA --binary-format hex build/circuitdojo_feather_nrf9151/merged.hex
probe-rs reset --chip nRF9151_xxAA
```

Serial console: use the nRF Connect **Serial Terminal**, or any terminal at 115200 baud
on the Feather's USB COM port.

## Notes

- MCUboot (via sysbuild) uses an insecure default signing key. Generate a real key
  before shipping OTA updates, and **never commit `*.pem` files**.
