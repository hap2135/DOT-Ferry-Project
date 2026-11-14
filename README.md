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

## One-time SDK setup (Windows)

The app is built against Circuit Dojo's west workspace
([nfed](https://github.com/circuitdojo/nrf9160-feather-examples-and-drivers),
which also covers the nRF9151). The SDK lives **outside** this repo.

Recommended path ([Circuit Dojo guide](https://docs.circuitdojo.com/nrf9151-feather/sdk-setup-ui.html)):

1. Install VS Code, Git and Python >= 3.10.
2. Install the **Zephyr Tools** extension (`circuitdojo.zephyr-tools`).
3. In the Zephyr Tools sidebar: **Run Setup**, then **Init Repo** with
   `https://github.com/circuitdojo/nrf9160-feather-examples-and-drivers.git`.

Alternative: nRF Connect for VS Code, toolchain/SDK **v3.0.x**, then
"West Init" with the nfed URL as a custom repository
([guide](https://docs.circuitdojo.com/nrf9151-feather/using-vscode.html)).

## Build

From a shell with the NCS/nfed environment active:

```sh
cd firmware/app
west build -b circuitdojo_feather_nrf9151/nrf9151/ns -p -d build --sysbuild
```

Or in VS Code with Zephyr Tools, open `firmware/app` and use **Build**.

## Flash

The Feather has an on-board CMSIS-DAP debugger over USB, so you don't need an external probe.

- Zephyr Tools: **Flash** button, then **Serial Monitor** to see the console.
- Or with [probe-rs](https://probe.rs):
  ```sh
  probe-rs download --chip nRF9151_xxAA --binary-format hex build/merged.hex
  probe-rs reset --chip nRF9151_xxAA
  ```

## Notes

- MCUboot (via sysbuild) uses an insecure default signing key. Generate a real key
  before shipping OTA updates, and **never commit `*.pem` files**.
