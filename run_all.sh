#!/bin/bash

# === Preserve terminal color ===
export TERM=${TERM:-xterm-256color}

# === Get absolute script directory ===
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === Add apt-install FIRST ===
APT_DIR="$BASE_DIR/apt-install"
TOOL_DIRS=()
if [[ -f "$APT_DIR/install.sh" ]]; then
    TOOL_DIRS+=("$APT_DIR")
fi

# === Add all other folders with install.sh (excluding apt-install again) ===
mapfile -t OTHER_DIRS < <(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d \
  -not -name "apt-install" \
  -exec test -f "{}/install.sh" \; -print)

TOOL_DIRS+=("${OTHER_DIRS[@]}")

# === Exit if no tools found ===
if [[ ${#TOOL_DIRS[@]} -eq 0 ]]; then
    echo -e "[\e[31m✗\e[0m] No installable tools found."
    exit 1
fi

# === Display Menu ===
echo -e "\e[1;36m========= Tool Installer =========\e[0m"
for i in "${!TOOL_DIRS[@]}"; do
    tool_name=$(basename "${TOOL_DIRS[$i]}")
    printf "[ %2d ] %s\n" "$((i + 1))" "$tool_name"
done
echo "[  0 ] Install ALL"
echo -e "\e[1;36m==================================\e[0m"

# === Get User Selection ===
read -rp "Enter the number(s) of the tools to install (e.g., 1 3 4) or 0 for all: " -a choices

# === Install Function ===
run_install() {
    local dir="$1"
    local name
    name=$(basename "$dir")
    local script="$dir/install.sh"

    echo -e "\n==========[ Installing: \e[33m$name\e[0m ]=========="

    if [[ ! -x "$script" ]]; then
        chmod +x "$script"
        echo -e "[*] Made \e[36m$script\e[0m executable"
    fi

    pushd "$dir" > /dev/null
    if ./install.sh; then
        echo -e "[\e[32m✓\e[0m] Completed: $name"
    else
        echo -e "[\e[31m✗\e[0m] Failed: $name — skipping to next"
    fi
    popd > /dev/null

    # === Print tools/*.txt (except for apt-install) ===
    if [[ "$name" != "apt-install" ]]; then
        local tools_dir="$dir/tools"
        if [[ -d "$tools_dir" ]]; then
            echo -e "\n[\e[36mℹ\e[0m] Tools under $name:"
            find "$tools_dir" -type f -name "*.txt" | while read -r file; do
                echo -e "    ➤ \e[34m$file\e[0m"
            done
        else
            echo -e "[\e[33m!\e[0m] No tools/ directory found in $name."
        fi
    fi
}

# === Install Selected Tools ===
if [[ " ${choices[*]} " =~ " 0 " ]]; then
    for dir in "${TOOL_DIRS[@]}"; do
        run_install "$dir"
    done
else
    for choice in "${choices[@]}"; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#TOOL_DIRS[@]} )); then
            run_install "${TOOL_DIRS[$((choice - 1))]}"
        else
            echo -e "[\e[33m!\e[0m] Invalid selection: $choice"
        fi
    done
fi

# === Completion Message ===
echo -e "\n==========[ \e[1;32mInstallation Complete\e[0m ]=========="
echo "All selected tools have been processed."
echo -e "\e[1;36m=============================================\e[0m"
echo "Thank you for using the Tool Installer!"
echo -e "\e[1;36m=============================================\e[0m"
