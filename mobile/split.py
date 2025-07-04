#!/usr/bin/env python3
import os

def split_tools_file():
    categories = {}
    with open('tools.txt', 'r') as f:
        for line in f:
            if line.strip():
                parts = line.strip().split()
                if len(parts) >= 3:
                    category = parts[-1]
                    if category not in categories:
                        categories[category] = []
                    categories[category].append(line.strip())

    for category, tools in categories.items():
        with open(f'tools/{category}.txt', 'w') as f:
            for tool in tools:
                f.write(tool + '\n')

if __name__ == '__main__':
    os.makedirs('tools', exist_ok=True)
    os.chdir('tools')
    split_tools_file()