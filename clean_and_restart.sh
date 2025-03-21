#!/bin/bash

# Script to clean up previous analysis results and restart the workflow
# This ensures a clean execution after fixing syntax issues

echo "=== Cleaning up previous analysis results ==="

# Check for and kill any running STAR processes
echo "Checking for running STAR processes..."
pkill -f STAR || true

# Remove analysis directories with force option
echo "Removing Analysis directory..."
find Analysis/ -type d -name "*_STARtmp" -exec chmod -R u+w {} \; 2>/dev/null || true
find Analysis/ -type d -name "*_STARgenome" -exec chmod -R u+w {} \; 2>/dev/null || true
rm -rf Analysis/ || echo "Warning: Some files could not be removed. This is usually not a problem."

# Remove logs
echo "Removing logs..."
rm -rf logs/

# Remove any temporary Snakemake files
echo "Removing Snakemake temporary files..."
rm -rf .snakemake/

# Remove any marker files
echo "Removing marker files..."
rm -f *.complete

# Create essential directories
echo "Creating essential directories..."
mkdir -p logs/slurm
mkdir -p logs/workflow
mkdir -p logs/fastqc
mkdir -p logs/multiqc
mkdir -p logs/trimming
mkdir -p logs/star

echo "=== Clean-up complete ==="
echo "You can now submit the job with: sbatch submit_snakemake.sh" 