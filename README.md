# RNA-seq Analysis Pipeline

## Overview

This repository contains a comprehensive RNA-seq analysis pipeline implemented using Snakemake. The pipeline processes raw sequencing data through quality control, trimming, alignment, and quantification stages to produce gene expression counts ready for downstream analysis.

## Pipeline Stages

The pipeline consists of five main stages:

1. **Quality Control (QC)**: Assesses the quality of raw sequencing data and determines optimal trimming parameters
2. **Trimming**: Removes adapters and low-quality bases from raw reads
3. **Alignment**: Maps trimmed reads to a reference genome
4. **Feature Counts**: Quantifies gene expression by counting reads mapped to genomic features
5. **Workflow Completion**: Ensures all stages are completed successfully

## Quick Start

```bash
# Clone the repository
git clone https://github.com/TheSaezAtienzarLab/osc-rnaseq-pipeline.git
cd satienzar-brnaseq

# Configure samples in resources/config/metasheet.csv
# Configure parameters in resources/config/params.yaml

# Run the pipeline
snakemake --cores <N> --use-conda
```

## Documentation

For detailed information about the pipeline, see the following documentation:

- [Pipeline Overview](docs/README_PIPELINE.md)
- [Quality Control Documentation](docs/README_QC.md)
- [Trimming Documentation](docs/README_TRIMMING.md)
- [Alignment Documentation](docs/README_ALIGNMENT.md)
- [Feature Counts Documentation](docs/README_COUNTS.md)

## Requirements

- Snakemake (≥ 6.0)
- FastQC
- MultiQC
- fastp
- STAR
- Samtools
- Subread (for featureCounts)
- Python (≥ 3.6)

## Key Features

### Quality Control
- FastQC analysis of raw reads
- MultiQC reporting for easy comparison
- Automatic determination of optimal trimming parameters

### Trimming
- Adapter and quality trimming with fastp
- Sample-specific trimming parameters
- MultiQC reporting of trimming results

### Alignment
- STAR alignment with optimized parameters
- BAM indexing and metrics collection
- MultiQC reporting of alignment statistics

### Feature Counts
- Gene expression quantification with featureCounts
- Flexible counting options (exon/gene/transcript level)
- Merged count matrix generation
- CPM normalization
- MultiQC reporting of counting statistics

## Directory Structure

```
project_root/
├── Analysis/                  # Main output directory
│   ├── QC/                    # Quality control outputs
│   │   ├── FastQC/           # FastQC reports
│   │   ├── MultiQC/          # MultiQC reports for raw data
│   │   └── Trimming/         # Trimming parameters and reports
│   ├── Trimmed/              # Trimmed FASTQ files
│   ├── Alignment/            # Alignment outputs
│   │   ├── STAR/             # STAR alignment files
│   │   └── MultiQC/          # MultiQC reports for alignment
│   └── Counts/               # Feature counts outputs
│       ├── FeatureCounts/    # Count files and matrices
│       └── MultiQC/          # MultiQC reports for counts
├── logs/                      # Log files for all steps
│   ├── fastqc/               # FastQC logs
│   ├── trimming/             # Trimming logs
│   ├── star/                 # Alignment logs
│   ├── counts/               # Feature counts logs
│   └── workflow/             # Workflow stage logs
├── resources/                 # Input resources
│   ├── config/               # Configuration files
│   │   ├── params.yaml       # Pipeline parameters
│   │   ├── metasheet.csv     # Sample metadata
│   │   └── cluster.yaml      # Cluster configuration
│   ├── genome/               # Reference genome files
│   ├── metadata/             # Generated metadata files
│   ├── adaptors/             # Adaptor sequences
│   └── primers/              # Primer sequences
├── workflow/                  # Workflow components
│   ├── scripts/              # Helper scripts
│   ├── common/               # Shared utility functions
│   ├── utils/                # Additional utility scripts
│   ├── qc_params.snakefile   # QC and parameter generation rules
│   ├── fastp_trimming.snakefile # Trimming rules
│   ├── star_alignment.snakefile # Alignment rules
│   └── feature_counts.snakefile # Feature counts rules
└── Snakefile                  # Main workflow file
```

## Configuration

<<<<<<< HEAD
- Snakemake (v6.0+)
- FastQC
- MultiQC
- fastp
- STAR
- samtools
- subread (2.0.8)
=======
### Sample Configuration

Samples are defined in `resources/config/metasheet.csv`:

```csv
sample,R1,R2
sample1,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz
sample2,/path/to/sample2_R1.fastq.gz,/path/to/sample2_R2.fastq.gz
```

### Pipeline Parameters

Key parameters in `resources/config/params.yaml`:

```yaml
# Resource parameters
fastqc_threads: 2
trimming_threads: 4
star_threads: 8
featurecounts_threads: 4

# Reference files
genome_fasta: "resources/genome/Homo_sapiens.GRCh38.dna.primary_assembly.fa"
gtf_file: "resources/genome/Homo_sapiens.GRCh38.90.gtf"

# Feature counts parameters
feature_type: "exon"          # Feature type to count
attribute: "gene_id"          # Attribute for grouping features
strand_specificity: "0"       # Strand specificity (0=unstranded)
```
>>>>>>> c45f6d176d965773ff0dd163e104abb52db23b51

## Setup

1. Clone this repository:
   ```
   git clone https://github.com/TheSaezAtienzarLab/osc-rnaseq-pipeline.git
   ```

