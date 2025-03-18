from snakemake.utils import min_version
min_version("6.0")

# Define SAMPLES as an empty dict if not already defined (for syntax checking)
if 'SAMPLES' not in globals():
    SAMPLES = {}
    config = {}

# No configfile import - config is loaded in main Snakefile

# Rule to run alignment for all samples
rule align_all:
    input:
        expand("Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam.bai",
               sample=SAMPLES.keys()),
        "Analysis/Alignment/MultiQC/multiqc_report.html"

# Rule to create STAR index (run this once before the main workflow)
rule create_star_index:
    input:
        fasta=config.get("genome_fasta", "/users/PAS2598/duarte63/rna_seq_resources/genome/Homo_sapiens.GRCh38.dna.primary_assembly.fa"),
        gtf=config.get("gtf_file", "/users/PAS2598/duarte63/rna_seq_resources/genome/Homo_sapiens.GRCh38.90.gtf")
    output:
        directory(config.get("star_index", "/users/PAS2598/duarte63/rna_seq_resources/genome/star_index"))
    log:
        "logs/star/star_index.log"
    params:
        sjdb_overhang=config.get("sjdb_overhang", 100)  # Read length - 1
    threads: config.get("star_index_threads", 16)
    resources:
        mem_mb=config.get("star_index_memory", 40000)  # 40GB
    shell:
        """
        mkdir -p {output}
        
        STAR --runMode genomeGenerate \\
            --runThreadN {threads} \\
            --genomeDir {output} \\
            --genomeFastaFiles {input.fasta} \\
            --sjdbGTFfile {input.gtf} \\
            --sjdbOverhang {params.sjdb_overhang} \\
            > {log} 2>&1
        """

# Rule for STAR alignment with single-end reads (BRB-seq)
rule star_align_brbseq:
    input:
        r1=lambda wildcards: SAMPLES[wildcards.sample]["R1"],
        index=config.get("star_index", "/users/PAS2598/duarte63/rna_seq_resources/genome/star_index"),
        qc_complete="Analysis/QC/.qc_complete"
    output:
        bam="Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam",
        transcriptome_bam="Analysis/Alignment/STAR/{sample}/{sample}.Aligned.toTranscriptome.out.bam",
        counts="Analysis/Alignment/STAR/{sample}/{sample}.ReadsPerGene.out.tab",
        sj="Analysis/Alignment/STAR/{sample}/{sample}.SJ.out.tab",
        log_final="Analysis/Alignment/STAR/{sample}/{sample}.Log.final.out",
        log="Analysis/Alignment/STAR/{sample}/{sample}.Log.out",
        log_progress="Analysis/Alignment/STAR/{sample}/{sample}.Log.progress.out"
    log:
        "logs/star/{sample}.log"
    params:
        # STAR alignment parameters
        gtf=config.get("gtf_file", "/users/PAS2598/duarte63/rna_seq_resources/genome/Homo_sapiens.GRCh38.90.gtf"),
        prefix="Analysis/Alignment/STAR/{sample}/{sample}.",
        # STAR specific parameters
        outFilterMismatchNmax=config.get("star_mismatch", 10),
        outFilterMultimapNmax=config.get("star_multimap", 20),
        outFilterScoreMinOverLread=config.get("star_score_min", 0.66),
        outFilterMatchNminOverLread=config.get("star_match_min", 0.66),
        alignSJDBoverhangMin=config.get("star_sjdb_overhang_min", 3),
        alignIntronMax=config.get("star_intron_max", 500000),
        # Special parameters for large samples
        extra_params=lambda wildcards: "--limitIObufferSize 50000000 50000000 --limitOutSAMoneReadBytes 1000000" if wildcards.sample in ["Scaber_SRR28516486", "Scaber_SRR28516488", "Scaber_SRR28516489"] else ""
    threads: config.get("star_threads", 8)
    resources:
        mem_mb=config.get("star_memory", 64000)
    shell:
        """
        # Create output directory
        mkdir -p $(dirname {output.bam})
        
        # Log input files and verify they exist
        echo "===== STAR ALIGNMENT STARTING =====" > {log} 2>&1
        echo "Processing sample: {wildcards.sample}" >> {log} 2>&1
        echo "Date: $(date)" >> {log} 2>&1
        echo "Input reads:" >> {log} 2>&1
        echo "  R1: {input.r1}" >> {log} 2>&1
        echo "STAR index: {input.index}" >> {log} 2>&1
        echo "GTF file: {params.gtf}" >> {log} 2>&1
        echo "Threads: {threads}" >> {log} 2>&1
        
        # Verify input files exist
        if [ ! -f "{input.r1}" ]; then
            echo "ERROR: Input fastq file not found" >> {log} 2>&1
            exit 1
        fi
        
        if [ ! -d "{input.index}" ]; then
            echo "ERROR: STAR index directory not found" >> {log} 2>&1
            exit 1
        fi
        
        if [ ! -f "{params.gtf}" ]; then
            echo "ERROR: GTF file not found" >> {log} 2>&1
            exit 1
        fi
        
        # Set temporary directory for STAR (helps with network file system issues)
        export TMPDIR=$(dirname {output.bam})/tmp
        mkdir -p $TMPDIR
        
        # Run STAR alignment for single-end reads
        echo "Running STAR alignment..." >> {log} 2>&1
        set -o pipefail  # Ensure pipeline errors are caught
        
        STAR --runThreadN {threads} \\
            --genomeDir {input.index} \\
            --readFilesIn {input.r1} \\
            --readFilesCommand zcat \\
            --outFileNamePrefix {params.prefix} \\
            --outSAMtype BAM SortedByCoordinate \\
            --outSAMunmapped Within \\
            --outSAMattributes Standard \\
            --outFilterMismatchNmax {params.outFilterMismatchNmax} \\
            --outFilterMultimapNmax {params.outFilterMultimapNmax} \\
            --outFilterScoreMinOverLread {params.outFilterScoreMinOverLread} \\
            --outFilterMatchNminOverLread {params.outFilterMatchNminOverLread} \\
            --alignSJDBoverhangMin {params.alignSJDBoverhangMin} \\
            --alignIntronMax {params.alignIntronMax} \\
            --quantMode TranscriptomeSAM GeneCounts \\
            --sjdbGTFfile {params.gtf} \\
            --limitBAMsortRAM $(({resources.mem_mb} * 1000000 * 1/2)) \\
            {params.extra_params} \\
            >> {log} 2>&1
        
        STAR_EXIT_CODE=$?
        if [ $STAR_EXIT_CODE -ne 0 ]; then
            echo "ERROR: STAR alignment failed with exit code $STAR_EXIT_CODE" >> {log} 2>&1
            exit $STAR_EXIT_CODE
        fi
        
        # Verify output files exist
        if [ ! -f "{output.bam}" ]; then
            echo "ERROR: BAM file was not created: {output.bam}" >> {log} 2>&1
            exit 1
        fi
        
        if [ ! -f "{output.counts}" ]; then
            echo "ERROR: Counts file was not created: {output.counts}" >> {log} 2>&1
            exit 1
        fi
        
        # Check BAM file with samtools
        samtools quickcheck {output.bam}
        if [ $? -ne 0 ]; then
            echo "ERROR: BAM file failed samtools quickcheck: {output.bam}" >> {log} 2>&1
            exit 1
        fi
        
        # Print alignment statistics
        echo "===== ALIGNMENT STATISTICS =====" >> {log} 2>&1
        grep "Number of input reads" {output.log_final} >> {log} 2>&1
        grep "Uniquely mapped reads" {output.log_final} >> {log} 2>&1
        grep "% of reads mapped to multiple loci" {output.log_final} >> {log} 2>&1
        grep "% of reads unmapped" {output.log_final} >> {log} 2>&1
        
        # Clean up temporary directory
        rm -rf $TMPDIR
        
        echo "===== STAR ALIGNMENT COMPLETED SUCCESSFULLY =====" >> {log} 2>&1
        echo "Date: $(date)" >> {log} 2>&1
        echo "Output BAM: {output.bam}" >> {log} 2>&1
        echo "Output counts: {output.counts}" >> {log} 2>&1
        """

