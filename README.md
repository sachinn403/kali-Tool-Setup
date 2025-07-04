# 🛠 Kali Tool Installer

This repository contains a modular and automated setup for installing a wide range of security and penetration testing tools categorized by platform and purpose.

## 📁 Folder Structure Overview

| Folder Name       | Purpose                                                                                                                                                                     |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `activedirectory` | Tools related to Active Directory attacks and enumeration. Includes `tools/`, `tools.txt`, and scripts like `install.sh`, `download_release.py`, and `split_toolsfiles.py`. |
| `apt-install`     | Contains `install.sh` and tool lists for apt-based installations.                                                                                                           |
| `bugbounty`       | Recon and bug bounty tools (e.g., subdomain enumeration, fuzzers, etc).                                                                                                     |
| `go-based-tool`   | Tools written in Go, primarily from ProjectDiscovery (e.g., **httpx**, **nuclei**, **subfinder**, **dnsx**, etc.).                                                          |
| `linux`           | Linux-specific tools organized by categories like Enumeration, Exploitation, Privilege Escalation, etc. Uses categorized `.txt` lists and scripts for modular installs.     |
| `mobile`          | Tools for Android/iOS testing. Includes `install.sh`, `split.py`, and a `tools/` folder.                                                                                    |
| `windows`         | Tools for Windows exploitation, enumeration, and post-exploitation.                                                                                                         |
| `run_all`         | Master script to run everything across folders.                                                                                                                             |

---

## 🚀 How to Use

1. Clone the repository:

```bash
git clone https://github.com/sachinn403/kali-tool-setup.git
cd kali-tool-setup
```

2. Make the master script executable:

```bash
chmod +x run_all.sh
```

3. Run the full setup:

```bash
sudo ./run_all.sh
```

> The script will automatically install tools from each category using a combination of `apt`, GitHub releases, and Git repositories.

---

## 📎 Notes

* Each subfolder may contain `install.sh`, `tools.txt`, `tools.txt`, or GitHub download helpers like `download_release.py` or `split.py`.
* The structure allows easy customization by editing the `.txt` lists.
* Folders like `linux` group tools by functional categories for clarity.
* The Go-based tools follow a lightweight and fast scanning approach with a focus on ProjectDiscovery utilities.
* The script uses `set -euo pipefail` for safe and strict error handling.

---

## 📄 License

MIT License

---

Happy hacking! ⚔️
