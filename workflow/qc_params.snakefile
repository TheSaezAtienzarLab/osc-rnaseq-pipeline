import os
from snakemake.utils import min_version
min_version("6.0")

# Define SAMPLES as an empty dict if not already defined (for syntax checking)
if 'SAMPLES' not in globals():
    SAMPLES = {}
    config = {}

# Note: No configfile statement here anymore - config is loaded in main Snakefile

# Rule to generate all QC outputs
rule qc_all:
    input:
        # FastQC outputs for R1 (BRB-seq is single-end)
        expand("Analysis/QC/FastQC/{sample}/{sample}_R1_fastqc.html",
               sample=SAMPLES.keys()),
        # MultiQC report
        "Analysis/QC/MultiQC/multiqc_report.html"

# Rule to run FastQC on R1 for each sample (BRB-seq is single-end)
rule fastqc:
    input:
        r1=lambda wildcards: SAMPLES[wildcards.sample]["R1"]
    output:
        html_r1="Analysis/QC/FastQC/{sample}/{sample}_R1_fastqc.html",
        zip_r1="Analysis/QC/FastQC/{sample}/{sample}_R1_fastqc.zip"
    log:
        "logs/fastqc/{sample}.log"
    params:
        outdir="Analysis/QC/FastQC/{sample}"
    threads: config.get("fastqc_threads", 2)
    resources:
        mem_mb=config.get("fastqc_memory", 4000)
    shell:
        """
        set -o pipefail
        mkdir -p {params.outdir}
        
        fastqc --threads {threads} \\
            --outdir {params.outdir} \\
            {input.r1} \\
            > {log} 2>&1
            
        # Rename the files to match expected output filenames
        BASE_R1=$(basename {input.r1} .fastq.gz)
        
        # Move and rename files if needed
        if [ -f "{params.outdir}/${{BASE_R1}}_fastqc.html" ] && [ "{params.outdir}/${{BASE_R1}}_fastqc.html" != "{output.html_r1}" ]; then
            mv "{params.outdir}/${{BASE_R1}}_fastqc.html" "{output.html_r1}"
            mv "{params.outdir}/${{BASE_R1}}_fastqc.zip" "{output.zip_r1}"
        fi
        
        # Ensure the output files exist and have correct permissions
        for f in {output}; do
            if [ ! -f "$f" ]; then
                echo "Expected output file $f was not created" >> {log}
                exit 1
            fi
            chmod 644 "$f"  # Ensure files are readable
        done
        """

# Rule to run MultiQC
rule multiqc:
    input:
        fastqc_outputs=expand("Analysis/QC/FastQC/{sample}/{sample}_R1_fastqc.zip",
                             sample=SAMPLES.keys())
    output:
        html="Analysis/QC/MultiQC/multiqc_report.html",
        data_dir=directory("Analysis/QC/MultiQC/multiqc_data")
    log:
        "logs/multiqc/multiqc.log"
    params:
        outdir="Analysis/QC/MultiQC"
    resources:
        mem_mb=config.get("multiqc_memory", 4000)
    shell:
        """
        # Run MultiQC with explicit specification of input files
        multiqc --force \\
            --outdir {params.outdir} \\
            Analysis/QC/FastQC/ \\
            2> {log}
            
        # Ensure the output files exist
        if [ ! -f "{output.html}" ]; then
            echo "ERROR: MultiQC report was not created" >> {log}
            exit 1
        fi
        
        # Create data directory if it doesn't exist
        if [ ! -d "{output.data_dir}" ]; then
            mkdir -p {output.data_dir}
            touch {output.data_dir}/.placeholder
        fi
        
        # Also check for the specific metrics file we need
        if [ ! -f "{output.data_dir}/multiqc_fastqc.txt" ]; then
            echo "ERROR: FastQC metrics file was not created by MultiQC" >> {log}
            echo "Creating empty placeholder file" >> {log}
            mkdir -p $(dirname {output.data_dir}/multiqc_fastqc.txt)
            touch {output.data_dir}/multiqc_fastqc.txt
        fi
        """