import os
import glob

# Automatically detect samples based on FASTQ files
FASTQ_FILES = sorted(glob.glob("sample_*.fastq.gz"))
if len(FASTQ_FILES) == 0:
    print("ERROR: No FASTQ files found. Please add sample_*.fastq.gz files.")
    exit(1)
SAMPLES = [os.path.basename(f).replace(".fastq.gz", "") for f in FASTQ_FILES]

print("Detected samples:", SAMPLES)

# Rule: All - final outputs
rule all:
    input:
        expand("fastqc_reports/{sample}_fastqc.html", sample=SAMPLES),
        "featureCounts_output.txt",
        "deseq2_results.txt",
        "deseq2_up.txt",
        "deseq2_down.txt"

# Rule: Run FASTQC on raw reads
rule quality_check:
    input:
        "{sample}.fastq.gz"
    output:
        "fastqc_reports/{sample}_fastqc.html",
        "fastqc_reports/{sample}_fastqc.zip"
    conda:
        "envs/fastqc.yaml"
    shell:
        "fastqc -o fastqc_reports {input}"

# Rule: Trim adapters with Cutadapt
rule adapter_trimming:
    input:
        "{sample}.fastq.gz"
    output:
        "trimmed_files/{sample}_trimmed.fastq.gz"
    conda: "envs/cutadapt.yaml"
    shell:
        "cutadapt --cut 5 --minimum-length 25 --quality-cutoff 30 "
        "-o {output} {input}"

# Rule: Generate STAR genome index
rule star_index:
    input:
        g="genome.fa",
        a="annotation.gtf"
    output:
        directory("star_index")
    conda: "envs/star.yaml"
    shell:
        "STAR --runMode genomeGenerate "
        "--genomeDir {output} "
        "--genomeFastaFiles {input.g} "
        "--sjdbGTFfile {input.a} "
        "--genomeSAindexNbases 11"

# Rule: Align reads with STAR
rule star_alignment:
    input:
        f="trimmed_files/{sample}_trimmed.fastq.gz",
        index="star_index"  # directory as proxy
    output:
        "alignment_results/{sample}_Aligned.out.sam"
    conda: "envs/star.yaml"
    params:
        prefix="alignment_results/{sample}_"
    threads: 2
    shell:
        "STAR --runThreadN {threads} "
        "--genomeDir star_index "
        "--readFilesIn {input.f} "
        "--readFilesCommand zcat "
        "--outFileNamePrefix {params.prefix} "
        "--outSAMtype SAM"

# Rule: Feature counting with featureCounts
rule feature_count:
    input:
        files=expand("alignment_results/{sample}_Aligned.out.sam", sample=SAMPLES),
        gtf="annotation.gtf"
    output:
        "featureCounts_output.txt"
    conda: "envs/subread.yaml"
    shell:
        "featureCounts -T 4 -s 1 -a {input.gtf} -g gene_name "
        "-o {output} {input.files}"

# Rule: Differential Expression Analysis
rule run_deseq2:
    input:
        counts="featureCounts_output.txt"
    output:
        results="deseq2_results.txt",
        up="deseq2_up.txt",
        down="deseq2_down.txt"
    conda: "envs/deseq2.yaml"
    shell:
        "Rscript deseq_rScript.r {input.counts} {output.results} {output.up} {output.down}"