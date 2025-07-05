#!/bin/bash

# ─────────────────────────────────────────────────────
# MOBILE TOOLS INSTALLER (Dynamic, Safe)
# Author: Sachin Nishad
# ─────────────────────────────────────────────────────

set -euo pipefail

if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR"
BASE_DIR="/opt/mobile"
LOGFILE="/tmp/mobile_tools_install_$(date +%F_%H-%M-%S).log"

exec > >(tee -a "$LOGFILE") 2>&1
echo "Starting mobile tools installation at $(date)"

# ─────────────────────────────────────────────────────
# Dependencies
# ─────────────────────────────────────────────────────
echo "Installing dependencies..."
apt-get update -y
apt-get install -y git python3 python3-pip golang-go unzip default-jdk docker.io

# Install Go if not already present
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
    rm go1.22.5.linux-amd64.tar.gz
    echo "export PATH=\$PATH:/usr/local/go/bin" >> /root/.bashrc
    export PATH=$PATH:/usr/local/go/bin
fi

# Enable Docker
systemctl start docker
systemctl enable docker

mkdir -p "$BASE_DIR"
cd "$TOOLS_DIR" || { echo "Failed to change to $TOOLS_DIR"; exit 1; }

# ─────────────────────────────────────────────────────
# Tool Install
# ─────────────────────────────────────────────────────
if [ ! -f "tools/tools.txt" ]; then
    echo "Error: tools/tools.txt not found in $TOOLS_DIR"
    exit 1
fi

# Run split.py
if [ -f "tools/split.py" ]; then
    echo "Splitting tools.txt into categories..."
    python3 tools/split.py
else
    echo "Error: split.py not found in tools/"
    exit 1
fi

while IFS= read -r line; do
    [[ -z "$line" ]] && continue

    TYPE=$(echo "$line" | awk '{print $1}')
    NAME=$(echo "$line" | awk '{print $2}')
    URL=$(echo "$line" | awk '{print $3}')
    CATEGORY=$(echo "$line" | awk '{print $4}')
    DEST_DIR="$BASE_DIR/$CATEGORY/$NAME"

    mkdir -p "$DEST_DIR"
    echo "Installing $NAME into $DEST_DIR..."

    case "$TYPE" in
        git)
            git clone "$URL" "$DEST_DIR" && cd "$DEST_DIR"
            [[ -f "requirements.txt" ]] && pip3 install -r requirements.txt
            [[ -f "setup.py" ]] && python3 setup.py install || python2 setup.py install
            [[ -f "Makefile" ]] && make
            cd "$TOOLS_DIR"
            ;;
        pip)
            pip3 install "$NAME" && cp "$(command -v "$NAME" 2>/dev/null || true)" "$DEST_DIR/" || echo "Binary for $NAME not found"
            ;;
        binary)
            if [ -f "tools/download_release.py" ]; then
                python3 tools/download_release.py "$URL" "$DEST_DIR"
                chmod +x "$DEST_DIR"/* || true
            else
                echo "download_release.py not found"
            fi
            ;;
        manual)
            echo "Manual install required: $URL"
            ;;
        *)
            echo "Unknown install type: $TYPE"
            ;;
    esac
done < "tools/tools.txt"

# ─────────────────────────────────────────────────────
# apktool handling
# ─────────────────────────────────────────────────────
echo "Handling apktool manual download..."
APK_DIR="$BASE_DIR/Android_Tools/apktool"
mkdir -p "$APK_DIR"
cd "$APK_DIR"

wget https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.10.0.jar -O apktool.jar || echo "Visit https://ibotpeaches.github.io/Apktool/"
chmod +x apktool.jar
echo -e "#!/bin/bash\njava -jar \"$APK_DIR/apktool.jar\" \"\$@\"" > apktool
chmod +x apktool

# ─────────────────────────────────────────────────────
# SDK Tools
# ─────────────────────────────────────────────────────
echo "Handling Android SDK tools setup..."
SDK_DIR="$BASE_DIR/SDK_JDK_Tools"
mkdir -p "$SDK_DIR"
cd "$SDK_DIR"
wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip -O sdk.zip
unzip -q sdk.zip && rm sdk.zip

for tool in adb aapt apksigner zipalign; do
    mkdir -p "$tool"
    mv platform-tools/"$tool" "$tool/$tool"
    chmod +x "$tool/$tool"
done
rm -rf platform-tools

# ─────────────────────────────────────────────────────
# MobSF Docker
# ─────────────────────────────────────────────────────
echo "Setting up MobSF in Docker..."
MOBSF_DIR="$BASE_DIR/Android_Tools/MobSF"
mkdir -p "$MOBSF_DIR"
cd "$MOBSF_DIR"

if ! docker ps | grep -q "mobile-security-framework"; then
    docker pull opensecurity/mobile-security-framework-mobsf
    docker run -d -p 8000:8000 opensecurity/mobile-security-framework-mobsf
else
    echo "MobSF container already running"
fi

# ─────────────────────────────────────────────────────
# Wrap up
# ─────────────────────────────────────────────────────
cd "$TOOLS_DIR"
echo "Installation complete. Log saved to $LOGFILE"
