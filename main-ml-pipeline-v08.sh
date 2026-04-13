#!/bin/bash

###############################################################################
# MAIN PIPELINE SCRIPT
# Usage: ./main-ml-pipeline-v08.sh <file_date> <folder_date>
###############################################################################

# Exit on error, unset vars, and pipe failures
set -euo pipefail

###############################################################################
# Environment configuration
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
# Check required env-vars
###############################################################################
echo "Checking BASE_DIR, OUTPUT_BASE_DIR, LIB_PATH, and MODEL_PATH_QUANTIZED"
if [ -z "${BASE_DIR:-}" ] || [ -z "${OUTPUT_BASE_DIR:-}" ] || [ -z "${LIB_PATH:-}" ] || [ -z "${MODEL_PATH_QUANTIZED:-}" ]; then
    echo "Error: One or more required environment variables are not set. Check BASE_DIR, OUTPUT_BASE_DIR, LIB_PATH, MODEL_PATH_QUANTIZED." >&2
    exit 1
fi


###############################################################################
# Concurrency settings
###############################################################################
# Maximum number of tasks from each sbatch array that can run concurrently
MAX_ARRAY_CONCURRENT=150

###############################################################################
# Date and directory setup
###############################################################################

FILE_DATE="$1"
TODAY="$2"

if [ -z "$FILE_DATE" ] || [ -z "$TODAY" ]; then
    echo "Error: Usage: $0 <file_date> <folder_date>"
    exit 1
fi

# ── FILE_DATE → YESTERDAY_OUTPUT ─────────────────────────────────
YESTERDAY_OUTPUT="$FILE_DATE"

# ── TODAY (folder_date) → TODAY_OUTPUT ────────────────────────────
TODAY_OUTPUT="$TODAY"
TIMESTAMP="$YESTERDAY_OUTPUT"

###############################################################################
# Base directories
###############################################################################
ABSTRACT_SOURCE_DIR="${BASE_DIR}/${TODAY}/abstract/source"
FULLTEXT_SOURCE_DIR="${BASE_DIR}/${TODAY}/fulltext/source"
TODAY_OUTPUT_DIR="${OUTPUT_BASE_DIR}/${TODAY_OUTPUT}"

###############################################################################
# Worker scripts
###############################################################################
SECTION_TAGGER_PATH="${LIB_PATH}/fulltext_section_tagger_worker.sh"
FULLTEXT_TAGGER_PATH="${LIB_PATH}/fulltext_annotation_tagger_worker.sh"
ABSTRACT_TAGGER_PATH="${LIB_PATH}/abstract_annotation_tagger_worker.sh"
METAGENOMICS_FULLTEXT_TAGGER_PATH="${LIB_PATH}/metagenomics_fulltext_annotation_tagger_worker.sh"
SUBMISSION_SCRIPT="${LIB_PATH}/submission_worker.sh"

###############################################################################
# Log and directory creation
###############################################################################
LOG_DIRS=(
    "${TODAY_OUTPUT_DIR}/fulltext/sections"
    "${TODAY_OUTPUT_DIR}/fulltext/annotations/europepmc"
    "${TODAY_OUTPUT_DIR}/fulltext/annotations/metagenomics"
    "${TODAY_OUTPUT_DIR}/abstract/annotations/europepmc"
    "${TODAY_OUTPUT_DIR}/fulltext/logs/section_logs"
    "${TODAY_OUTPUT_DIR}/fulltext/logs/annotation_logs"
    "${TODAY_OUTPUT_DIR}/fulltext/logs/submission_logs"
    "${TODAY_OUTPUT_DIR}/abstract/logs/annotation_logs"
    "${TODAY_OUTPUT_DIR}/abstract/logs/submission_logs"
)

for dir in "${LOG_DIRS[@]}"; do
    mkdir -p "$dir" || {
        echo "Error: Failed to create directory $dir."
        exit 1
    }
done

###############################################################################
# Pipeline execution
###############################################################################

