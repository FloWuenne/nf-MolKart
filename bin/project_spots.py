#!/usr/bin/env python

#### This script takes a table of Molecular Cartography spots as input and projects them
#### onto a reference image. The output is a stack of images, one for each spot, with 
#### the spot projected onto the reference image shape.

## Import packages
import argparse
import pandas as pd
import numpy as np
import tifffile
from rich.progress import track
from aicsimageio.writers import OmeTiffWriter

# Make a function to project a table of spots with x,y coordinates onto a 2d plane based on reference image shape and add any duplicate spots to increase their pixel value in the output image
def project_spots(spot_table,img):
    # Initialize an empty image with the same shape as the reference image
    img = np.zeros_like(img, dtype= 'int16')
    # Iterate through each spot in the table
    for spot in spot_table.itertuples():
        # Add the corresponding spot count to the pixel value at the spot's x,y coordinates
        img[spot.y, spot.x] += spot.counts
    return img

if __name__ == "__main__":
    # Add a python argument parser with options for input, output and image size in x and y
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--input", 
        help="Spot table to project."
        )
    parser.add_argument(
        "-s",
        "--sample_id", 
        help="Sample ID."
        )
    parser.add_argument(
        "-d",
        "--img_dims",
        dest="img_dims",
        help="Corresponding image to get dimensions from."
    )
    
    args = parser.parse_args()
    
    spots = pd.read_csv(args.input)
    img = tifffile.imread(args.img_dims)
    
    spots = spots[["y","x", "gene"]]
    
    # Sum spots by z-axis
    spots_zsum = spots.value_counts().to_frame('counts').reset_index()
    
    # Project each gene into a 2d plane and add to list
    # Add a printed message that says "Projecting spots for gene X" for each gene in the list
    spots_2d_list = [project_spots(spots_zsum[spots_zsum.gene == gene], img) for gene in track(spots_zsum.gene.unique(), description='[green]Projecting spots...')]
    
    # Stack images on the c-axis
    spot_2d_stack = np.stack(spots_2d_list, axis=0)
    
    ## Write a csv file containing the channel names
    channel_names = spots_zsum.gene.unique().tolist()
    pd.DataFrame(channel_names).to_csv("channel_names.csv", index=False, header=False)
    
    #tifffile.imwrite(args.output, spot_2d_stack, metadata={'axes': 'CYX'})
    OmeTiffWriter.save(spot_2d_stack,
                       args.sample_id + ".tiff", 
                       dim_order = "CYX")