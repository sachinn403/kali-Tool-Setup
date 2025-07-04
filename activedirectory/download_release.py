#!/usr/bin/env python3
import os
import re
import requests

def get_latest_release_url(repo, pattern):
    api_url = f"https://api.github.com/repos/{repo}/releases/latest"
    headers = {}
    if "GITHUB_TOKEN" in os.environ:
        headers["Authorization"] = f"token {os.environ['GITHUB_TOKEN']}"
    try:
        response = requests.get(api_url, headers=headers, timeout=10)
        response.raise_for_status()
        release = response.json()
        for asset in release["assets"]:
            if re.search(pattern, asset["name"]):
                return asset["browser_download_url"]
        print(f"No asset matching '{pattern}' found in {repo}")
        return None
    except requests.RequestException as e:
        print(f"Error fetching release for {repo}: {e}")
        return None

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 3:
        print("Usage: download_release.py <repo> <pattern>")
        sys.exit(1)
    repo, pattern = sys.argv[1], sys.argv[2]
    url = get_latest_release_url(repo, pattern)
    if url:
        print(url)
        
