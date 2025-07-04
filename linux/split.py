#!/usr/bin/env python3
import os
import re

# Category mapping based on tool names or keywords
CATEGORY_MAPPING = {
    'Privilege-Escalation': ['LinPEAS', 'Linux Exploit Suggester', 'LinEnum', 'unix-privesc-check', 'SUID3NUM', 'GTFOBins', 'PEASS', 'Checksec', 'Linux Exploit Suggester 2', 'LES', 'Dirty COW', 'LinuxPrivChecker'],
    'Enumeration': ['enum4linux-ng', 'pspy', 'lscpu', 'lsof', 'nmap-vulners', 'linux-smart-enumeration', 'Procmon', 'VulnScan', 'Lynis'],
    'Binaries': ['busybox', 'socat', 'chkrootkit', 'rkhunter', 'nc', 'proxychains-ng', 'Chisel', 'SSHuttle', 'Wget', 'Curl', 'Dropbear', 'Ngrok'],
    'Exploitation': ['Metasploit Framework', 'Exploit-DB', 'Kernelpop', 'CVE-2017-5638', 'CVE-2021-4034'],
    'Networking': ['Nmap', 'Masscan', 'Wireshark', 'Hping3'],
    'Persistence': ['Pupy', 'Cronjob Persistence', 'Rootkits'],
    'Utilities': ['Hashcat', 'John the Ripper', 'Hydra', 'GDB', 'Strace']
}

def get_category(tool_name):
    for category, tools in CATEGORY_MAPPING.items():
        if tool_name in tools or any(keyword in tool_name for keyword in tools):
            return category
    return 'Utilities'  # Default category

def split_tools_file(input_file="tools.txt", output_dir="tools"):
    if not os.path.isfile(input_file):
        print(f"Error: Input file '{input_file}' does not exist.")
        exit(1)

    try:
        os.makedirs(output_dir, exist_ok=True)
    except PermissionError:
        print(f"Error: Cannot create directory '{output_dir}'. Check permissions.")
        exit(1)

    category_files = {}
    with open(input_file, "r") as infile:
        for line in infile:
            line = line.rstrip('\r\n')
            if not line or line.startswith("#"):
                continue
            parts = line.split(maxsplit=2)
            if len(parts) < 2:
                print(f"Warning: Invalid line in '{input_file}': '{line}'. Skipping...")
                continue
            name, url = parts[0], parts[1]
            dest_subfolder = parts[2] if len(parts) > 2 else name.replace('git:', '')
            category = get_category(name.replace('git:', ''))

            output_file = os.path.join(output_dir, f"{category}.txt")
            if output_file not in category_files:
                try:
                    category_files[output_file] = open(output_file, "a", newline='\n')
                except PermissionError:
                    print(f"Error: Cannot write to '{output_file}'. Check permissions.")
                    exit(1)
            category_files[output_file].write(f"{name} {url} {dest_subfolder}\n")

    for file in category_files.values():
        file.close()

    print(f"Successfully split '{input_file}' into '{output_dir}'.")

if __name__ == "__main__":
    split_tools_file()