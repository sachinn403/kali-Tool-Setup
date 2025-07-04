#!/usr/bin/env python3
import requests
import re
import sys
import os

def get_latest_release_url(repo, pattern):
    try:
        api_url = f"https://api.github.com/repos/{repo}/releases/latest"
        headers = {}
        if 'GITHUB_TOKEN' in os.environ:
            headers['Authorization'] = f"token {os.environ['GITHUB_TOKEN']}"
        response = requests.get(api_url, headers=headers, timeout=10)
        response.raise_for_status()
        data = response.json()
        for asset in data.get('assets', []):
            if re.search(pattern, asset['name']):
                return asset['browser_download_url']
        return None
    except requests.RequestException as e:
        print(f"Error fetching release for {repo}: {e}", file=sys.stderr)
        return None

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: download_release.py <owner/repo> <pattern>", file=sys.stderr)
        sys.exit(1)
    repo = sys.argv[1]
    pattern = sys.argv[2]
    url = get_latest_release_url(repo, pattern)
    if url:
        print(url)
    else:
        sys.exit(1)