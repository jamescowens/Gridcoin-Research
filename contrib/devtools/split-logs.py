#!/usr/bin/env python3

import sys
import re

def clean_filename(name):
    """
    Sanitizes the job name to create a valid filename.
    Replaces non-alphanumeric characters (except hyphen) with underscores.
    """
    # Replace non-alphanumeric chars (except hyphen) with underscores, strip leading/trailing underscores
    clean = re.sub(r'[^\w\-]', '_', name).strip('_')
    # Squeeze multiple underscores to a single one
    clean = re.sub(r'_+', '_', clean)
    return f"{clean}.log"

def main():
    # Regex to match Act output format: [Job Name]    | Message
    log_pattern = re.compile(r'^\[([^\]]+)\]\s*\|\s?(.*)')

    # Dictionary to hold all open file handles
    file_handles = {}

    # Store the input source; defaults to stdin
    source = sys.stdin

    # Flag to track if we opened the file ourselves (and need to close it)
    opened_file = False

    # --- INPUT SETUP (Using context manager for file argument) ---
    if len(sys.argv) > 1:
        try:
            # Open the file argument and assign it to source
            source = open(sys.argv[1], 'r', encoding="utf-8", errors='replace')
            opened_file = True # Mark that we need to close this file later
        except FileNotFoundError:
            print(f"Error: File '{sys.argv[1]}' not found.")
            sys.exit(1)

    print("Processing logs...")

    # --- MAIN PROCESSING LOGIC (Using try...finally for cleanup) ---
    try:
        for line in source:
            match = log_pattern.match(line)
            if match:
                job_name = match.group(1)
                message = match.group(2)

                # If we haven't seen this job yet, open a new file for it
                if job_name not in file_handles:
                    fname = clean_filename(job_name)
                    print(f"  -> Found new job: '{job_name}' -> writing to '{fname}'")
                    # Note: We keep this handle open in the dictionary until the end
                    file_handles[job_name] = open(fname, 'w', encoding="utf-8")

                # Write the cleaned message to the specific job file
                file_handles[job_name].write(message + '\n')

    finally:
        # --- CLEANUP ---
        # 1. Close all dynamically opened job files
        print("Finalizing and closing job files...")
        for fh in file_handles.values():
            try:
                # Explicitly close each job file handle to flush buffers
                fh.close()
            except Exception as e:
                # Handle potential errors during closing (e.g., if already closed)
                print(f"Warning: Could not close file handle: {e}")

        # 2. Close the input source if it was a file opened by the script
        if opened_file:
            source.close()


    print("Done. Logs split successfully.")

if __name__ == "__main__":
    main()
