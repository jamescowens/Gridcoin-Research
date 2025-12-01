#!/usr/bin/env python3

import sys
import re

def clean_filename(name):
    """
    Sanitizes the job name to create a valid filename.
    Replaces non-alphanumeric characters with underscores.
    """
    # Replace non-alphanumeric chars with underscores, strip leading/trailing underscores
    clean = re.sub(r'[^\w\-]', '_', name).strip('_')
    # Squeeze multiple underscores to a single one
    clean = re.sub(r'_+', '_', clean)
    return f"{clean}.log"

def main():
    # Read from file argument if provided, otherwise read from stdin
    if len(sys.argv) > 1:
        try:
            source = open(sys.argv[1], 'r', encoding="utf-8", errors='replace')
        except FileNotFoundError:
            print(f"Error: File '{sys.argv[1]}' not found.")
            sys.exit(1)
    else:
        source = sys.stdin

    # Regex to match Act output format: [Job Name]   | Message
    # Example: [CMake Production Builds (Depends)/Windows Cross-Compile]   | ...
    log_pattern = re.compile(r'^\[([^\]]+)\]\s*\|\s?(.*)')

    file_handles = {}

    print("Processing logs...")

    for line in source:
        match = log_pattern.match(line)
        if match:
            job_name = match.group(1)
            message = match.group(2)

            # If we haven't seen this job yet, open a new file for it
            if job_name not in file_handles:
                fname = clean_filename(job_name)
                print(f"  -> Found new job: '{job_name}' -> writing to '{fname}'")
                file_handles[job_name] = open(fname, 'w', encoding="utf-8")

            # Write the cleaned message to the specific job file
            file_handles[job_name].write(message + '\n')

    # Cleanup: Close all open file handles
    for f in file_handles.values():
        f.close()

    if source is not sys.stdin:
        source.close()

    print("Done. Logs split successfully.")

if __name__ == "__main__":
    main()
