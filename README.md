# 🚀 Linux Server Init

> A CLI tool for fast Linux server initialization and management.
>
> 一个用于快速初始化和管理 Linux 服务器的 CLI 工具。

� **[中文文档](doc/README_CN.md)** | **[English Docs](doc/README_EN.md)**

---

## Quick Install / 快速安装

**China (国内)**:
```bash
curl -fsSL https://gh-proxy.org/https://github.com/ytt447735/linux-server-init/raw/refs/heads/main/install.sh -o /tmp/install.sh && bash /tmp/install.sh
```

**International (海外)**:
```bash
curl -fsSL https://raw.githubusercontent.com/ytt447735/linux-server-init/main/install.sh -o /tmp/install.sh && bash /tmp/install.sh
```

**Git Clone**:
```bash
git clone https://github.com/ytt447735/linux-server-init.git && cd linux-server-init && bash install.sh
```

---

## Usage / 使用

```bash
server-init              # Launch menu / 启动主菜单
server-init update       # Online update / 在线更新
server-init uninstall    # Uninstall / 卸载
server-init version      # Version / 版本
server-init help         # Help / 帮助
```

---

## Supported OS / 支持的系统

| OS     | Version                | Status |
| :----- | :--------------------- | :----- |
| CentOS | 7.x / 8.x / Stream 8/9 | ✅      |
| Ubuntu | 20.04 / 22.04 / 24.04  | ✅      |
| Debian | 10 / 11                | ✅      |

---

## License

MIT