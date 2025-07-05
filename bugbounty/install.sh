#!/bin/bash

# Ensure script runs with sudo
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Dynamically get current folder (bugbounty/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR"
BASE_DIR="/opt/bugbounty"

# Set up logging
LOGFILE="/tmp/bugbounty_tools_install_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "Starting bug bounty tools installation at $(date)"

# Install dependencies
echo "Installing dependencies..."
apt-get update -y
apt-get install -y git python3 python3-pip golang-go unzip ruby-dev build-essential libssl-dev libffi-dev python2 python2-dev

# Install Go manually if not installed
if ! command -v go &> /dev/null; then
    echo "Installing Go manually..."
    wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
    rm go1.22.5.linux-amd64.tar.gz
    echo "export PATH=\$PATH:/usr/local/go/bin" >> /root/.bashrc
    export PATH=$PATH:/usr/local/go/bin
fi

# Create base install directory
mkdir -p "$BASE_DIR"
cd "$TOOLS_DIR" || { echo "Failed to change to $TOOLS_DIR"; exit 1; }

# Check for tools file
if [ ! -f "tools/tools.txt" ]; then
    echo "Error: tools/tools.txt not found in $TOOLS_DIR"
    exit 1
fi

# Run split.py if it exists
if [ -f "split.py" ]; then
    echo "Splitting tools.txt into category files..."
    python3 split.py
else
    echo "Error: split.py not found in $TOOLS_DIR"
    exit 1
fi

# Process each tool
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    TYPE=$(echo "$line" | awk '{print $1}')
    NAME=$(echo "$line" | awk '{print $2}')
    URL=$(echo "$line" | awk '{print $3}')
    CATEGORY=$(echo "$line" | awk '{print $4}')
    DEST_DIR="$BASE_DIR/$CATEGORY/$NAME"
    mkdir -p "$DEST_DIR"
    echo "Installing $NAME in $DEST_DIR..."

    case "$TYPE" in
        git)
            git clone "$URL" "$DEST_DIR" && {
                echo "$NAME cloned successfully"
                cd "$DEST_DIR"
                [[ -f requirements.txt ]] && pip3 install -r requirements.txt
                [[ -f setup.py ]] && (python3 setup.py install || python2 setup.py install)
                [[ -f Makefile ]] && make
                cd "$TOOLS_DIR"
            } || echo "Failed to clone $NAME"
            ;;
        pip)
            pip3 install "$NAME" && {
                echo "$NAME installed via pip"
                cp "$(command -v $NAME)" "$DEST_DIR/" 2>/dev/null || echo "No binary for $NAME"
            } || echo "Failed to install $NAME via pip"
            ;;
        apt)
            apt-get install -y "$NAME" && {
                echo "$NAME installed via apt"
                cp "$(command -v $NAME)" "$DEST_DIR/" 2>/dev/null || echo "No binary for $NAME"
            } || echo "Failed to install $NAME via apt"
            ;;
        go)
            /usr/local/go/bin/go install "$URL" && {
                echo "$NAME installed via go"
                mv ~/go/bin/* "$DEST_DIR/" 2>/dev/null || echo "No binary for $NAME"
            } || echo "Failed to install $NAME via go"
            ;;
        binary)
            if [ -f "download_release.py" ]; then
                python3 download_release.py "$URL" "$DEST_DIR" && {
                    echo "$NAME binary downloaded"
                    chmod +x "$DEST_DIR"/*
                } || echo "Failed to download $NAME binary"
            else
                echo "Error: download_release.py not found in $TOOLS_DIR"
            fi
            ;;
        manual)
            echo "Manual installation required for $NAME: Visit $URL"
            ;;
        *)
            echo "Unknown installation type for $NAME: $TYPE"
            ;;
    esac
done < "tools/tools.txt"

# Arachni (manual install handling)
echo "Handling Arachni manual installation..."
cd "$BASE_DIR/Frameworks/Arachni" || mkdir -p "$BASE_DIR/Frameworks/Arachni" && cd "$BASE_DIR/Frameworks/Arachni"
wget http://www.arachni-scanner.com/downloads/arachni-latest.tar.gz || echo "Failed to download Arachni"
if [ -f "arachni-latest.tar.gz" ]; then
    tar -xzf arachni-latest.tar.gz
    cd arachni-* || echo "Failed to enter Arachni directory"
    ./bin/arachni --help 2>/dev/null || echo "Arachni requires manual setup; check $BASE_DIR/Frameworks/Arachni"
fi

# Done
cd "$TOOLS_DIR"
echo "Installation complete. Check $LOGFILE for details."