2. Create the necessary directories (if they don't exist):
   ```
   mkdir -p resources/config resources/genome resources/metadata
   ```

3. Prepare your sample metadata file (`resources/config/metasheet.csv`):
   ```
   sample,R1,R2
   sample1,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz
   sample2,/path/to/sample2_R1.fastq.gz,/path/to/sample2_R2.fastq.gz
   ```

4. Configure the workflow parameters in `resources/config/params.yaml`:
   - Adjust memory, threads, and time requirements
   - Set paths to reference genome and annotation files
   - Customize tool-specific parameters

5. Prepare your reference genome:
   - Place your reference genome FASTA in `resources/genome/`
   - Place your GTF annotation file in `resources/genome/`
   - Create a STAR index or use the provided rule:
     ```
     snakemake --cores 16 create_star_index
     ```

## Usage

### Running the Complete Workflow

To run the entire workflow:

```
snakemake --cores <N> --use-conda
```

Replace `<N>` with the number of cores to use.

### Running Specific Stages

The workflow supports running individual stages:

```
# Run just the QC stage
snakemake --cores <N> qc_all

# Run just the trimming stage
snakemake --cores <N> trim_all

# Run just the alignment stage
snakemake --cores <N> align_all

# Run just the feature counts stage
snakemake --cores <N> count_all
```

### Cluster Execution

For HPC environments, you can use the provided cluster configuration:

```
snakemake --profile slurm --cluster-config resources/config/cluster.yaml
```

Or with explicit cluster parameters:

```
snakemake --cluster "sbatch --mem={resources.mem_mb} --time={params.time} --cpus-per-task={threads}" --jobs 100
```

## Output Files

### Quality Control
- `Analysis/QC/FastQC/{sample}/{sample}_R[1,2]_fastqc.html`: FastQC reports
- `Analysis/QC/MultiQC/multiqc_report.html`: MultiQC summary of FastQC results
- `Analysis/QC/Trimming/trimming_params.json`: Sample-specific trimming parameters

### Trimming
- `Analysis/Trimmed/{sample}/{sample}_R[1,2]_trimmed.fastq.gz`: Trimmed FASTQ files
- `Analysis/QC/Trimming/Reports/{sample}_fastp.html`: fastp reports
- `Analysis/QC/Trimming/MultiQC/multiqc_report.html`: MultiQC summary of trimming
- `resources/metadata/trimmed_samples.csv`: Metadata file with trimmed FASTQ paths

### Alignment
- `Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam`: Aligned BAM files
- `Analysis/Alignment/STAR/{sample}/{sample}.Aligned.toTranscriptome.out.bam`: Transcriptome-aligned BAM
- `Analysis/Alignment/STAR/{sample}/{sample}.ReadsPerGene.out.tab`: Gene counts
- `Analysis/Alignment/STAR/{sample}/{sample}.SJ.out.tab`: Splice junctions
- `Analysis/Alignment/STAR/{sample}/{sample}.flagstat.txt`: Alignment statistics
- `Analysis/Alignment/MultiQC/multiqc_report.html`: MultiQC summary of alignment

### Feature Counts
- `Analysis/Counts/FeatureCounts/{sample}/{sample}.counts.txt`: Count file for each sample
- `Analysis/Counts/FeatureCounts/merged_gene_counts.txt`: Merged count matrix
- `Analysis/Counts/FeatureCounts/merged_gene_counts.normalized.txt`: Normalized count matrix
- `Analysis/Counts/MultiQC/multiqc_report.html`: MultiQC summary of counts

## Workflow Checkpoints

The pipeline includes checkpoint markers to ensure each stage completes successfully:

- `Analysis/QC/.qc_complete`: QC stage completed
- `Analysis/Trimmed/.trimming_complete`: Trimming stage completed
- `Analysis/Alignment/.main_alignment_complete`: Alignment stage completed
- `Analysis/Counts/.counts_complete`: Feature counts stage completed
- `Analysis/.workflow_complete`: Entire workflow completed

## Troubleshooting

### Common Issues

1. **Missing Input Files**
   - Check paths in metasheet.csv
   - Verify file permissions

2. **Resource Limitations**
   - Increase memory or threads in params.yaml
   - Use cluster execution for large datasets

3. **Software Compatibility**
   - Ensure all tools are installed and in PATH
   - Check version compatibility

### Log Files

Log files are stored in the `logs/` directory, organized by pipeline stage:

- `logs/fastqc/`: FastQC logs
- `logs/trimming/`: Trimming logs
- `logs/star/`: Alignment logs
- `logs/counts/`: Feature counts logs
- `logs/workflow/`: Workflow checkpoint logs

## Advanced Usage

### Test Mode

The pipeline supports a test mode for quick validation:

```bash
snakemake --config test_mode=True --cores <N>
```

### Custom Parameters

You can override parameters at runtime:

```bash
snakemake --config star_threads=16 star_memory=64000 --cores <N>
```

### Resuming Failed Runs

To resume a failed run:

```bash
snakemake --cores <N> --rerun-incomplete
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Citation

If you use this pipeline in your research, please cite:

```
Duarte Gabriel,Saez-Atienzar Sara. (2025). RNA-seq Analysis Pipeline. GitHub repository, https://github.com/TheSaezAtienzarLab/osc-rnaseq-pipeline
```

## Contact

For questions or issues, please open an issue on GitHub or contact [gabriel.duarte@osumc.edu].
