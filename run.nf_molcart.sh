## Test the nextflow workflow
nextflow run main.nf -c ./nextflow.config \
-resume \
-profile test,docker \
-with-dag dag.html \
-with-tower \
--outdir "/Users/florian_wuennemann/1_Projects/MI_project/data/nf_molcart_test" \
--ilastik_model_dir "/Users/florian_wuennemann/1_Projects/MI_project/data/nextflow_test_data/small_test_data/" \
--cellpose_model "/Users/florian_wuennemann/1_Projects/MI_project/data/segmentation_models/CP_20230417_172320"