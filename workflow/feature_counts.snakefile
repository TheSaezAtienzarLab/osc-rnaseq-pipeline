from snakemake.utils import min_version
min_version("6.0")

# Define SAMPLES as an empty dict if not already defined (for syntax checking)
if 'SAMPLES' not in globals():
    SAMPLES = {}
    config = {}

# No configfile import - config is loaded in main Snakefile

# Rule to run feature counts for all samples
rule count_all:
    input:
        # Individual count files
        expand("Analysis/Counts/FeatureCounts/{sample}/{sample}.counts.txt", 
               sample=SAMPLES.keys()),
        # Merged count matrix
        "Analysis/Counts/FeatureCounts/merged_gene_counts.txt",
        # MultiQC report
        "Analysis/Counts/MultiQC/multiqc_report.html",
        # Completion marker
        "Analysis/Counts/.counts_complete"

# Rule to run featureCounts on each BAM file
rule feature_counts:
    input:
        bam="Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam",
        bai="Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam.bai",
        alignment_complete="Analysis/Alignment/.main_alignment_complete"
    output:
        counts="Analysis/Counts/FeatureCounts/{sample}/{sample}.counts.txt",
        summary="Analysis/Counts/FeatureCounts/{sample}/{sample}.counts.txt.summary"
    log:
        "logs/counts/{sample}.featurecounts.log"
    params:
        gtf=config.get("gtf_file", "/users/PAS2598/duarte63/rna_seq_resources/genome/Homo_sapiens.GRCh38.90.gtf"),
        # Feature type to count (default: exon)
        feature_type=config.get("feature_type", "exon"),
        # Attribute to use for grouping features (default: gene_id)
        attribute=config.get("attribute", "gene_id"),
        # Strand specificity: 0 (unstranded), 1 (stranded), 2 (reversely stranded)
        # For BRB-seq, we typically use stranded=1 (forward stranded)
        strand=config.get("strand_specificity", "1"),
        # Additional parameters
        extra_params=config.get("featurecounts_extra", "-p -B -C --fracOverlap 0.2")
    threads: config.get("featurecounts_threads", 4)
    resources:
        mem_mb=config.get("featurecounts_memory", 8000)
    shell:
        """
        # Create output directory
        mkdir -p $(dirname {output.counts})
        
        # Run featureCounts
        echo "Running featureCounts on {wildcards.sample}..." > {log} 2>&1
        
        featureCounts \\
            -a {params.gtf} \\
            -o {output.counts} \\
            -t {params.feature_type} \\
            -g {params.attribute} \\
            -s {params.strand} \\
            -T {threads} \\
            {params.extra_params} \\
            {input.bam} \\
            >> {log} 2>&1
            
        # Check if output was created successfully
        if [ ! -f "{output.counts}" ]; then
            echo "ERROR: featureCounts failed to create output file" >> {log}
            exit 1
        fi
        
        # Print summary statistics
        echo "Summary statistics:" >> {log}
        cat {output.summary} >> {log}
        """

# Rule to merge individual count files into a single matrix
rule merge_counts:
    input:
        counts=expand("Analysis/Counts/FeatureCounts/{sample}/{sample}.counts.txt", 
                     sample=SAMPLES.keys())
    output:
        merged="Analysis/Counts/FeatureCounts/merged_gene_counts.txt",
        normalized="Analysis/Counts/FeatureCounts/merged_gene_counts.normalized.txt"
    log:
        "logs/counts/merge_counts.log"
    resources:
        mem_mb=config.get("merge_counts_memory", 8000)
    script:
        "scripts/merge_counts.py"

# Rule to run MultiQC on feature counts results
rule multiqc_counts:
    input:
        summaries=expand("Analysis/Counts/FeatureCounts/{sample}/{sample}.counts.txt.summary", 
                        sample=SAMPLES.keys())
    output:
        html="Analysis/Counts/MultiQC/multiqc_report.html",
        data_dir=directory("Analysis/Counts/MultiQC/multiqc_data")
    log:
        "logs/counts/multiqc.log"
    params:
        outdir="Analysis/Counts/MultiQC"
    resources:
        mem_mb=config.get("multiqc_counts_memory", 4000)
    shell:
        """
        # Create output directory
        mkdir -p {params.outdir}
        
        # Run MultiQC
        echo "Running MultiQC on feature counts results..." > {log} 2>&1
        
        multiqc --force \\
            --outdir {params.outdir} \\
            Analysis/Counts/FeatureCounts/ \\
            >> {log} 2>&1
            
        # Verify output
        if [ ! -f "{output.html}" ]; then
            echo "ERROR: MultiQC report was not created" >> {log}
            exit 1
        fi
        
        # Create data directory if it doesn't exist
        if [ ! -d "{output.data_dir}" ]; then
            mkdir -p {output.data_dir}
            touch {output.data_dir}/.placeholder
        fi
        
        echo "MultiQC completed successfully" >> {log}
        """

# Rule to mark completion of counting stage
rule counts_complete:
    input:
        counts=expand("Analysis/Counts/FeatureCounts/{sample}/{sample}.counts.txt", 
                     sample=SAMPLES.keys()),
        merged="Analysis/Counts/FeatureCounts/merged_gene_counts.txt",
        normalized="Analysis/Counts/FeatureCounts/merged_gene_counts.normalized.txt",
        multiqc="Analysis/Counts/MultiQC/multiqc_report.html"
    output:
        touch("Analysis/Counts/.counts_complete")
    log:
        "logs/workflow/counts_complete.log"
    shell:
        """
        echo "Feature counts completed successfully at $(date)" > {log}
        echo "Generated count files for $(echo {input.counts} | wc -w) samples" >> {log}
        echo "Merged count matrix: {input.merged}" >> {log}
        echo "Normalized count matrix: {input.normalized}" >> {log}
        """ 