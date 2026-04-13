#!/bin/bash

###############################################################################
# submission_worker.sh
# This script receives 5 arguments:
#   1) JSON_DIR_API
#   2) SUBMISSION_DIR
#   3) TAR_FILENAME
#   4) YESTERDAY_OUTPUT
#   5) PROVIDER
###############################################################################

# 1. Source environment file if needed
ENV_FILE="/hps/software/users/literature/textmining-ml/.env_paths"
if [ -f "$ENV_FILE" ]; then
    if source "$ENV_FILE"; then
        echo "SUBMISSION_SCRIPT: Loaded environment file from $ENV_FILE"
    else
        echo "Error: SUBMISSION_SCRIPT: Could not load environment file from $ENV_FILE"
        exit 1
    fi
else
    echo "Error: SUBMISSION_SCRIPT: Environment file not found at $ENV_FILE"
    exit 1
fi

# 2. Parse the 5 positional arguments
JSON_DIR_API="$1"
SUBMISSION_DIR="$2"
TAR_FILENAME="$3"
YESTERDAY_OUTPUT="$4"
PROVIDER="$5"

# 3. Validate the arguments
[ -z "$JSON_DIR_API" ] && { echo "Error: Missing JSON_DIR_API"; exit 1; }
[ -z "$SUBMISSION_DIR" ] && { echo "Error: Missing SUBMISSION_DIR"; exit 1; }
[ -z "$TAR_FILENAME" ] && { echo "Error: Missing TAR_FILENAME"; exit 1; }
[ -z "$YESTERDAY_OUTPUT" ] && { echo "Error: Missing YESTERDAY_OUTPUT"; exit 1; }
[ -z "$PROVIDER" ] && { echo "Error: Missing PROVIDER"; exit 1; }

echo "SUBMISSION_SCRIPT running with arguments:"
echo "  JSON_DIR_API:     $JSON_DIR_API"
echo "  SUBMISSION_DIR:   $SUBMISSION_DIR"
echo "  TAR_FILENAME:     $TAR_FILENAME"
echo "  YESTERDAY_OUTPUT: $YESTERDAY_OUTPUT"
echo "  PROVIDER:         $PROVIDER"

# Ensure submission directory exists
mkdir -p "$SUBMISSION_DIR" || {
    echo "Error: Could not create or access $SUBMISSION_DIR"
    exit 1
}

# 4. Count matching files (example: patch-2024_10_27-*.api.json)
FILE_PATTERN="patch-${YESTERDAY_OUTPUT}-*.api.json"
echo "Looking for files with pattern: ${FILE_PATTERN} in directory: ${JSON_DIR_API}"

#FILE_COUNT=$(find "${JSON_DIR_API}" -name "${FILE_PATTERN}" | wc -l)
FILE_COUNT=$(find "${JSON_DIR_API}" -maxdepth 1 -name "${FILE_PATTERN}" -type f | wc -l)
echo "Number of source files in $JSON_DIR_API matching $FILE_PATTERN: $FILE_COUNT"

if [ "$FILE_COUNT" -eq 0 ]; then
    echo "No files found matching pattern: ${JSON_DIR_API}/${FILE_PATTERN}"
    echo "Submission script will exit, doing nothing."
    exit 0
fi

# 5. Check if the tar file already exists
TAR_PATH="${SUBMISSION_DIR}/${TAR_FILENAME}"
if [ -f "$TAR_PATH" ]; then
    echo "Tar file $TAR_PATH already exists. Skipping creation."
else
    # 6. Create the tar file and/or upload to MinIO
    echo "Creating tar files "

    /hps/software/users/literature/annotation_submission_system/production/submit_file_to_minio_split.sh \
        "$JSON_DIR_API" \
        "$SUBMISSION_DIR" \
        "$TAR_FILENAME" \
        "$YESTERDAY_OUTPUT" \
        "$PROVIDER"

    if [ $? -ne 0 ]; then
        echo "Error: External script to create or upload tar failed."
        exit 1
    fi
fi

echo "SUBMISSION_SCRIPT completed successfully."
exit 0

