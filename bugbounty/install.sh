#!/bin/bash

# Ensure script runs with sudo
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Set up logging
LOGFILE="/tmp/bugbounty_tools_install_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "Starting bug bounty tools installation at $(date)"

# Install dependencies
echo "Installing dependencies..."
apt-get update -y
apt-get install -y git python3 python3-pip golang-go unzip ruby-dev build-essential libssl-dev libffi-dev python2 python2-dev

# Install Go if not present
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
    rm go1.22.5.linux-amd64.tar.gz
    echo "export PATH=\$PATH:/usr/local/go/bin" >> /root/.bashrc
    export PATH=$PATH:/usr/local/go/bin
fi

# Set up directories
BASE_DIR="/opt/bugbounty"
TOOLS_DIR="$HOME/Desktop/uploads/Tool-Setup/bugbounty"
mkdir -p "$BASE_DIR"
cd "$TOOLS_DIR" || { echo "Failed to change to $TOOLS_DIR"; exit 1; }

# Check for tools.txt
if [ ! -f "tools/tools.txt" ]; then
    echo "Error: tools/tools.txt not found in $TOOLS_DIR"
    exit 1
fi

# Run split.py to generate category files
if [ -f "split.py" ]; then
    echo "Splitting tools.txt into category files..."
    python3 split.py
else
    echo "Error: split.py not found in $TOOLS_DIR"
    exit 1
fi

# Install tools
while IFS= read -r line; do
    if [ -z "$line" ]; then
        continue
    fi
    TYPE=$(echo "$line" | awk '{print $1}')
    NAME=$(echo "$line" | awk '{print $2}')
    URL=$(echo "$line" | awk '{print $3}')
    CATEGORY=$(echo "$line" | awk '{print $4}')
    DEST_DIR="$BASE_DIR/$CATEGORY/$NAME"
    mkdir -p "$DEST_DIR"
    echo "Installing $NAME in $DEST_DIR..."

    case "$TYPE" in
        git)
            git clone "$URL" "$DEST_DIR"
            if [ $? -eq 0 ]; then
                echo "$NAME cloned successfully"
                cd "$DEST_DIR"
                if [ -f "requirements.txt" ]; then
                    pip3 install -r requirements.txt
                elif [ -f "setup.py" ]; then
                    python3 setup.py install || python2 setup.py install
                fi
                if [ -f "Makefile" ]; then
                    make
                fi
                cd "$TOOLS_DIR"
            else
                echo "Failed to clone $NAME"
            fi
            ;;
        pip)
            pip3 install "$NAME"
            if [ $? -eq 0 ]; then
                echo "$NAME installed via pip"
                cp "$(which $NAME)" "$DEST_DIR/" 2>/dev/null || echo "No binary for $NAME"
            else
                echo "Failed to install $NAME via pip"
            fi
            ;;
        apt)
            apt-get install -y "$NAME"
            if [ $? -eq 0 ]; then
                echo "$NAME installed via apt"
                cp "$(which $NAME)" "$DEST_DIR/" 2>/dev/null || echo "No binary for $NAME"
            else
                echo "Failed to install $NAME via apt"
            fi
            ;;
        go)
            /usr/local/go/bin/go install "$URL"
            if [ $? -eq 0 ]; then
                echo "$NAME installed via go"
                mv ~/go/bin/* "$DEST_DIR/" 2>/dev/null || echo "No binary for $NAME"
            else
                echo "Failed to install $NAME via go"
            fi
            ;;
        binary)
            if [ -f "download_release.py" ]; then
                python3 download_release.py "$URL" "$DEST_DIR"
                if [ $? -eq 0 ]; then
                    echo "$NAME binary downloaded"
                    chmod +x "$DEST_DIR"/*
                else
                    echo "Failed to download $NAME binary"
                fi
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

# Special handling for Arachni (manual download)
echo "Handling Arachni manual installation..."
cd "$BASE_DIR/Frameworks/Arachni"
wget http://www.arachni-scanner.com/downloads/arachni-latest.tar.gz || echo "Failed to download Arachni; visit http://www.arachni-scanner.com/"
if [ -f "arachni-latest.tar.gz" ]; then
    tar -xzf arachni-latest.tar.gz
    cd arachni-* || echo "Failed to enter Arachni directory"
    ./bin/arachni --help 2>/dev/null || echo "Arachni requires manual setup; check $BASE_DIR/Frameworks/Arachni"
fi

# Clean up
cd "$TOOLS_DIR"
echo "Installation complete. Check $LOGFILE for details."