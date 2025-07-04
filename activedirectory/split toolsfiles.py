#!/usr/bin/env python3
import os
import re

def split_tools_file(input_file="tools.txt", output_dir="tools"):
    # Validate input file
    if not os.path.isfile(input_file):
        print(f"Error: Input file '{input_file}' does not exist.")
        exit(1)

    # Create output directory
    try:
        os.makedirs(output_dir, exist_ok=True)
    except PermissionError:
        print(f"Error: Cannot create directory '{output_dir}'. Check permissions.")
        exit(1)

    current_file = None
    current_category = None

    with open(input_file, "r") as infile:
        for line in infile:
            # Strip \r and \n
            line = line.rstrip('\r\n')
            if not line:
                continue
            if line.startswith("#"):
                # Close previous file if open
                if current_file:
                    current_file.close()
                # Extract category (preserve name, make safe for filenames)
                category = line[1:].strip()
                safe_category = re.sub(r'[^\w\-]', '-', category) + ".txt"
                output_file = os.path.join(output_dir, safe_category)
                try:
                    current_file = open(output_file, "w", newline='\n')
                    current_category = category
                except PermissionError:
                    print(f"Error: Cannot write to '{output_file}'. Check permissions.")
                    exit(1)
            elif current_file:
                # Validate line format (name url [dest_subfolder])
                if len(line.split()) < 2:
                    print(f"Warning: Invalid line in '{input_file}': '{line}'. Skipping...")
                    continue
                # Write line with Unix-style newline
                current_file.write(line + "\n")
            else:
                print(f"Warning: Line '{line}' ignored (no category defined).")

    # Close last file
    if current_file:
        current_file.close()

    print(f"Successfully split '{input_file}' into '{output_dir}'.")

if __name__ == "__main__":
    split_tools_file()
