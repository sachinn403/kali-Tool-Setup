#!/bin/bash

# Enforce strict error handling (except in process_tool_file)
set -uo pipefail

# Base directory and log file
BASE_DIR="/opt/activedirectory"
TOOLS_DIR="tools"
LOG_FILE="/tmp/ad_tools_install_$(date +%F_%H-%M-%S).log"
YOUR_USER="${YOUR_USER:-$(whoami)}"
YOUR_GROUP="${YOUR_GROUP:-$(id -gn "$YOUR_USER")}"

# Function to log messages
log() {
  echo "$1" | tee -a "$LOG_FILE"
  [[ "$1" =~ ^\[✗\] ]] && echo "$1" >&2  # Print errors to stderr
}

# Create log file
touch "$LOG_FILE" 2>/dev/null || { log "[✗] Error: Cannot write to $LOG_FILE"; exit 1; }
chmod 644 "$LOG_FILE"

# Check dependencies
log "[*] Checking dependencies..."
DEPENDENCIES=("curl" "git" "unzip" "7z" "python3" "python3-pip" "golang-go" "dos2unix")
MISSING_DEPS=()
for dep in "${DEPENDENCIES[@]}"; do
  if ! command -v "$dep" >/dev/null; then
    MISSING_DEPS+=("$dep")
  fi
done
if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
  log "[!] Missing dependencies: ${MISSING_DEPS[*]}"
  log "[+] Attempting to install missing dependencies..."
  if ! sudo apt update && sudo apt install -y "${MISSING_DEPS[@]}" >> "$LOG_FILE" 2>&1; then
    log "[✗] Failed to install dependencies: ${MISSING_DEPS[*]}. Please install manually."
    exit 1
  fi
  log "[✓] Dependencies installed successfully."
else
  log "[✓] All dependencies are installed."
fi

