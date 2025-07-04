#!/bin/bash

# Ensure script runs with sudo
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root. Use sudo."
    exit 1
fi

# Set up logging
LOGFILE="/tmp/mobile_tools_install_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "Starting mobile tools installation at $(date)"

# Install dependencies
echo "Installing dependencies..."
apt-get update -y
apt-get install -y git python3 python3-pip golang-go unzip default-jdk docker.io

# Install Go if not present
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.22.5.linux-amd64.tar.gz
    rm go1.22.5.linux-amd64.tar.gz
    echo "export PATH=\$PATH:/usr/local/go/bin" >> /root/.bashrc
    export PATH=$PATH:/usr/local/go/bin
fi

# Start Docker service for MobSF
systemctl start docker
systemctl enable docker

# Set up directories
BASE_DIR="/opt/mobile"
TOOLS_DIR="/home/kali/Desktop/uploads/Tool-Setup/mobile"
if [ ! -d "$TOOLS_DIR" ]; then
    echo "Error: Directory $TOOLS_DIR does not exist"
    exit 1
fi
cd "$TOOLS_DIR" || { echo "Failed to change to $TOOLS_DIR"; exit 1; }
mkdir -p "$BASE_DIR"

# Check for tools.txt
if [ ! -f "tools/tools.txt" ]; then
    echo "Error: tools/tools.txt not found in $TOOLS_DIR"
    exit 1
fi

# Run split.py to generate category files
if [ -f "tools/split.py" ]; then
    echo "Splitting tools.txt into category files..."
    python3 tools/split.py
else
    echo "Error: split.py not found in $TOOLS_DIR/tools"
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
        binary)
            if [ -f "tools/download_release.py" ]; then
                python3 tools/download_release.py "$URL" "$DEST_DIR"
                if [ $? -eq 0 ]; then
                    echo "$NAME binary downloaded"
                    chmod +x "$DEST_DIR"/*
                else
                    echo "Failed to download $NAME binary"
                fi
            else
                echo "Error: download_release.py not found in $TOOLS_DIR/tools"
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

# Special handling for apktool
echo "Handling apktool manual download..."
cd "$BASE_DIR/Android_Tools/apktool"
wget https://bitbucket.org/iBotPeaches/apktool/downloads/apktool_2.10.0.jar || echo "Failed to download apktool; visit https://ibotpeaches.github.io/Apktool/"
if [ -f "apktool_2.10.0.jar" ]; then
    mv apktool_2.10.0.jar apktool.jar
    chmod +x apktool.jar
    echo "#!/bin/bash" > apktool
    echo "java -jar $DEST_DIR/apktool.jar \"\$@\"" >> apktool
    chmod +x apktool
fi

# Special handling for SDK tools (adb, aapt, apksigner, zipalign)
echo "Handling SDK tools installation..."
cd "$BASE_DIR/SDK_JDK_Tools"
wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip
if [ -f "platform-tools-latest-linux.zip" ]; then
    unzip platform-tools-latest-linux.zip
    mv platform-tools/adb adb/adb
    mv platform-tools/aapt aapt/aapt
    mv platform-tools/apksigner apksigner/apksigner
    mv platform-tools/zipalign zipalign/zipalign
    chmod +x adb/adb aapt/aapt apksigner/apksigner zipalign/zipalign
    rm -rf platform-tools platform-tools-latest-linux.zip
fi

# Special handling for MobSF (Docker option)
echo "Setting up MobSF with Docker..."
cd "$BASE_DIR/Android_Tools/MobSF"
docker pull opensecurity/mobile-security-framework-mobsf
docker run -d -p 8000:8000 opensecurity/mobile-security-framework-mobsf

# Clean up
cd "$TOOLS_DIR"
echo "Installation complete. Check $LOGFILE for details."