# Step 1: Abstract annotation pipeline
ABSTRACT_FILES=($(find "$ABSTRACT_SOURCE_DIR" -type f -name "*.abstract.gz"))
NUM_ABSTRACT_FILES=${#ABSTRACT_FILES[@]}

if [[ $NUM_ABSTRACT_FILES -gt 0 ]]; then
    echo "Found $NUM_ABSTRACT_FILES abstract files. Submitting Abstract Annotation job..."

    ABSTRACT_JOB_ID=$(sbatch \
        --array=0-$((NUM_ABSTRACT_FILES - 1))%${MAX_ARRAY_CONCURRENT} \
        --job-name="AB-AN-${TIMESTAMP}" \
        --output="${TODAY_OUTPUT_DIR}/abstract/logs/annotation_logs/AB-AN_%A_%a.out" \
        --error="${TODAY_OUTPUT_DIR}/abstract/logs/annotation_logs/AB-AN_%A_%a.err" \
        --ntasks=1 \
        --cpus-per-task=3 \
        --partition=production \
        --mem=8G \
        --time=10:00:00 \
        --mail-user="lit-dev@ebi.ac.uk" \
        --mail-type=BEGIN,END,FAIL,ARRAY_TASKS \
        "$ABSTRACT_TAGGER_PATH" \
            "$ABSTRACT_SOURCE_DIR" \
            "$TODAY_OUTPUT_DIR" \
            "$MODEL_PATH_QUANTIZED" | awk '{print $4}')

    if [ -z "$ABSTRACT_JOB_ID" ]; then
        echo "Error: Failed to submit Abstract Annotation job."
        exit 1
    fi
    echo "Abstract Annotation job submitted with Job ID: $ABSTRACT_JOB_ID"

    echo "Submitting Abstract Submission job with dependency on Job ID: $ABSTRACT_JOB_ID"

    AB_SUB_JOB_ID=$(sbatch \
        --dependency=afterok:"$ABSTRACT_JOB_ID" \
        --job-name="AB-SUBMISSION-${TIMESTAMP}" \
        --output="${TODAY_OUTPUT_DIR}/abstract/logs/submission_logs/AB-SUB_%j.out" \
        --error="${TODAY_OUTPUT_DIR}/abstract/logs/submission_logs/AB-SUB_%j.err" \
        --ntasks=1 \
        --cpus-per-task=1 \
        --partition=production \
        --mem=2G \
        --time=01:00:00 \
        --mail-user="lit-dev@ebi.ac.uk" \
        --mail-type=BEGIN,END,FAIL,ARRAY_TASKS \
        "$SUBMISSION_SCRIPT" \
            "${TODAY_OUTPUT_DIR}/abstract/annotations/europepmc" \
            "${TODAY_OUTPUT_DIR}/abstract/submission/europepmc" \
            "abstract-patch-${YESTERDAY_OUTPUT}-europepmc" \
            "$YESTERDAY_OUTPUT" \
            "europepmc" | awk '{print $4}')

    if [ -z "$AB_SUB_JOB_ID" ]; then
        echo "Error: Failed to submit Abstract Submission job."
        exit 1
    fi
    echo "Abstract Submission job submitted successfully with Job ID: $AB_SUB_JOB_ID"
else
    echo "No abstract files found. Skipping Abstract pipeline."
fi

# Step 2: Fulltext pipeline
FULLTEXT_FILES=($(find "$FULLTEXT_SOURCE_DIR" -type f -name "patch-*.xml.gz"))
NUM_FULLTEXT_FILES=${#FULLTEXT_FILES[@]}

if [[ $NUM_FULLTEXT_FILES -gt 0 ]]; then
    echo "Found $NUM_FULLTEXT_FILES fulltext files. Submitting Section Tagger job..."

    SECTION_JOB_ID=$(sbatch \
        --array=0-$((NUM_FULLTEXT_FILES - 1))%${MAX_ARRAY_CONCURRENT} \
        --job-name="FT-ST-${TIMESTAMP}" \
        --output="${TODAY_OUTPUT_DIR}/fulltext/logs/section_logs/FT-ST_%A_%a.out" \
        --error="${TODAY_OUTPUT_DIR}/fulltext/logs/section_logs/FT-ST_%A_%a.err" \
        --ntasks=1 \
        --cpus-per-task=3 \
        --partition=production \
        --mem=5G \
        --time=10:00:00 \
        --mail-user="lit-dev@ebi.ac.uk" \
        --mail-type=BEGIN,END,FAIL,ARRAY_TASKS \
        "$SECTION_TAGGER_PATH" \
            "$FULLTEXT_SOURCE_DIR" \
            "$TODAY_OUTPUT_DIR" \
            "$YESTERDAY_OUTPUT" | awk '{print $4}')

    if [ -z "$SECTION_JOB_ID" ]; then
        echo "Error: Failed to submit Section Tagger job."
        exit 1
    fi
    echo "Section Tagger job submitted with Job ID: $SECTION_JOB_ID"

    echo "Submitting Fulltext Annotation job with dependency on Job ID: $SECTION_JOB_ID"

    FULLTEXT_JOB_ID=$(sbatch \
        --dependency=afterok:"$SECTION_JOB_ID" \
        --array=0-$((NUM_FULLTEXT_FILES - 1))%${MAX_ARRAY_CONCURRENT} \
        --job-name="FT-AN-${TIMESTAMP}" \
        --output="${TODAY_OUTPUT_DIR}/fulltext/logs/annotation_logs/FT-AN_%A_%a.out" \
        --error="${TODAY_OUTPUT_DIR}/fulltext/logs/annotation_logs/FT-AN_%A_%a.err" \
        --ntasks=1 \
        --cpus-per-task=3 \
        --partition=production \
        --mem=8G \
        --time=10:00:00 \
        --mail-user="lit-dev@ebi.ac.uk" \
        --mail-type=BEGIN,END,FAIL,ARRAY_TASKS \
        "$FULLTEXT_TAGGER_PATH" \
            "$TODAY_OUTPUT_DIR" \
            "$MODEL_PATH_QUANTIZED" | awk '{print $4}')

    if [ -z "$FULLTEXT_JOB_ID" ]; then
        echo "Error: Failed to submit Fulltext Annotation job."
        exit 1
    fi
    echo "Fulltext Annotation job submitted with Job ID: $FULLTEXT_JOB_ID"

    echo "Submitting Metagenomics Annotation job with dependency on Job ID: $SECTION_JOB_ID"

    METAGENOMICS_JOB_ID=$(sbatch \
        --dependency=afterok:"$SECTION_JOB_ID" \
        --array=0-$((NUM_FULLTEXT_FILES - 1))%${MAX_ARRAY_CONCURRENT} \
        --job-name="MTFT-AN-${TIMESTAMP}" \
        --output="${TODAY_OUTPUT_DIR}/fulltext/logs/annotation_logs/MTFT-AN_%A_%a.out" \
        --error="${TODAY_OUTPUT_DIR}/fulltext/logs/annotation_logs/MTFT-AN_%A_%a.err" \
        --ntasks=1 \
        --cpus-per-task=3 \
        --partition=production \
        --mem=8G \
        --time=15:00:00 \
        --mail-user="stirunag@ebi.ac.uk" \
        --mail-type=BEGIN,END,FAIL,ARRAY_TASKS \
        "$METAGENOMICS_FULLTEXT_TAGGER_PATH" \
            "$TODAY_OUTPUT_DIR" | awk '{print $4}')

    if [ -z "$METAGENOMICS_JOB_ID" ]; then
        echo "Error: Failed to submit Metagenomics Annotation job."
        exit 1
    fi
    echo "Metagenomics Annotation job submitted with Job ID: $METAGENOMICS_JOB_ID"

    echo "Submitting Fulltext Submission job with dependency on Job ID: $FULLTEXT_JOB_ID"

    FT_SUB_JOB_ID=$(sbatch \
        --dependency=afterok:"$FULLTEXT_JOB_ID" \
        --job-name="FT-SUBMISSION-${TIMESTAMP}" \
        --output="${TODAY_OUTPUT_DIR}/fulltext/logs/submission_logs/FT-SUB_%j.out" \
        --error="${TODAY_OUTPUT_DIR}/fulltext/logs/submission_logs/FT-SUB_%j.err" \
        --ntasks=1 \
        --cpus-per-task=1 \
        --partition=production \
        --mem=2G \
        --time=15:00:00 \
        --mail-user="lit-dev@ebi.ac.uk" \
        --mail-type=BEGIN,END,FAIL,ARRAY_TASKS \
        "$SUBMISSION_SCRIPT" \
            "${TODAY_OUTPUT_DIR}/fulltext/annotations/europepmc" \
            "${TODAY_OUTPUT_DIR}/fulltext/submission/europepmc" \
            "fulltext-patch-${YESTERDAY_OUTPUT}-europepmc" \
            "$YESTERDAY_OUTPUT" \
            "europepmc" | awk '{print $4}')

    echo "Submitting Metagenomics Submission job with dependency on Job ID: $METAGENOMICS_JOB_ID"

    MTFT_SUB_JOB_ID=$(sbatch \
        --dependency=afterok:"$METAGENOMICS_JOB_ID" \
        --job-name="MTFT-SUBMISSION-${TIMESTAMP}" \
        --output="${TODAY_OUTPUT_DIR}/fulltext/logs/submission_logs/MTFT-SUB_%j.out" \
        --error="${TODAY_OUTPUT_DIR}/fulltext/logs/submission_logs/MTFT-SUB_%j.err" \
        --ntasks=1 \
        --cpus-per-task=1 \
        --partition=production \
        --mem=2G \
        --time=15:00:00 \
        --mail-user="stirunag@ebi.ac.uk" \
        --mail-type=BEGIN,END,FAIL,ARRAY_TASKS \
        "$SUBMISSION_SCRIPT" \
            "${TODAY_OUTPUT_DIR}/fulltext/annotations/metagenomics" \
            "${TODAY_OUTPUT_DIR}/fulltext/submission/metagenomics" \
            "fulltext-patch-${YESTERDAY_OUTPUT}-metagenomics" \
            "$YESTERDAY_OUTPUT" \
            "Metagenomics" | awk '{print $4}')
else
    echo "No fulltext files found. Skipping Fulltext and Metagenomics pipelines."
fi

echo "Pipeline successfully submitted for $TODAY_OUTPUT."
exit 0

