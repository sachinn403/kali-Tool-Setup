#!/bin/bash

BASE_DIR="/opt/bugbounty"
LOGFILE="/tmp/bugbounty_tools_list_$(date +%F_%H-%M-%S).log"
exec > >(tee -a "$LOGFILE") 2>&1
echo "Listing installed bug bounty tools at $(date)"

find "$BASE_DIR" -type d -maxdepth 2 | while read -r dir; do
    if [ -d "$dir" ]; then
        echo "Found: $dir"
        ls -l "$dir"
    fi
done

echo "Listing complete. Check $LOGFILE for details."