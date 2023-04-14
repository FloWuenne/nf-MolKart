#!/usr/bin/env python3
# importing the module
import ast
import tifffile as tiff
import os
import argparse

# Create a function to create crops from a tiff image and a dictionary of crop coordinates
def create_crops(tiff_image,crop_dict):
    for index, (crop_name, crop) in enumerate(crop_dict.items()):
        crop_image = tiff_image[:,crop[0][0]:crop[0][1],  crop[1][0]:crop[1][1]]
        basename =os.path.basename(args.input)
        basename = os.path.splitext(basename)[0]
        tiff.imsave(f"./{basename}_crop{index}.tiff",crop_image)

## Run the script
if __name__ == "__main__":
    # Add argument parser with arguments for input tiffile, crop_summary input file and output tiffile
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--input", 
        help="Input tiffile."
        )
    parser.add_argument(
        "-c",
        "--crop_summary", 
        help="Crop summary file."
        )
    args = parser.parse_args()
    
    # reading the crop information from the file
    with open(args.crop_summary) as f:
        crops = f.read()
    # reconstructing the data as a dictionary
    crops = ast.literal_eval(crops)
        ## Read in tiff image
    tiff_image = tiff.imread(args.input)
    
    create_crops(tiff_image,crops)