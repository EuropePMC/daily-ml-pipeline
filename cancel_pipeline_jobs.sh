#!/bin/bash

###############################################################################
# CANCEL PIPELINE JOBS
#
# This script cancels all running and pending jobs associated with the
# daily ML pipeline by targeting their specific job names. This prevents
# the cancellation of other, unrelated jobs.
#
###############################################################################

echo "Canceling all jobs related to the Daily ML Pipeline..."

scancel --name="AB-AN-*" \
        --name="FT-ST-*" \
        --name="FT-AN-*" \
        --name="MTFT-AN-*" \
        --name="AB-SUBMISSION-*" \
        --name="FT-SUBMISSION-*" \
        --name="MTFT-SUBMISSION-*"

echo "Cancellation request submitted."
echo "Use 'squeue -u \$USER' to confirm the jobs have been removed."

