#!/bin/bash

###############################################################################
# INTERACTIVE SLURM JOB CANCELLER
#
# This script provides a summary of your Slurm jobs and interactively
# prompts for which job group to cancel.
#
###############################################################################

# Function to get and display the current job summary
get_and_display_jobs() {
    echo "-------------------------------------------------------"
    echo "Fetching job summary for user: $(whoami)"
    echo "-------------------------------------------------------"
    
    # Define the awk script as a variable to avoid shell quoting issues
    local AWK_SCRIPT='
    BEGIN {
        printf "%-30s | %-10s | %-10s\n", "JOB NAME", "RUNNING", "PENDING";
        print "-------------------------------------------------------";
    }
    NR > 1 {
        job_name = $1;
        state = $2;
        
        # Filter for daily pipeline jobs only using a single regex
        if (job_name ~ /^(AB-AN-|FT-ST-|FT-AN-|MTFT-AN-|AB-SUBMISSION-|FT-SUBMISSION-|MTFT-SUBMISSION-)/) {
            if (state == "R") {
                running[job_name]++;
            } else if (state == "PD") {
                pending[job_name]++;
            }
            all_jobs[job_name] = 1;
        }
    }
    END {
        job_count = 0;
        # Sort the job names for consistent output (gawk specific)
        PROCINFO["sorted_in"] = "@ind_str_asc";
        for (job in all_jobs) {
            r_count = running[job] ? running[job] : 0;
            p_count = pending[job] ? pending[job] : 0;
            printf "%-30s | %-10d | %-10d\n", job, r_count, p_count;
            job_count++;
        }
        if (job_count == 0) {
            print "No jobs found for the Daily ML Pipeline.";
        }
    }
    '
    # Use squeue to get job data and pipe it to awk for processing
    squeue -u "$(whoami)" -o "%.30j %.2t" | awk "$AWK_SCRIPT"
    echo "-------------------------------------------------------"
}

# Main loop for interaction
while true; do
    # Display the current jobs
    get_and_display_jobs

    # Prompt the user for action
    read -p "Do you want to cancel a group of jobs? (y/n): " choice
    echo "" # Newline for spacing

    # Check the user's choice
    if [[ "$choice" != "y" && "$choice" != "Y" ]]; then
        echo "Exiting."
        break
    fi

    # Ask for the job name to cancel
    read -p "Enter the full job name to cancel (e.g., 'FT-ST-total'): " job_name_to_cancel

    # Check if the input is empty
    if [ -z "$job_name_to_cancel" ]; then
        echo "No job name entered. Please try again."
        continue
    }

    # Final confirmation
    read -p "Are you sure you want to cancel all jobs named '$job_name_to_cancel'? (y/n): " confirm_choice

    if [[ "$confirm_choice" == "y" || "$confirm_choice" == "Y" ]]; then
        echo "Canceling jobs named '$job_name_to_cancel'..."
        scancel --name="$job_name_to_cancel"
        echo "Cancellation command sent."
        # Pause to allow Slurm to process the cancellation before re-displaying jobs
        sleep 2
    else
        echo "Cancellation aborted."
    fi
done

exit 0
