#!/bin/bash
set -e

cd /hps/software/users/literature/textmining-ml

echo "Pulling latest code..."
git pull origin main

echo "Submitting SLURM job..."
sbatch run_pipeline.slurm
