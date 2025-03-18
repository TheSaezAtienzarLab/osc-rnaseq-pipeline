from snakemake.utils import min_version
import os
import json
import re

# Ensure minimum Snakemake version for compatibility
min_version("6.0")

# Import centralized utility functions
from workflow.common.utils import get_samples_from_metasheet, create_workflow_dirs

# Create essential directories
create_workflow_dirs()

# Load configuration file (using relative path for portability)
configfile: "resources/config/params.yaml"

# Check if we're in test mode
TEST_MODE = config.get("test_mode", False)
if TEST_MODE:
    print("RUNNING IN TEST MODE WITH REDUCED DATASET")

# Get samples information
SAMPLES = get_samples_from_metasheet(config, test_mode=TEST_MODE)

# Update genome paths for BRB-seq
config["genome_fasta"] = "/users/PAS2598/duarte63/rna_seq_resources/genome/Homo_sapiens.GRCh38.dna.primary_assembly.fa"
config["gtf_file"] = "/users/PAS2598/duarte63/rna_seq_resources/genome/Homo_sapiens.GRCh38.90.gtf"
config["star_index"] = "/users/PAS2598/duarte63/rna_seq_resources/genome/star_index"

# Include rules from other Snakefiles
# This brings in all the rules defined in the other files
include: "workflow/qc_params.snakefile"      # QC and parameter generation rules
include: "workflow/star_alignment.snakefile" # Alignment rules
include: "workflow/feature_counts.snakefile" # Feature counts rules

# Define the workflow order
# Updated for BRB-seq: skip trimming step and handle single-end reads
ruleorder: fastqc > multiqc > star_align_brbseq > index_bam > alignment_metrics > multiqc_alignment > feature_counts > merge_counts > multiqc_counts

# Define the complete workflow with all expected outputs
rule all:
    input:
        # QC stage outputs (only R1 for BRB-seq)
        expand("Analysis/QC/FastQC/{sample}/{sample}_R1_fastqc.html",
               sample=SAMPLES.keys()),
        "Analysis/QC/MultiQC/multiqc_report.html",
        # QC completion marker
        "Analysis/QC/.qc_complete",
        # Alignment stage outputs (directly from raw reads)
        expand("Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam",
               sample=SAMPLES.keys()),
        expand("Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam.bai",
               sample=SAMPLES.keys()),
        "Analysis/Alignment/MultiQC/multiqc_report.html",
        # Alignment completion marker
        "Analysis/Alignment/.main_alignment_complete",
        # Feature counts stage outputs
        expand("Analysis/Counts/FeatureCounts/{sample}/{sample}.counts.txt",
               sample=SAMPLES.keys()),
        "Analysis/Counts/FeatureCounts/merged_gene_counts.txt",
        "Analysis/Counts/FeatureCounts/merged_gene_counts.normalized.txt",
        "Analysis/Counts/MultiQC/multiqc_report.html",
        # Counts completion marker
        "Analysis/Counts/.counts_complete",
        # Final workflow completion marker
        "Analysis/.workflow_complete"

# This rule ensures QC is completed before alignment starts
# It acts as a checkpoint between workflow stages
rule qc_complete:
    input:
        fastqc=expand("Analysis/QC/FastQC/{sample}/{sample}_R1_fastqc.html",
               sample=SAMPLES.keys()),
        multiqc="Analysis/QC/MultiQC/multiqc_report.html"
    output:
        touch("Analysis/QC/.qc_complete")
    log:
        "logs/workflow/qc_complete.log"
    shell:
        """
        echo "QC completed successfully at $(date)" > {log}
        """

# This rule ensures alignment is completed
rule main_alignment_complete:
    input:
        bams=expand("Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam",
               sample=SAMPLES.keys()),
        bai=expand("Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam.bai",
               sample=SAMPLES.keys()),
        multiqc="Analysis/Alignment/MultiQC/multiqc_report.html"
    output:
        touch("Analysis/Alignment/.main_alignment_complete")
    log:
        "logs/workflow/main_alignment_complete.log"
    shell:
        """
        echo "Alignment completed successfully at $(date)" > {log}
        
        # Also create the standard alignment complete marker for compatibility
        touch Analysis/Alignment/.alignment_complete
        """

# Define workflow stages for better control over execution order
rule workflow_stages:
    input:
        qc="Analysis/QC/.qc_complete",
        alignment="Analysis/Alignment/.main_alignment_complete",
        counts="Analysis/Counts/.counts_complete"
    output:
        touch("Analysis/.workflow_complete")
    shell:
        """
        echo "Workflow completed successfully at $(date)"
        """

# Provide helpful messages on workflow completion or failure
onsuccess:
    print("\nWorkflow completed successfully!")
    print("================================")
    print("Quality control reports: Analysis/QC/MultiQC/multiqc_report.html")
    print("Alignment BAMs: Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam")
    print("Alignment counts: Analysis/Alignment/STAR/{sample}/{sample}.ReadsPerGene.out.tab")
    print("Alignment MultiQC: Analysis/Alignment/MultiQC/multiqc_report.html")
    print("Feature counts: Analysis/Counts/FeatureCounts/{sample}/{sample}.counts.txt")
    print("Merged count matrix: Analysis/Counts/FeatureCounts/merged_gene_counts.txt")
    print("Normalized count matrix: Analysis/Counts/FeatureCounts/merged_gene_counts.normalized.txt")
    print("Counts MultiQC: Analysis/Counts/MultiQC/multiqc_report.html")
    print("\nTo visualize the workflow graph:")
    print("  snakemake --dag | dot -Tsvg > workflow.svg")

onerror:
    print("\nWorkflow failed!")
    print("===============")
    print("Check log files in the logs/ directory for error details.")
    print("Run with --notemp flag to keep temporary files for debugging.")
    print("Use -n (dry run) and -p (print shell commands) for troubleshooting.")