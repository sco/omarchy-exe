# exe.dev for Omarchy

A compact, keyboard-first Omarchy bar plugin for browsing and managing [exe.dev](https://exe.dev) VMs.

## Features

- Lists and manages VMs through exe.dev's HTTPS API
- Shows VM name, status, region, and SSH destination
- Opens an SSH session in the configured Omarchy terminal
- Opens a VM's HTTPS URL
- Restarts a VM, copies its SSH destination, or creates a default VM
- Refreshes whenever the panel opens and on a configurable interval (30 seconds by default)
- Mints a scoped 90-day API token through one interactive SSH authorization
- Stores the token in GNOME Keyring; it is never passed in process arguments

## Requirements

- OpenSSH for initial authorization and interactive VM sessions
- `curl` and `secret-tool` (both included with Omarchy)
- `wl-copy` for clipboard actions
- A current Omarchy shell with bar plugin support

## Installation

```bash
omarchy plugin add https://github.com/sco/omarchy-exe --enable
```

If installing from a local checkout, copy or link the repository into `~/.config/omarchy/plugins/sco.exe`, then enable `sco.exe` in the Omarchy shell plugin settings.

## Keyboard shortcuts

With the panel open:

- `j` / `k` or arrow keys: select a VM
- `enter` or click: open a terminal and SSH to the selected VM
- `o`: open its HTTPS URL
- `r`: restart it
- `c`: copy its SSH destination
- `n`: create a new VM with exe.dev defaults
- `f`: refresh the list
- `esc`: close the panel

When no API token is available, `enter` opens a terminal, asks SSH to mint a token limited to `ls`, `new`, and `restart`, stores it in GNOME Keyring, and reopens the panel. Press `o` to open exe.dev's email/passkey sign-in page.

Right-clicking the bar icon also refreshes the VM list.

## Configuration

`refreshIntervalSec` controls background refreshes. It defaults to 30 seconds and accepts values from 5 to 3600 seconds.

## Design

The plugin follows Omarchy's current `bar-widget` conventions: `Panel.qml` is the entry point, `Service.qml` owns the backend processes, and the panel uses the shared `Panel`, `KeyboardPanel`, `PanelKeyCatcher`, and `CursorSurface` primitives.

## License

MIT
