#!/bin/bash

###############################################################################
# SLURM JOB COUNT SUMMARY
#
# This script provides a summary of your Slurm jobs, grouped by job name,
# showing the count of running and pending instances for each.
#
###############################################################################

# Get the current user's username
CURRENT_USER=$(whoami)

echo "Fetching job summary for user: $CURRENT_USER"
echo "--------------------------------------------------"

# Use squeue to get job data and pipe it to awk for processing
squeue -u "$CURRENT_USER" -o "%.30j %.2t" | awk '
BEGIN {
    # Print a formatted header
    printf "%-30s | %-10s | %-10s\n", "JOB NAME", "RUNNING", "PENDING"
    print "-------------------------------------------------------"
}
# Skip the header line from squeue output
NR > 1 {
    job_name = $1
    state = $2

    # Increment counters based on job state
    if (state == "R") {
        running[job_name]++
    } else if (state == "PD") {
        pending[job_name]++
    }
    # Keep track of all unique job names encountered
    all_jobs[job_name] = 1
}
END {
    # Iterate through all unique job names and print the summary
    for (job in all_jobs) {
        # Use 0 if a count is not set
        r_count = running[job] ? running[job] : 0
        p_count = pending[job] ? pending[job] : 0
        printf "%-30s | %-10d | %-10d\n", job, r_count, p_count
    }
}'

echo "-------------------------------------------------------"
echo "Done."
