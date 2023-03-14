## Image dimensions of the test image are:
## 
## width (x)    = 17152
## height (y)   = 19296 

test_data=/Users/florian_wuennemann/1_Projects/MI_project/data/nextflow_test_data
script_dir=/Users/florian_wuennemann/1_Projects/MI_project/nf_molcat/bin
python rasterize_spots.py \
    --input $test_data/sample_2d_r1_s1.spots.txt \
    --output $test_data/sample_2d_r1_s1.spots.tiff \
    --img_dims $test_data/sample_2d_r1_s1.DAPI.tiff


## Test using docker container 
docker run --rm -it -v $test_data:/input -v $script_dir:/scripts rasterize_spots:latest python /scripts/rasterize_spots.py \
--input /input/sample_2d_r1_s1.spots.txt \
--output /input/sample_2d_r1_s1.spots.tiff \
--img_dims /input/sample_2d_r1_s1.DAPI.tiff
