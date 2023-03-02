## Test the nextflow workflow
nextflow run main.nf -c ./nextflow.config -resume

# raw_img_path = "/Users/florian_wuennemann/Downloads/img_test/*.tiff"

# -with-report "./nextflow_reports/test_report.html" \
# -with-timeline "./nextflow_reports/test_timeline.html"
# --grm_plink_input "$work_dir/test_data/input/nfam_100_nindep_0_step1_includeMoreRareVariants_poly.{bed,bim,fam}" \
# --phenoFile "$work_dir/test_data/input/pheno*.txt" \
# --phenoCol "y_binary" \
# --covarColList "x1,x2" \
# --bgen_prefix "genotype_100markers.chr" \
# --bgen_suffix ".bgen" \
# --bgen_path "$work_dir/test_data/input" \
# --sampleFile "$work_dir/test_data/input/samplefile_test_input.txt" \
# --outdir "../saige_test_out" \
# --gwas_cat "../gwascat.csv"