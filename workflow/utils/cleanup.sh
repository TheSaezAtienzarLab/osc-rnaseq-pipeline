#!/bin/bash
# Cleanup script to remove all previous output files and directories

echo "Cleaning up previous output files..."

# Remove QC outputs
echo "Removing QC outputs..."
rm -rf Analysis/QC/FastQC/*
rm -rf Analysis/QC/MultiQC/*
rm -rf Analysis/QC/Trimming/*
rm -f Analysis/QC/.qc_complete

# Remove trimmed outputs
echo "Removing trimmed outputs..."
rm -rf Analysis/Trimmed/*
rm -f Analysis/Trimmed/.trimming_complete

# Remove alignment outputs
echo "Removing alignment outputs..."
rm -rf Analysis/Alignment/*
rm -rf Analysis/Alignment/STAR/*
rm -rf Analysis/Alignment/MultiQC/*
rm -f Analysis/.alignment_complete

# Remove count outputs
echo "Removing count outputs..."
rm -rf Analysis/Counts/*
rm -f Analysis/.counts_complete

# Remove log files
echo "Removing log files..."
rm -rf logs/fastqc/*
rm -rf logs/multiqc/*
rm -rf logs/trimming/*
rm -rf logs/alignment/*
rm -rf logs/star/*
rm -rf logs/slurm/*
rm -rf logs/counts/*
rm -rf logs/workflow/*

# Remove Snakemake-specific files
echo "Removing Snakemake-specific files..."
rm -rf .snakemake/*
rm -rf workflow/.snakemake/*

# Remove any temporary files
echo "Removing temporary files..."
rm -f params_temp.json
rm -f workflow_dag.svg
rm -f Analysis/.workflow_complete

echo "Cleanup complete. You can now run the workflow again."