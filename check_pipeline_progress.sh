#!/bin/bash

###############################################################################
# PIPELINE PROGRESS CHECKER
#
# This script checks the progress of the ML pipeline by scanning the log files
# for success and error messages.
#
# Usage: ./check_pipeline_progress.sh <folder_date>
#
###############################################################################

# Exit on unset variables
set -u

# --- Configuration ---

# Color codes for output
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[0;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_NONE='\033[0m'

# --- Argument and Environment Validation ---

# Check for folder_date argument
if [ -z "${1:-}" ]; then
    echo -e "${COLOR_RED}Error: Missing required argument.${COLOR_NONE}"
    echo "Usage: $0 <folder_date>"
    exit 1
fi
FOLDER_DATE="$1"

# Source environment file to get OUTPUT_BASE_DIR
ENV_FILE="/hps/software/users/literature/textmining-ml/.env_paths"
if [ -f "$ENV_FILE" ]; then
    if ! source "$ENV_FILE"; then
        echo -e "${COLOR_RED}Error: Failed to load environment file from $ENV_FILE.${COLOR_NONE}" >&2
        exit 1
    fi
else
    echo -e "${COLOR_RED}Error: Environment file not found at $ENV_FILE.${COLOR_NONE}" >&2
    exit 1
fi

# Check if OUTPUT_BASE_DIR is set
if [ -z "${OUTPUT_BASE_DIR:-}" ]; then
    echo -e "${COLOR_RED}Error: OUTPUT_BASE_DIR is not set in your environment file.${COLOR_NONE}" >&2
    exit 1
fi

# --- Directory and Path Setup ---

OUTPUT_DIR="${OUTPUT_BASE_DIR}/${FOLDER_DATE}"

if [ ! -d "$OUTPUT_DIR" ]; then
    echo -e "${COLOR_RED}Error: Output directory not found at ${OUTPUT_DIR}.${COLOR_NONE}"
    echo "Please ensure the <folder_date> is correct and the pipeline has started."
    exit 1
fi

echo -e "${COLOR_BLUE}Checking pipeline progress for date: ${FOLDER_DATE}${COLOR_NONE}"
echo -e "${COLOR_BLUE}Output directory: ${OUTPUT_DIR}${COLOR_NONE}"
echo "---------------------------------------------------------------------"

# --- Helper Function ---

# Function to check a specific pipeline stage
# Arguments:
#   $1: Stage Name (e.g., "Abstract Annotation")
#   $2: Log Directory Path
#   $3: Success Message Pattern
#   $4: Total Files Pattern (optional, for array jobs)
check_stage() {
    local stage_name="$1"
    local log_dir="$2"
    local success_pattern="$3"
    local files_pattern="${4:-}"
    
    printf "%-40s" "$stage_name"

    if [ ! -d "$log_dir" ]; then
        echo -e "[ ${COLOR_YELLOW}NOT STARTED${COLOR_NONE} ]"
        return
    fi

    local out_pattern="*.out"
    if [ -n "$files_pattern" ]; then
        out_pattern="$files_pattern"
    fi
    
    local total_logs=$(find "$log_dir" -name "$out_pattern" -type f | wc -l)
    
    if [ "$total_logs" -eq 0 ]; then
        echo -e "[ ${COLOR_YELLOW}PENDING/RUNNING${COLOR_NONE} ]"
        return
    fi

    # Safely count successes without failing on no-matches
    local success_count
    success_count=$(find "$log_dir" -name "$out_pattern" -type f -print0 | xargs -0 --no-run-if-empty grep -lch "$success_pattern" | wc -l)
    
    local error_pattern="*.err"
    if [ -n "$files_pattern" ];
    then
        # Derive error pattern from the .out pattern (e.g., FT-AN_*.out -> FT-AN_*.err)
        error_pattern="${files_pattern/%.out/.err}"
    fi
    local error_count=$(find "$log_dir" -name "$error_pattern" -type f -size +0 | wc -l)

    echo -e "[ ${COLOR_GREEN}Success: ${success_count}${COLOR_NONE} / ${COLOR_RED}Errors: ${error_count}${COLOR_NONE} / Total: ${total_logs} ]"
}

# --- Main Progress Check ---

# Abstract Pipeline
check_stage "Abstract Annotation" \
    "${OUTPUT_DIR}/abstract/logs/annotation_logs" \
    "Abstract annotation tagging completed" \
    "AB-AN_*.out"

check_stage "Abstract Submission" \
    "${OUTPUT_DIR}/abstract/logs/submission_logs" \
    "SUBMISSION_SCRIPT completed successfully"

echo ""

# Fulltext Pipeline
check_stage "Fulltext Section Tagging" \
    "${OUTPUT_DIR}/fulltext/logs/section_logs" \
    "Processed file" \
    "FT-ST_*.out"

check_stage "Fulltext Annotation (Europe PMC)" \
    "${OUTPUT_DIR}/fulltext/logs/annotation_logs" \
    "Full-text annotation tagging completed" \
    "FT-AN_*.out"
    
check_stage "Fulltext Annotation (Metagenomics)" \
    "${OUTPUT_DIR}/fulltext/logs/annotation_logs" \
    "Metagenomics Full-text annotation tagging completed" \
    "MTFT-AN_*.out"

check_stage "Fulltext Submission (Europe PMC)" \
    "${OUTPUT_DIR}/fulltext/logs/submission_logs" \
    "SUBMISSION_SCRIPT completed successfully" \
    "FT-SUB_*.out"

check_stage "Fulltext Submission (Metagenomics)" \
    "${OUTPUT_DIR}/fulltext/logs/submission_logs" \
    "SUBMISSION_SCRIPT completed successfully" \
    "MTFT-SUB_*.out"

echo "---------------------------------------------------------------------"
echo -e "${COLOR_BLUE}Done.${COLOR_NONE}"
echo "For detailed error information, check the .err files in the respective log directories."

exit 0