# Rule to index BAM files
rule index_bam:
    input:
        bam="Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam"
    output:
        bai="Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam.bai"
    log:
        "logs/star/{sample}.index.log"
    threads: 1
    resources:
        mem_mb=config.get("bam_index_memory", 4000)
    shell:
        """
        samtools index {input.bam} {output.bai} 2> {log}
        """

# Rule to extract alignment metrics
rule alignment_metrics:
    input:
        bam="Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam",
        bai="Analysis/Alignment/STAR/{sample}/{sample}.Aligned.sortedByCoord.out.bam.bai"
    output:
        flagstat="Analysis/Alignment/STAR/{sample}/{sample}.flagstat.txt",
        idxstats="Analysis/Alignment/STAR/{sample}/{sample}.idxstats.txt",
        stats="Analysis/Alignment/STAR/{sample}/{sample}.stats.txt"
    log:
        "logs/star/{sample}.metrics.log"
    threads: 1
    resources:
        mem_mb=config.get("metrics_memory", 4000)
    shell:
        """
        # Generate alignment metrics
        samtools flagstat {input.bam} > {output.flagstat} 2> {log}
        samtools idxstats {input.bam} > {output.idxstats} 2>> {log}
        samtools stats {input.bam} > {output.stats} 2>> {log}
        """

# Rule to run MultiQC on alignment results
rule multiqc_alignment:
    input:
        star_logs=expand("Analysis/Alignment/STAR/{sample}/{sample}.Log.final.out", sample=SAMPLES.keys()),
        flagstats=expand("Analysis/Alignment/STAR/{sample}/{sample}.flagstat.txt", sample=SAMPLES.keys()),
        idxstats=expand("Analysis/Alignment/STAR/{sample}/{sample}.idxstats.txt", sample=SAMPLES.keys()),
        stats=expand("Analysis/Alignment/STAR/{sample}/{sample}.stats.txt", sample=SAMPLES.keys())
    output:
        html="Analysis/Alignment/MultiQC/multiqc_report.html",
        data_dir=directory("Analysis/Alignment/MultiQC/multiqc_data")
    log:
        "logs/star/multiqc.log"
    params:
        outdir="Analysis/Alignment/MultiQC"
    resources:
        mem_mb=config.get("multiqc_alignment_memory", 4000)
    shell:
        """
        # Create output directory
        mkdir -p {params.outdir}
        
        # Run MultiQC
        multiqc --force \\
            --outdir {params.outdir} \\
            Analysis/Alignment/STAR/ \\
            > {log} 2>&1
            
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
        """