#!/bin/bash

# Input VCF files directory
VCF_DIR="path/to/vcf/directory"

# Output directory
OUTPUT_DIR="path/to/output/directory/"

# Path to gene coordinates BED file
GENE_BED="path/to/bed/file/with/coordenates/of/gene/of/interest"

# Path to VEP executable
VEP="/path/to/vep"

# Path to VEP cache directory
VEP_CACHE="/path/to/vep_cache"

# Use the find command to locate VCF files
find "$VCF_DIR" -name "*deepvariant.vcf.gz" -type f | while read -r vcf; do
    # Extract the filename without the directory path and extension
    vcf_filename=$(basename "$vcf")
    vcf_basename="${vcf_filename%.vcf.gz}"

    # Construct the output file paths
    intersect_output_file="${OUTPUT_DIR}/intersect_${vcf_basename}.bed"
    subset_vcf_output_file="${OUTPUT_DIR}/subset_${vcf_basename}.vcf.gz"
    vep_output_file="${OUTPUT_DIR}/vep_${vcf_basename}.vcf"

    # Perform intersection using bedtools
    bedtools intersect -a "$GENE_BED" -b "$vcf" -wo > "$intersect_output_file"

    # Extract genes variants that "PASS" the filters
    pass_genes=$(awk '$11 == "PASS" { print $4 }' "$intersect_output_file")

    # Print the unique genes for this sample
    echo "Sample: $vcf_basename"
    echo "Unique Genes that PASS the filters:"
    echo "$pass_genes" | tr ',' '\n' | sort -u | tr '\n' ','

    # Extract and create a subset of the original VCF with intersected variants
    bcftools view -R "$intersect_output_file" -Oz -o "$subset_vcf_output_file" "$vcf"

    # Filter subset VCF to retain only lines with "PASS" in the 7th column
    bcftools view -i 'FILTER=="PASS"' -Oz -o "$subset_vcf_output_file" "$subset_vcf_output_file"

    # Run VEP on the subset VCF
    "$VEP" -i "$subset_vcf_output_file" -o "$vep_output_file" --cache --dir "$VEP_CACHE" --fork 4 --species homo_sapiens

    echo "Subset VCF file with intersected variants (PASS) saved at: $subset_vcf_output_file"
    echo "VEP output file saved at: $vep_output_file"

    # Print the lines with "PASS" in the 11th column
    echo "Variant's coordinates"
    awk '$11 == "PASS" { print }' "$intersect_output_file"
done
