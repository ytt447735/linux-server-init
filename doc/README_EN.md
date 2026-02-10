# 🚀 Linux Server Init

> A **CLI tool** for fast Linux server initialization and management. Run `server-init` from anywhere after install, with online update support.

**[中文](README_CN.md)** | English

---

## ✨ Features

- **🐧 Multi-OS**: CentOS 7/8/Stream 9, Ubuntu 20.04+, Debian 10+
- **🖥️ System Overview**: Hostname, OS, CPU, memory, disk, IP, load
- **🔄 Mirror Source**: One-click Aliyun mirror switch (auto backup)
- **📦 System Update**: Full update with reboot prompt
- **🧰 Common Tools**: Basic + enhanced ops packages (vim, htop, tmux, jq, etc.)
- **🐳 Docker Install**: Docker CE + China registry mirrors
- **📦 Service Install**: Nginx / Node.js / Python / Go / GCC / Docker Compose (native + Docker modes)
- **⏰ NTP Sync**: 7 China NTP sources, chrony / ntpdate support
- **🛡️ Firewall**: firewalld / ufw port management
- **🔐 SSH Hardening**: Key auth, port change, disable password/root login
- **👤 User Management**: Add/delete users, password, sudo privileges
- **⚙️ Service Management**: systemd start/stop/restart, auto-start, logs, ports
- **⏰ Cron Jobs**: Crontab CRUD + 8 common job templates
- **🧹 System Cleanup**: Cache/logs/kernels/deps + Docker 8 cleanup modes
- **🌐 i18n**: Chinese / English menu switching
- **🔧 Self-management**: In-menu update / repair / uninstall / version

---

## 🖥️ Supported OS

| OS     | Version                | Status |
| :----- | :--------------------- | :----- |
| CentOS | 7.x / 8.x / Stream 8/9 | ✅      |
| Ubuntu | 20.04 / 22.04 / 24.04  | ✅      |
| Debian | 10 / 11                | ✅      |

---

## 📺 UI Preview

```
  ┌──────────────────────────────────────────────┐
  │        🚀 Linux Server Init  v1.0.0          │
  │        CentOS/RHEL Server Init Tool          │
  └──────────────────────────────────────────────┘
  CentOS Stream 9  ·  my-server

  ▸ Info
     1. System Overview

  ▸ System Config
     2. Change Mirror       4. NTP Time Sync
     3. System Update       5. Hostname / Timezone

  ▸ Software Install
     6. Common Tools        8. Install Services
     7. Install Docker

  ▸ Security
     9. Firewall           11. User Management
    10. SSH Hardening

  ▸ Operations
    12. Service Mgmt       14. System Cleanup
    13. Cron Job Mgmt

  ──────────────────────────────────────────────
    u) Update  v) Version  r) Repair  x) Uninstall  l) 中文
  ──────────────────────────────────────────────

     0. Exit

  Select [0-14/u/v/r/x/l]:
```

---

## 🚀 Install

Run as **root**:

### International

```bash
curl -fsSL https://raw.githubusercontent.com/ytt447735/linux-server-init/main/install.sh -o /tmp/install.sh && bash /tmp/install.sh
```

### China (mirror)

```bash
curl -fsSL https://gh-proxy.org/https://github.com/ytt447735/linux-server-init/raw/refs/heads/main/install.sh -o /tmp/install.sh && bash /tmp/install.sh
```

### git clone

```bash
git clone https://github.com/ytt447735/linux-server-init.git && cd linux-server-init && bash install.sh
```

---

## 📖 Usage

After installation, use `server-init` from anywhere:

```bash
server-init              # Launch main menu
server-init update       # Online update to latest version
server-init uninstall    # Uninstall tool
server-init version      # Show version info
server-init help         # Show help
```

| Path                          | Description               |
| ----------------------------- | ------------------------- |
| `/usr/local/bin/server-init`  | CLI entry point           |
| `/usr/local/lib/server-init/` | Scripts install directory |