# Convert all .txt files in tools/ to Unix format
log "[*] Converting .txt files in $TOOLS_DIR to Unix format..."
if [[ -d "$TOOLS_DIR" ]]; then
  for file in "$TOOLS_DIR"/*.txt; do
    [[ -f "$file" ]] || continue
    if sudo dos2unix "$file" >> "$LOG_FILE" 2>&1; then
      log "[✓] Converted $file to Unix format."
    else
      log "[✗] Failed to convert $file to Unix format."
    fi
  done
else
  log "[✗] Error: $TOOLS_DIR directory not found!"
  exit 1
fi

# Verify write access to BASE_DIR
log "[*] Checking write access to $BASE_DIR..."
if ! sudo mkdir -p "$BASE_DIR" || ! sudo touch "$BASE_DIR/.test_write" 2>/dev/null; then
  log "[✗] Error: Cannot write to $BASE_DIR. Check permissions."
  exit 1
fi
sudo rm -f "$BASE_DIR/.test_write"
sudo chmod 755 "$BASE_DIR"

# Create category directories
declare -a CATEGORIES=(
  "ACL" "ADCS" "AD-Enum" "AD-Module" "Adversary-Simulation-Emulation" "Credentials-collection"
  "DCSync" "Delegation" "DNS" "Enumeration" "Evasion-and-bypass" "Exploits" "GPO"
  "Inveigh-NTLM-relay" "Kerberos" "LAPS-gMSA" "Macro-and-WScript" "Mail-Users-Web"
  "Monitor" "PasswordSpray" "Persistence" "Priv-Esc" "Remote-connection" "SMB-Enum"
  "SQL" "SwissArmyKnife" "Utilities" "dot_exe" "dot_ps" "AD-Attack" "SharpCollection"
  "Obfuscation" "Sysinternals" "Mimikatz"
)

for category in "${CATEGORIES[@]}"; do
  category_dir="$BASE_DIR/$category"
  if ! sudo mkdir -p "$category_dir" >> "$LOG_FILE" 2>&1; then
    log "[✗] Error: Failed to create directory $category_dir"
    exit 1
  fi
  sudo chmod 755 "$category_dir"
done

# Function to check GitHub rate limit
check_github_rate_limit() {
  local response
  response=$(curl -s -I https://api.github.com 2>/dev/null)
  remaining=$(echo "$response" | grep -i '^x-ratelimit-remaining:' | cut -d' ' -f2 | tr -d '\r')
  if [[ -n "$remaining" && "$remaining" -eq 0 ]]; then
    log "[✗] GitHub API rate limit exceeded. Set GITHUB_TOKEN environment variable."
    return 1
  fi
  return 0
}

# Function to resolve regex-based GitHub release URLs
resolve_release_url() {
  local repo="$1"
  local pattern="$2"
  local url
  if ! check_github_rate_limit; then
    return 1
  fi
  url=$(python3 download_release.py "$repo" "$pattern" 2>> "$LOG_FILE")
  if [[ -n "$url" ]]; then
    echo "$url"
  else
    log "[✗] Failed to resolve release URL for $repo with pattern $pattern"
    return 1
  fi
}

# Function to process a single tool file
process_tool_file() {
  local file="$1"
  local category=$(basename "$file" .txt | tr -d '\r')
  local count=0
  local total=$(grep -vE '^\s*(#|$)' "$file" | wc -l)

  log "[*] Processing $category ($total tools)..."
  while IFS=' ' read -r name url dest_subfolder || [[ -n "$name" ]]; do
    # Strip \r from fields as a fallback
    name=$(echo "$name" | tr -d '\r')
    url=$(echo "$url" | tr -d '\r')
    dest_subfolder=$(echo "${dest_subfolder:-}" | tr -d '\r')
    # Skip empty or comment lines
    [[ -z "$name" || "$name" =~ ^# ]] && continue
    # Validate line format
    if [[ -z "$url" ]]; then
      log "[✗] Invalid line in $file: '$name $url $dest_subfolder'. Skipping..."
      continue
    fi
    ((count++))

    # Handle regex-based URLs (e.g., repo pattern)
    if [[ "$url" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\ .+\$ ]]; then
      repo=$(echo "$url" | cut -d' ' -f1)
      pattern=$(echo "$url" | cut -d' ' -f2-)
      resolved_url=$(resolve_release_url "$repo" "$pattern")
      if [[ -z "$resolved_url" ]]; then
        log "[✗] Skipping $name due to unresolved URL."
        continue
      fi
      url="$resolved_url"
    fi

    dest_dir="$BASE_DIR/$category/${dest_subfolder:-$name}"
    log "[*] [$count/$total] Processing $name ($url)..."

    # Handle Git repositories
    if [[ "$name" == git:* ]]; then
      repo_name="${name#git:}"
      if [[ -d "$dest_dir/.git" ]] && git -C "$dest_dir" rev-parse --git-dir >/dev/null 2>&1; then
        log "[!] $repo_name already exists at $dest_dir and is a valid Git repo. Skipping..."
        continue
      fi
      log "[+] Cloning $repo_name to $dest_dir..."
      if sudo rm -rf "$dest_dir" && sudo git clone --depth 1 "$url" "$dest_dir" >> "$LOG_FILE" 2>&1; then
        sudo chmod -R 755 "$dest_dir"
        log "[✓] Cloned $repo_name successfully."
      else
        log "[✗] Failed to clone $repo_name. See $LOG_FILE for details."
        continue
      fi
    # Handle file downloads
    else
      dest_path="$dest_dir/$name"
      temp_file="/tmp/$name.$$"
      # Check if extracted contents exist for archives
      if [[ "$name" == *.zip || "$name" == *.7z || "$name" == *.tar.gz || "$name" == *.gz || "$name" == *.exe ]]; then
        if [[ -d "$dest_dir" && -n "$(ls -A "$dest_dir")" ]]; then
          log "[!] $name already extracted at $dest_dir. Skipping..."
          continue
        fi
      elif [[ -f "$dest_path" ]]; then
        log "[!] $name already exists at $dest_path. Skipping..."
        continue
      fi

      log "[+] Downloading $name to $temp_file..."
      curl_cmd=(curl -L -s --fail --max-time 600 --retry 5 --retry-delay 10 -o "$temp_file" "$url")
      [[ -n "${GITHUB_TOKEN:-}" ]] && curl_cmd+=(-H "Authorization: token $GITHUB_TOKEN")
      if sudo "${curl_cmd[@]}" >> "$LOG_FILE" 2>&1; then
        if ! sudo mkdir -p "$dest_dir" >> "$LOG_FILE" 2>&1; then
          log "[✗] Failed to create directory $dest_dir."
          sudo rm -f "$temp_file"
          continue
        fi
        if [[ "$name" == *.zip ]]; then
          log "[+] Extracting $name (zip)..."
          if sudo unzip -o "$temp_file" -d "$dest_dir" >> "$LOG_FILE" 2>&1; then
            log "[✓] Extracted $name successfully."
          else
            log "[✗] Failed to extract $name (zip). Temp file preserved at $temp_file."
            continue
          fi
        elif [[ "$name" == *.7z ]]; then
          log "[+] Extracting $name (7z)..."
          if sudo 7z x "$temp_file" -o"$dest_dir" >> "$LOG_FILE" 2>&1; then
            log "[✓] Extracted $name successfully."
          else
            log "[✗] Failed to extract $name (7z). Temp file preserved at $temp_file."
            continue
          fi
        elif [[ "$name" == *.tar.gz ]]; then
          log "[+] Extracting $name (tar.gz)..."
          if sudo tar -xzf "$temp_file" -C "$dest_dir" >> "$LOG_FILE" 2>&1; then
            log "[✓] Extracted $name successfully."
          else
            log "[✗] Failed to extract $name (tar.gz). Temp file preserved at $temp_file."
            continue
          fi
        elif [[ "$name" == *.gz ]]; then
          log "[+] Extracting $name (gz)..."
          extracted_name="${name%.gz}"
          if sudo gunzip -c "$temp_file" > "$dest_dir/$extracted_name" >> "$LOG_FILE" 2>&1; then
            log "[✓] Extracted $name successfully."
          else
            log "[✗] Failed to extract $name (gz). Temp file preserved at $temp_file."
            continue
          fi
        elif [[ "$name" == *.exe ]]; then
          log "[+] Moving $name to $dest_path..."
          if sudo mv "$temp_file" "$dest_path" >> "$LOG_FILE" 2>&1; then
            log "[✓] Downloaded $name successfully."
          else
            log "[✗] Failed to move $name to $dest_path. Temp file preserved at $temp_file."
            continue
          fi
        else
          log "[+] Moving $name to $dest_path..."
          if sudo mv "$temp_file" "$dest_path" >> "$LOG_FILE" 2>&1; then
            log "[✓] Downloaded $name successfully."
          else
            log "[✗] Failed to move $name to $dest_path. Temp file preserved at $temp_file."
            continue
          fi
        fi
        sudo chmod -R 755 "$dest_dir"
        [[ -f "$temp_file" ]] && sudo rm -f "$temp_file"
      else
        log "[✗] Failed to download $name. Temp file preserved at $temp_file."
        continue
      fi
    fi
  done < <(tr -d '\r' < "$file")  # Fallback: Remove \r from input file
}

# Process all .txt files in tools/ directory
if [[ ! -d "$TOOLS_DIR" ]]; then
  log "[✗] Error: $TOOLS_DIR directory not found!"
  exit 1
fi

for file in "$TOOLS_DIR"/*.txt; do
  [[ -f "$file" ]] || { log "[!] No .txt files found in $TOOLS_DIR. Skipping..."; continue; }
  # Disable set -e for the loop to continue on errors
  set +e
  process_tool_file "$file"
  set -e
done

# Install PoshC2
if ! command -v poshc2 >/dev/null; then
  log "[*] Installing PoshC2..."
  if sudo curl -sSL https://raw.githubusercontent.com/nettitude/PoshC2/dev/Install.sh | sudo bash -s -- -b dev >> "$LOG_FILE" 2>&1; then
    log "[✓] PoshC2 installed successfully."
  else
    log "[✗] Failed to install PoshC2. See $LOG_FILE for details."
  fi
else
  log "[!] PoshC2 already installed. Skipping..."
fi

# Install kerbrute
if ! command -v kerbrute >/dev/null; then
  log "[*] Installing kerbrute..."
  if sudo go install github.com/ropnop/kerbrute@master >> "$LOG_FILE" 2>&1; then
    sudo cp /root/go/bin/kerbrute /usr/local/bin/kerbrute
    sudo chmod 755 /usr/local/bin/kerbrute
    log "[✓] kerbrute installed successfully."
  else
    log "[✗] Failed to install kerbrute. See $LOG_FILE for details."
  fi
else
  log "[!] kerbrute already installed. Skipping..."
fi

# Install adidnsdump
if ! pip show adidnsdump >/dev/null 2>&1; then
  log "[*] Installing adidnsdump..."
  if sudo pip install git+https://github.com/dirkjanm/adidnsdump#egg=adidnsdump --break-system-packages >> "$LOG_FILE" 2>&1; then
    log "[✓] adidnsdump installed successfully."
  else
    log "[✗] Failed to install adidnsdump. See $LOG_FILE for details."
  fi
else
  log "[!] adidnsdump already installed. Skipping..."
fi

# Install ldapdomaindump
if ! pip show ldapdomaindump >/dev/null 2>&1; then
  log "[*] Installing ldapdomaindump..."
  if sudo pip install ldapdomaindump --break-system-packages >> "$LOG_FILE" 2>&1; then
    log "[✓] ldapdomaindump installed successfully."
  else
    log "[✗] Failed to install ldapdomaindump. See $LOG_FILE for details."
  fi
else
  log "[!] ldapdomaindump already installed. Skipping..."
fi

# Install Spraykatz requirements
if [[ -f "$BASE_DIR/Credentials-collection/spraykatz/requirements.txt" ]] && ! pip show -r "$BASE_DIR/Credentials-collection/spraykatz/requirements.txt" >/dev/null 2>&1; then
  log "[*] Installing Spraykatz requirements..."
  if sudo pip install -r "$BASE_DIR/Credentials-collection/spraykatz/requirements.txt" --break-system-packages >> "$LOG_FILE" 2>&1; then
    log "[✓] Spraykatz requirements installed successfully."
  else
    log "[✗] Failed to install Spraykatz requirements. See $LOG_FILE for details."
  fi
else
  log "[!] Spraykatz requirements already satisfied or not applicable. Skipping..."
fi

# Install APT packages
APT_PACKAGES=(
  git empire bloodhound evil-winrm unicorn responder powershell-empire powersploit
  python3-neo4j python-ldap bloodhound.py crackmapexec certipy-ad impacket
)
log "[*] Installing APT packages..."
INSTALLED_APT=0
for pkg in "${APT_PACKAGES[@]}"; do
  if ! dpkg -s "$pkg" >/dev/null 2>&1; then
    if sudo apt install -y "$pkg" >> "$LOG_FILE" 2>&1; then
      log "[✓] Installed APT package $pkg."
      ((INSTALLED_APT++))
    else
      log "[✗] Failed to install APT package $pkg."
    fi
  else
    log "[!] APT package $pkg already installed. Skipping..."
  fi
done
log "[✓] Installed $INSTALLED_APT/${#APT_PACKAGES[@]} APT packages."

# Create Python virtual environment
VENV_DIR="$BASE_DIR/venv"
if [[ ! -d "$VENV_DIR" ]]; then
  log "[*] Creating Python virtual environment in $VENV_DIR..."
  if python3 -m venv "$VENV_DIR" >> "$LOG_FILE" 2>&1; then
    log "[✓] Virtual environment created."
    source "$VENV_DIR/bin/activate"
    "$VENV_DIR/bin/pip" install --upgrade pip >> "$LOG_FILE" 2>&1
    PIP_PACKAGES=(certipy-ad impacket)
    for pkg in "${PIP_PACKAGES[@]}"; do
      if ! "$VENV_DIR/bin/pip" show "$pkg" >/dev/null 2>&1; then
        if "$VENV_DIR/bin/pip" install "$pkg" >> "$LOG_FILE" 2>&1; then
          log "[✓] $pkg installed in virtual environment."
        else
          log "[✗] Failed to install $pkg in virtual environment."
        fi
      else
        log "[!] $pkg already installed in virtual environment. Skipping..."
      fi
    done
    deactivate
  else
    log "[✗] Failed to create virtual environment. See $LOG_FILE for details."
  fi
else
  log "[!] Virtual environment already exists at $VENV_DIR. Skipping..."
fi

# Copy .exe and .ps1 files to dot_exe and dot_ps
log "[*] Copying .exe files to $BASE_DIR/dot_exe..."
find "$BASE_DIR" -type f -name "*.exe" -not -path "$BASE_DIR/dot_exe/*" -exec sudo cp {} "$BASE_DIR/dot_exe/" \; >> "$LOG_FILE" 2>&1
sudo chmod -R 755 "$BASE_DIR/dot_exe"

log "[*] Copying .ps1 files to $BASE_DIR/dot_ps..."
find "$BASE_DIR" -type f -name "*.ps*1" -not -path "$BASE_DIR/dot_ps/*" -exec sudo cp {} "$BASE_DIR/dot_ps/" \; >> "$LOG_FILE" 2>&1
sudo chmod -R 755 "$BASE_DIR/dot_ps"

# Fix ownership
if id "$YOUR_USER" >/dev/null 2>&1; then
  log "[*] Checking ownership of $BASE_DIR..."
  if [[ $(stat -c '%U:%G' "$BASE_DIR") != "$YOUR_USER:$YOUR_GROUP" ]]; then
    log "[+] Fixing ownership to $YOUR_USER:$YOUR_GROUP"
    if sudo chown -R "$YOUR_USER:$YOUR_GROUP" "$BASE_DIR" >> "$LOG_FILE" 2>&1; then
      log "[✓] Ownership fixed successfully."
    else
      log "[✗] Failed to fix ownership. See $LOG_FILE for details."
    fi
  else
    log "[!] Ownership already set to $YOUR_USER:$YOUR_GROUP. Skipping..."
  fi
else
  log "[!] WARNING: User '$YOUR_USER' does not exist. Skipping ownership fix."
fi

log "[✓] Active Directory tools installation complete."
log "[*] Tools installed in $BASE_DIR. Log file: $LOG_FILE"



# There are no more steps to execute.
#!/bin/bash

# Define tools with destination folder names (not full paths!)
TOOLS_LIST=(
  "https://download.sysinternals.com/files/SysinternalsSuite.zip Sysinternals"
  "https://download.sysinternals.com/files/AdExplorer.zip AdExplorer"
  "https://github.com/gentilkiwi/mimikatz/releases/download/2.2.0-20210810-2/mimikatz_trunk.zip mimikatz"
)

echo "[*] Starting single-time download to /tmp and dual extraction to /opt..."

for entry in "${TOOLS_LIST[@]}"; do
  URL=$(echo "$entry" | awk '{print $1}')
  TOOL_FOLDER=$(echo "$entry" | awk '{print $2}')
  FILE_NAME=$(basename "$URL")
  TEMP_FILE="/tmp/$FILE_NAME"

  echo "[*] Downloading $FILE_NAME to /tmp..."
  if ! curl -sSL --fail --retry 3 --retry-delay 5 -o "$TEMP_FILE" "$URL"; then
    echo "[✗] Failed to download: $URL"
    continue
  fi

  # Destination folders
  DEST1="/opt/windows/$TOOL_FOLDER"
  DEST2="/opt/activedirectory/$TOOL_FOLDER"
  for DEST in "$DEST1" "$DEST2"; do
    echo "[+] Creating directory: $DEST"
    mkdir -p "$DEST"

    if [[ "$FILE_NAME" == *.zip ]]; then
      echo "[+] Extracting $FILE_NAME to $DEST"
      if unzip -o "$TEMP_FILE" -d "$DEST" >/dev/null; then
        echo "[✓] Extracted to $DEST"
      else
        echo "[✗] Failed to unzip to $DEST"
      fi
    else
      echo "[+] Moving $FILE_NAME to $DEST"
      cp "$TEMP_FILE" "$DEST/"
    fi

    chmod -R 755 "$DEST"
  done

  echo "[✓] Done processing $FILE_NAME"
done

echo "[✓] All downloads and extractions completed."
# Clean up temporary files
rm -f /tmp/*.zip
echo "[*] Temporary files cleaned up."  
# End of script
