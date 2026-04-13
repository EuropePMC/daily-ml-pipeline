#!/bin/bash

###############################################################################
# SUBMISSION-ONLY PIPELINE (based on main-ml-pipeline-v08.sh)
# Usage: ./main-ml-pipeline-v08-submission-only.sh <file_date> <folder_date>
# Changes:
# - Skip all annotation/section tagging jobs
# - Submit only the submission jobs (abstract/fulltext/metagenomics)
# - Increased --time for submission jobs (from 1:00:00 to 04:00:00)
# - Keep your mail-user settings
###############################################################################

# Exit on error, unset vars, and pipe failures
set -euo pipefail

###############################################################################
# Environment configuration (unchanged)
###############################################################################
export OMP_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
export MKL_NUM_THREADS=1
export NUMEXPR_NUM_THREADS=1

# Activate Python virtual environment
source /hps/software/users/literature/textmining-ml/envs/ml_tm_pipeline_env/bin/activate

ENV_FILE="/hps/software/users/literature/textmining-ml/.env_paths"
if [ -f "$ENV_FILE" ]; then
    if ! source "$ENV_FILE"; then
        echo "Error: Failed to load environment file from $ENV_FILE." >&2
        exit 1
    fi
else
    echo "Error: Environment file not found at $ENV_FILE." >&2
    exit 1
fi

###############################################################################
# Check required env-vars (kept as-is for compatibility)
###############################################################################
echo "Checking BASE_DIR, OUTPUT_BASE_DIR, LIB_PATH, and MODEL_PATH_QUANTIZED"
if [ -z "${BASE_DIR:-}" ] || [ -z "${OUTPUT_BASE_DIR:-}" ] || [ -z "${LIB_PATH:-}" ] || [ -z "${MODEL_PATH_QUANTIZED:-}" ]; then
    echo "Error: One or more required environment variables are not set. Check BASE_DIR, OUTPUT_BASE_DIR, LIB_PATH, MODEL_PATH_QUANTIZED." >&2
    exit 1
fi

###############################################################################
# Concurrency settings (not used here but kept for minimal diff)
###############################################################################
MAX_ARRAY_CONCURRENT=150

###############################################################################
# Date and directory setup (unchanged)
###############################################################################
FILE_DATE="$1"
TODAY="$2"

if [ -z "$FILE_DATE" ] || [ -z "$TODAY" ]; then
    echo "Error: Usage: $0 <file_date> <folder_date>"
    exit 1
fi

YESTERDAY_OUTPUT="$FILE_DATE"
TODAY_OUTPUT="$TODAY"
TIMESTAMP="$YESTERDAY_OUTPUT"

###############################################################################
# Base directories (unchanged)
###############################################################################
ABSTRACT_SOURCE_DIR="${BASE_DIR}/${TODAY}/abstract/source"
FULLTEXT_SOURCE_DIR="${BASE_DIR}/${TODAY}/fulltext/source"
TODAY_OUTPUT_DIR="${OUTPUT_BASE_DIR}/${TODAY_OUTPUT}"

###############################################################################
# Worker scripts (unchanged)
###############################################################################
SECTION_TAGGER_PATH="${LIB_PATH}/fulltext_section_tagger_worker.sh"
FULLTEXT_TAGGER_PATH="${LIB_PATH}/fulltext_annotation_tagger_worker.sh"
ABSTRACT_TAGGER_PATH="${LIB_PATH}/abstract_annotation_tagger_worker.sh"
METAGENOMICS_FULLTEXT_TAGGER_PATH="${LIB_PATH}/metagenomics_fulltext_annotation_tagger_worker.sh"
SUBMISSION_SCRIPT="${LIB_PATH}/submission_worker.sh"

# Submission-only execution
###############################################################################
# We skip all tagger/annotation jobs. We directly submit the three submission jobs
# if their corresponding annotation output directories contain files.

# helper check: returns 0 if directory has at least one file
has_files () {
    compgen -G "$1/*" > /dev/null
}

# Step 2: Fulltext & Metagenomics SUBMISSION ONLY
if has_files "${TODAY_OUTPUT_DIR}/fulltext/annotations/europepmc"; then
    echo "Submitting Fulltext Submission job..."
    FT_SUB_JOB_ID=$(sbatch \
        --job-name="FT-SUBMISSION-${TIMESTAMP}" \
        --output="${TODAY_OUTPUT_DIR}/fulltext/logs/submission_logs/FT-SUB_%j.out" \
        --error="${TODAY_OUTPUT_DIR}/fulltext/logs/submission_logs/FT-SUB_%j.err" \
        --ntasks=1 \
        --cpus-per-task=3 \
        --partition=production \
        --mem=2G \
        --time=20:00:00 \
        --mail-user="lit-dev@ebi.ac.uk" \
        --mail-type=BEGIN,END,FAIL \
        "$SUBMISSION_SCRIPT" \
            "${TODAY_OUTPUT_DIR}/fulltext/annotations/europepmc" \
            "${TODAY_OUTPUT_DIR}/fulltext/submission/europepmc" \
            "fulltext-patch-${YESTERDAY_OUTPUT}-europepmc" \
            "$YESTERDAY_OUTPUT" \
            "europepmc" | awk '{print $4}')
    echo "Fulltext Submission job submitted with Job ID: $FT_SUB_JOB_ID"
else
    echo "No fulltext europepmc annotation outputs found. Skipping Fulltext Submission."
fi

echo "Fulltext submission-only pipeline done for $TODAY_OUTPUT."
