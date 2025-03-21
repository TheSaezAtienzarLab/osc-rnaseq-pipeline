#!/bin/bash
#SBATCH --account=PAS2598
#SBATCH --time=12:00:00
#SBATCH --nodes=10
#SBATCH --ntasks-per-node=8
#SBATCH --mem=64G
#SBATCH --job-name=prefetch
#SBATCH --output=prefetch_%j.log
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=mor558@osumc.edu

# Base directory
BASE_DIR="/fs/scratch/PAS2598/All_RNAseq_Samples"

# Load conda
module load miniconda3

# Activate your environment
source activate bulk_RNA_env

# Create main directory and lab directories
mkdir -p ${BASE_DIR}/{astrocytes,fetal_astrocytes,NPCs,cortical_neurons}_Samples

# Initialize metasheet
mkdir -p ${BASE_DIR}/resources/config
echo "sample,R1" > ${BASE_DIR}/resources/config/metasheet.csv

# Define samples by lab
declare -A lab_samples=(
    ["astrocytes"]="SRR15503422 SRR15503424 SRR15503426 SRR15503428 SRR15503430 SRR15503440 SRR15503432 SRR15503434 SRR15503442 SRR15503448 SRR15503450 SRR15503452"
    ["fetal_astrocytes "]="SRR7050888 SRR7050889"
    ["NPCs"]="SRR15503444 SRR15503445"
    ["cortical_neurons"]="SRR7050886 SRR7050887 SRR8400799 SRR8400800 SRR8400801 SRR8400802 SRR8400803 SRR8400804 SRR15503436 SRR15503437"
)

for lab in "${!lab_samples[@]}"; do
    echo "Processing ${lab} samples..."
    cd ${BASE_DIR}/${lab}_Samples
    
    # Process each sample for this lab
    for srr in ${lab_samples[$lab]}; do
        echo "Prefetching ${srr}..."
        prefetch ${srr}
        
        if [ $? -eq 0 ]; then
            echo "Running fasterq-dump for ${srr}..."
            fasterq-dump ${srr}
            
            if [ -f "${srr}.fastq" ]; then
                echo "Compressing file..."
                gzip ${srr}.fastq
                
                # Rename file to match desired format
                mv ${srr}.fastq.gz ${srr}_R1.fastq.gz
                
                # Add to metasheet
                echo "${lab}_${srr},${BASE_DIR}/${lab}_Samples/${srr}_R1.fastq.gz" >> ${BASE_DIR}/resources/config/metasheet.csv
                
                # Clean up SRA files
                rm -rf ~/ncbi/public/sra/${srr}.sra
                
                echo "Successfully processed ${srr}"
            else
                echo "Error: FastQ file not created for ${srr}"
            fi
        else
            echo "Error: Prefetch failed for ${srr}"
        fi
    done
done

# Generate download report
{
    echo "Download Report"
    echo "==============="
    echo "Date: $(date)"
    echo ""
    
    echo "Download Summary by Lab:"
    echo "----------------------"
    for lab in "${!lab_samples[@]}"; do
        echo "${lab} Samples:"
        if [ -d "${BASE_DIR}/${lab}_Samples" ]; then
            ls -lh ${BASE_DIR}/${lab}_Samples/*.fastq.gz 2>/dev/null || echo "No files downloaded"
            echo "Total size:"
            du -sh ${BASE_DIR}/${lab}_Samples 2>/dev/null || echo "Directory empty"
        fi
        echo ""
    done
    
    echo "Generated Metasheet Content:"
    echo "========================="
    cat ${BASE_DIR}/resources/config/metasheet.csv
    
    echo ""
    echo "Total Space Used:"
    du -sh ${BASE_DIR}
} > ${BASE_DIR}/download_report.txt

# Deactivate conda environment
conda deactivate

echo "
Download process completed! 
Check ${BASE_DIR}/download_report.txt for detailed information."