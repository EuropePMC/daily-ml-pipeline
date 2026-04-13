import os
import glob
import json
import csv

# Base directory containing date-named folders
base_dir = "/nfs/production/literature/santosh_tirunagari/textmining-ml"

# Pattern to match folders for February.
pattern = os.path.join(base_dir, "2025_02_*", "fulltext", "annotations", "metagenomics", "*.json")

# Dictionary to store PMCIDs with the file names where they appear (using a set to avoid duplicate file names)
pmcid_to_files = {}

# Use glob to find all matching JSON files
json_files = glob.glob(pattern)
print(f"Found {len(json_files)} JSON files to process.")

# Process each JSON file
for json_file in json_files:
    try:
        with open(json_file, 'r', encoding='utf-8') as f:
            # Each line is a JSON object
            for line in f:
                try:
                    record = json.loads(line)
                    # Check if the record has an 'id' field that starts with 'PMC'
                    if "id" in record:
                        pmcid = record["id"]
                        if isinstance(pmcid, str) and pmcid.startswith("PMC"):
                            # Use os.path.basename to get only the file name
                            filename = os.path.basename(json_file)
                            if pmcid not in pmcid_to_files:
                                pmcid_to_files[pmcid] = set()
                            pmcid_to_files[pmcid].add(filename)
                except json.JSONDecodeError as e:
                    print(f"Error decoding JSON in file {json_file}: {e}")
    except Exception as e:
        print(f"Error opening file {json_file}: {e}")

# Write the PMCIDs and filenames to a CSV file
csv_file = base_dir+"/pmcid_list.csv"
with open(csv_file, 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(["pmcid", "filename"])  # Write header
    for pmcid, filenames in pmcid_to_files.items():
        # Join filenames with a semicolon if there are multiple files
        writer.writerow([pmcid, ";".join(sorted(filenames))])

print(f"Saved {len(pmcid_to_files)} unique PMCIDs to {csv_file}")

