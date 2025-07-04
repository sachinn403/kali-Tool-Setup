#!/usr/bin/env python3
import requests
import os
import sys

def download_latest_release(repo_url, dest_dir):
    repo_name = repo_url.split('/')[-1]
    repo_path = repo_url.split("github.com/")[1]
    if repo_path.endswith(".git"):
        repo_path = repo_path[:-4]

    try:
        os.makedirs(dest_dir, exist_ok=True)
        api_url = f"https://api.github.com/repos/{repo_path}/releases/latest"
        
        headers = {}
        if 'GITHUB_TOKEN' in os.environ:
            headers['Authorization'] = f"token {os.environ['GITHUB_TOKEN']}"
        
        response = requests.get(api_url, headers=headers)
        response.raise_for_status()
        release_data = response.json()
        assets = release_data.get('assets', [])
        
        if not assets:
            print(f"[!] No assets found for {repo_name}")
            return False

        for asset in assets:
            asset_url = asset['browser_download_url']
            if 'linux' in asset_url.lower() or 'amd64' in asset_url.lower():
                asset_name = asset['name']
                dest_path = os.path.join(dest_dir, asset_name)
                print(f"[+] Downloading {asset_name} to {dest_path}")
                with requests.get(asset_url, stream=True) as r:
                    r.raise_for_status()
                    with open(dest_path, 'wb') as f:
                        for chunk in r.iter_content(chunk_size=8192):
                            f.write(chunk)
                print(f"[✓] Successfully downloaded {asset_name}")
                return dest_path

        print(f"[!] No suitable Linux asset found for {repo_name}")
        return False

    except Exception as e:
        print(f"[X] Error downloading release for {repo_name}: {e}")
        return False
