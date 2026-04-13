#!/bin/bash

###############################################################################
# BACKLOG PIPELINE SCRIPT
# Usage: ./backlog_main_ml_pipeline-v01.sh --start_date 'YYYY-MM-DD' --end_date 'YYYY-MM-DD'
###############################################################################

# Function to check if a date is valid
function is_valid_date() {
    date -d "$1" >/dev/null 2>&1
}

# Parsing arguments for start_date and end_date
START_DATE=""
END_DATE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --start_date)
            START_DATE="$2"
            shift 2
            ;;
        --end_date)
            END_DATE="$2"
            shift 2
            ;;
        *)
            echo "Error: Invalid argument '$1'. Use --start_date and --end_date."
            exit 1
            ;;
    esac
done

# Validate that start_date and end_date are provided
if [ -z "$START_DATE" ] || [ -z "$END_DATE" ]; then
    echo "Error: Both --start_date and --end_date must be provided."
    exit 1
fi

# Validate that the dates are valid
if ! is_valid_date "$START_DATE" || ! is_valid_date "$END_DATE"; then
    echo "Error: Invalid date format. Please use 'YYYY-MM-DD'."
    exit 1
fi

# Convert dates to timestamps for comparison
START_TIMESTAMP=$(date -d "$START_DATE" +"%s")
END_TIMESTAMP=$(date -d "$END_DATE" +"%s")

# Validate that start_date is before end_date
if [ "$START_TIMESTAMP" -gt "$END_TIMESTAMP" ]; then
    echo "Error: start_date must be earlier than end_date."
    exit 1
fi

# Loop through the dates from start_date to end_date
CURRENT_DATE="$START_DATE"
while [ "$CURRENT_DATE" != "$END_DATE" ]; do
    echo "*******************************************"
    echo "Running main pipeline for date: $CURRENT_DATE"
    
    # Call the main pipeline script with the current date
    sh abstract-ml-pipeline-v05.sh "$CURRENT_DATE"
    
    # Increment the current date by one day
    CURRENT_DATE=$(date -d "$CURRENT_DATE + 1 day" +"%Y-%m-%d")
done

# Finally, run the pipeline for the end date
echo "*********************************************"
echo "Running main pipeline for date: $END_DATE"
sh abstract-ml-pipeline-v05.sh "$END_DATE"
echo "*********************************************"
echo "Pipeline completed for all dates between $START_DATE and $END_DATE."

