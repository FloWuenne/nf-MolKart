## Image dimensions of the test image are:
## 
## width (x)    = 17152
## height (y)   = 19296 
test_data=/Users/florian_wuennemann/1_Projects/MI_project/data/nextflow_test_data
python rasterize_spots.py \
    --input $test_data/sample_2d_r1_s1.spots.txt \
    --output $test_data/sample_2d_r1_s1.spots.tiff \
    --img_dims $test_data/sample_2d_r1_s1.DAPI.tiff \
    --tensor_size 20 \
    --genes "Aqp1 Vim Flt1"


#--genes "Aqp1 Vim Flt1 Pecam1 Myh11 Pdgfrb C1qa C3 Mmrn1 Ccr2"
