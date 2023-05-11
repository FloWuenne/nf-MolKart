## Test the nextflow workflow
nextflow run main.nf -c ./nextflow.config \
-resume \
-profile test,docker \
-with-dag dag.html \
-with-tower \
--outdir "./nf_molcart_test" \
--ilastik_model_dir "$PWD/segmodels" \
--cellpose_model "$PWD/segmodels/CP_20230417_172320"