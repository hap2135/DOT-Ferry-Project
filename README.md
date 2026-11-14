# DOT-Ferry-Project
Columbia University DOT Ferry Project

Firmware for the [Circuit Dojo nRF9151 Feather](https://docs.circuitdojo.com/nrf9151-feather/overview.html).

## Layout

```
firmware/
  app/            Zephyr / nRF Connect SDK application
    CMakeLists.txt
    prj.conf               Kconfig options (UART console + RTT logging)
    sysbuild.conf          Turns on MCUboot, with no image signing (required, see Notes)
    sysbuild/mcuboot.conf  MCUboot settings (multithreading on)
    src/main.c
```

## Board target

```
circuitdojo_feather_nrf9151/nrf9151/ns
```

## One-time SDK setup (Windows) — nRF Connect for VS Code

This project uses **nRF Connect for VS Code** (not Circuit Dojo's Zephyr Tools).
It follows the [Circuit Dojo nRF Connect guide](https://docs.circuitdojo.com/nrf9151-feather/using-vscode.html).
The SDK lives **outside** this repo, e.g. `C:\ncs` (toolchain) and `C:\nfed` (workspace).

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

`merged.hex` holds MCUboot, TF-M and the app together. The first flash replaces
the bootloader the board shipped with. That's fine: probe-rs can always reflash it.

## Serial console

Open the Feather's USB serial port (COM5 on the dev PC; the number can differ per
machine) at **115200 8N1, no flow control**. Use the nRF Connect **Serial Terminal**
or any serial terminal. Press **RST** to see the boot output:

```
*** Booting nRF Connect SDK v3.0.1-9eb5615da66b ***
*** Using Zephyr OS v4.0.99-77f865b8f8d0 ***
<inf> app_startup: *** Vsys Current Limit: 1000 mA ***
<inf> app: DOT Ferry firmware starting on circuitdojo_feather_nrf9151
<inf> app: heartbeat 0
<inf> app: heartbeat 1
```

Only one program can have the COM port open at a time.

Logs also go to **SEGGER RTT** over the debug link, as a backup. From `firmware/app`:

```sh
probe-rs attach --chip nRF9151_xxAA build/circuitdojo_feather_nrf9151/app/zephyr/zephyr.elf
```

## Notes

- **MCUboot is required.** The board's build files (`sysbuild.cmake`) force a flash
  layout with the bootloader at `0x0` and the app image at `0x10000`, overriding any
  layout the project supplies. Without `sysbuild.conf` (`SB_CONFIG_BOOTLOADER_MCUBOOT=y`)
  the app never boots and prints nothing anywhere.
- **Unsigned for now.** `SB_CONFIG_BOOT_SIGNATURE_TYPE_NONE=y` means MCUboot only checks
  the image hash, so no signing key is needed. Switch to a real signature type and key
  before any OTA updates, and **never commit `*.pem` files**.
- `sysbuild/mcuboot.conf` must turn on multithreading (the board's I2C/PMIC drivers
  need it), or MCUboot fails to link with `undefined reference to z_impl_k_mutex_init`.
- The board has no `led0` alias. Its LEDs are driven by the nPM1300 PMIC (see Circuit
  Dojo's `samples/blinky`), so the LED blink in `main.c` is currently skipped.

## Troubleshooting

- **No output at all (COM port or RTT):** check that the app image header is in flash:
  `probe-rs read --chip nRF9151_xxAA b32 0x10000 1` should print `96f3b83d`. If it
  prints `ffffffff`, MCUboot isn't enabled in the build (see `sysbuild.conf`).
- **COM port "Access denied":** another program has the port open. Close any other
  serial terminal.
