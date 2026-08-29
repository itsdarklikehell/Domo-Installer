# Domo-Installer

Een (menu)script dat Domoticz home-automation installeert op een Debian/Ubuntu
systeem of Proxmox LXC.

## Wat dit script doet

- Detecteert de architectuur (x86_64 / aarch64 / armv7l) en downloadt de juiste build.
- Gebruikt de **officiële** Domoticz-downloadendpoint
  (`https://www.domoticz.com/download.php?...`). De oude statische tarball-URLs
  (`releases.domoticz.com/.../domoticz_linux_armv7l.tgz`) zijn dood (404).
- Installeert Domoticz als **systemd**-service (geen verouderde SysV `init.d` meer).
- Biedt een echt **backup**-menu (voorheen "not implemented yet").

## Menu-opties

1. Installeer Domoticz (Release / stable)
2. Installeer Domoticz (Beta)
3. Installeer Domoticz (broncode bouwen)
4. Update Domoticz
5. Backup Domoticz
6. Afsluiten

## Gebruik

```bash
sudo bash Domo-Installer.sh
```

Of via de one-liner (master-branch):

```bash
bash <(curl -Ls https://github.com/hmol33/Domo-Installer/raw/master/Domo-Installer.sh)
```

Na installatie is de webinterface bereikbaar op `http://<host>:8080`.

## Ontwikkeling

- `shellcheck -S warning Domo-Installer.sh` moet schoon zijn (CI controleert dit).
- Werk bij voorkeur op een feature-branch en open een PR naar `master`.
