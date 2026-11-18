# powerbi-linux

**Run Microsoft Power BI Desktop on Linux, in its own window, with one command.** · [Português](README.pt-BR.md)

Power BI Desktop is Windows-only and doesn't work under Wine. `powerbi-linux` installs a small Windows 11 VM in the background (KVM via the excellent [dockur/windows](https://github.com/dockur/windows) container), installs Power BI Desktop inside it without any clicks, and gives you a **"Power BI Desktop" entry in your app menu**. Clicking it starts Windows if needed and opens Power BI in a window you can resize, tile or maximize like any other app.

```text
app menu ─▶ powerbi-linux open ─▶ podman/docker: Windows 11 (KVM) ─▶ FreeRDP window "Power BI Desktop"
```

- **Unattended install.** Windows and Power BI both come from Microsoft's servers. The Power BI installer's signature is checked inside Windows before it runs.
- **Feels like an app.** Power BI starts maximized and the Windows taskbar is hidden. The window follows your window manager (tiling works) through FreeRDP's dynamic resolution.
- **Starts and stops on demand.** Windows only runs while you use it. When you close the window, you're asked whether to shut Windows down. Logging out or powering off shuts it down cleanly (systemd user unit).
- **Your files.** Your Linux home folder shows up in Windows as the drive **Linux** (*This PC*), so you can open and save `.pbix` files directly.
- **Local only.** The RDP and VNC ports are bound to `127.0.0.1`. A random password is generated and stored with `chmod 600`.
- **Updates.** `powerbi-linux update` downloads the latest Power BI. It installs itself the next time Windows starts.

> **Not affiliated with Microsoft.** You need a valid Windows license to use Windows beyond its evaluation terms. Power BI Desktop itself is free.

## Requirements

| | |
|---|---|
| CPU | x86_64 with virtualization enabled in BIOS/UEFI (Intel VT-x / AMD-V); `/dev/kvm` must exist |
| RAM | 8 GB minimum, 16 GB recommended (the VM uses ~1/3 of your RAM, 4–8 GB) |
| Disk | ~45 GB free (Windows disk image is sparse; ~30 GB used after install) |
| Packages | `podman` (recommended) or `docker`, **FreeRDP 3** (`xfreerdp3`), `curl`; optional `zenity`, `notify-send` |
| Desktop | Any X11 or Wayland session (FreeRDP runs via XWayland). Tested on Hyprland. |

`./install.sh --deps` prints and runs the right package command for Arch/CachyOS/Manjaro, Fedora, openSUSE, and Debian/Ubuntu. Ubuntu 24.04+ and Debian 13+ ship `freerdp3-x11`; on Debian 12, enable `bookworm-backports` first.

## Install

```bash
git clone https://github.com/ludoviciphilip/powerbi-linux.git
cd powerbi-linux
./install.sh
```

The installer shows a plan (resources, language, keyboard, disk) and asks before it starts. Then it downloads Windows (~7 GB) and Power BI (~700 MB) and waits until everything is ready. That takes **20–60 min**, mostly the download. You can watch the VM screen at <http://127.0.0.1:48006> while it works.

Options (pass them to `./install.sh` or `powerbi-linux install`):

```text
--ram 6G  --cpus 4  --disk 64G
--language en-US    Windows display language   (default: from $LANG)
--region pt-BR      number/date/currency format (default: from $LC_NUMERIC; matters for Power Query decimals!)
--keyboard de-DE    keyboard layout            (default: from your desktop: Hyprland, GNOME, KDE, localectl)
--engine docker     use Docker instead of Podman
--no-share-home     don't expose your home folder inside Windows
--yes               no questions
```

## Use

Open **Power BI Desktop** from your app menu. From a terminal:

```bash
powerbi-linux open        # start Windows if needed and open Power BI (default)
powerbi-linux stop        # shut Windows down cleanly
powerbi-linux status      # VM state, Power BI version, disk usage
powerbi-linux update      # fetch the latest Power BI (installs on next Windows start)
powerbi-linux uninstall   # remove VM + menu entry (add --purge to delete the Windows disk too)
```

Cold start takes about 20 s until the window appears, plus about a minute until Power BI has loaded. Closing the window only **disconnects**: Power BI keeps running inside Windows. You can then:

- **Keep running**: reopen it later and you're right where you left off.
- **Shut down**: frees the RAM. **Save your `.pbix` first**, because unsaved changes are lost.

To skip the question, set `ON_CLOSE="stop"` or `"keep"` in `~/.config/powerbi-linux/config.env`.

## How it works

| Piece | What it does |
|---|---|
| `dockurr/windows` | QEMU/KVM inside a container; downloads Windows from Microsoft and installs it unattended |
| `share/windows/setup.ps1` | runs once at first logon: verifies + installs Power BI, auto-hides the taskbar, registers a logon task |
| `share/windows/logon.ps1` | at every Windows logon: installs a pending update, starts Power BI maximized |
| `bin/powerbi-linux` | host CLI: install, open (FreeRDP full session with `+dynamic-resolution`), stop, update |
| `powerbi-linux-vm.service` | systemd **user** unit started on demand, so logout/shutdown stops Windows gracefully |

Windows writes its setup progress to `~/.local/share/powerbi-linux/exchange/status.txt` (shared as `\\host.lan\Data`). That's how the installer knows when Power BI is ready.

### Why a full RDP session and not a "seamless" RemoteApp window?

Tools like WinApps and WinBoat can show a single Windows app as a native-looking window (RemoteApp/RAIL). Under several Wayland compositors (Hyprland, COSMIC, …), resizing those windows breaks: FreeRDP echoes the compositor's geometry back to Windows, and the window drifts or renders offset (FreeRDP [#4934](https://github.com/FreeRDP/FreeRDP/issues/4934), [#13610](https://github.com/FreeRDP/FreeRDP/issues/13610)). A full session with dynamic resolution, Power BI maximized and the taskbar hidden looks the same and resizes perfectly everywhere.

## Configuration

`~/.config/powerbi-linux/config.env`:

| Key | Default | Meaning |
|---|---|---|
| `ON_CLOSE` | `ask` | `ask`, `stop` or `keep` when the window closes |
| `SHARE_HOME` | `yes` | map `$HOME` as drive *Linux* in Windows |
| `FREERDP_EXTRA` | empty | extra FreeRDP args, one per line (e.g. `/scale:140` for HiDPI) |
| `RDP_PORT` / `WEB_PORT` | `47389` / `48006` | localhost ports |
| `RAM_SIZE`, `CPU_CORES`, `DISK_SIZE`, `LANGUAGE`, `REGION`, `KEYBOARD` | detected | applied at install time (`powerbi-linux reinstall` to change) |

Data lives in `~/.local/share/powerbi-linux/` (`storage/` holds the Windows disk), and logs are in `~/.local/state/powerbi-linux/`.

### Hyprland tips

```lua
-- ~/.config/hypr/... (Lua config) — keep the window opaque
hl.window_rule({ match = { class = "powerbi-linux" }, opaque = true, no_blur = true })
```
With hyprlang configs: `windowrule = opaque, class:powerbi-linux`.

## Troubleshooting

- **`/dev/kvm` missing**: enable virtualization in BIOS/UEFI and check `lsmod | grep kvm`.
- **Permission denied on `/dev/kvm`**: `sudo usermod -aG kvm $USER`, then log out and back in.
- **The install seems stuck**: open <http://127.0.0.1:48006> to see the VM screen; `podman logs -f powerbi-linux` shows the container log.
- **Slow download**: the Windows ISO comes from Microsoft's CDN; anything else using your bandwidth (Steam…) slows it down.
- **Setup failed inside Windows**: see `~/.local/share/powerbi-linux/exchange/setup.log`.
- **Btrfs**: the installer disables copy-on-write on the empty disk folder automatically (`chattr +C`).
- **Start over**: `powerbi-linux reinstall`.

## Credits

- [dockur/windows](https://github.com/dockur/windows) (MIT): Windows in a container, unattended install. This project wouldn't exist without it.
- [FreeRDP](https://www.freerdp.com/): the RDP client.
- [WinApps](https://github.com/winapps-org/winapps): inspiration and research on RemoteApp integration.

## License

[MIT](LICENSE). Microsoft, Windows and Power BI are trademarks of Microsoft Corporation. This project is not affiliated with or endorsed by Microsoft.
