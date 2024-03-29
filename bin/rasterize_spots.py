#!/usr/bin/env python

#### This script takes a table of Molecular Cartography spots as input and projects them
#### onto a reference image. It then dilates the points and blurs the image to create a
#### spot image stack that can be used for training an ilastik model.


## Import packages
import argparse
import pandas as pd
import torch
import torch.nn as nn
import numpy as np
import tifffile
import skimage as skio
from rich.progress import track
from aicsimageio.writers import OmeTiffWriter
#import cv2 as cv
from skimage.morphology import square
from skimage.morphology import dilation

# Make a function to project a table of spots with x,y coordinates onto a 2d plane based on reference image shape and add any duplicate spots to increase their pixel value in the output image
def project_spots(spot_table,img):
    # Initialize an empty image with the same shape as the reference image
    img = np.zeros_like(img, dtype= 'int16')
    # Iterate through each spot in the table
    for spot in spot_table.itertuples():
        # Add the corresponding spot count to the pixel value at the spot's x,y coordinates
        img[spot.y, spot.x] += spot.counts
    return img


def pixel_expander(array, ts=2, use_sum=True):
    # Convert array to tensor
    input = torch.Tensor(array)

    # Calculate padded size
    padded_size = (ts * (input.size()[0]//ts + input.size()[0]%ts), ts * (input.size()[1]//ts + input.size()[1]%ts))

    # Compatible size
    padded = torch.zeros(padded_size)
    padded[0:input.size()[0],0:input.size()[1]] = input

    # Sum pool
    if use_sum:
        m = nn.AvgPool2d(ts, stride=ts, divisor_override=1) # Divisor override is important
    else:
        m = nn.AvgPool2d(ts, stride=ts)

    output = m(padded.unsqueeze(dim=0))

    # Get outputs
    output = output.squeeze(dim=0).unsqueeze(dim=-1).repeat(1, ts, ts)

    # Reshape output
    output = output.reshape(padded_size)

    # Subset output to input size
    output = output[0:array.shape[0], 0:array.shape[1]]
    #output *= (255.0/output.max())

    # Return output tensor
    return output

## Function that takes a list of spots and sums them together to create a single image
def sum_spots(spot_list):
    # Initialize an empty image with the same shape as the reference image
    img = np.zeros_like(spot_list[0], dtype= 'int16')
    # Iterate through each spot in the table
    for spot in spot_list:
        # Add 1 to the pixel value at the spot's x,y coordinates
        img += spot
    img = sum([spot for spot in spot_list])
    
    # Transform image to 8 bit
    img = (img/img.max())*255
    
    #element = cv.getStructuringElement(cv.MORPH_RECT, (3,3))
    # img_dil = cv.dilate(img, element)
    img_dil = dilation(img, square(3))
    img_blur = skio.filters.gaussian(img_dil, sigma=5)
    
    img_blur = (img_blur/img_blur.max())*65535
    
    return img_blur
    
if __name__ == "__main__":
    # Add a python argument parser with options for input, output and image size in x and y
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--input", 
        help="Spot table to project."
        )
    parser.add_argument(
        "-o",
        "--output",
        dest="output",
        type=str,
        help="Spot image stack with dimensions provided by --dims."
    )
    parser.add_argument(
        "-d",
        "--img_dims",
        dest="img_dims",
        help="Corresponding image to get dimensions from."
    )
    # # add argument for tensor_size as int
    # parser.add_argument(
    #     "-t",
    #     "--tensor_size",
    #     dest="tensor_size",
    #     type=int,
    #     help="Size of tensor to expand pixels to."
    # )
    # # add argument for genes to select
    # parser.add_argument(
    #     "-g",
    #     "--genes",
    #     dest="genes",
    #     type=str,
    #     help="Genes to rasterize."
    # )
    
    args = parser.parse_args()
    
    spots = pd.read_csv(args.input)
    img = tifffile.imread(args.img_dims)
    
    spots_sub = spots[["y","x", "gene"]]
    
    # subset spots for only those genes supplied in args.genes and save to spots_sub
    #sub_genes = list(args.genes.split(" "))
    #spots_sub = spots_sub[spots_sub.gene.isin(sub_genes)]
    spots_zsum = spots_sub.value_counts().to_frame('counts').reset_index()
    
    # Project each gene into a 2d plane and add to list
    
    # Add a printed message that says "Projecting spots for gene X" for each gene in the list
    spots_2d_list = [project_spots(spots_zsum[spots_zsum.gene == gene], img) for gene in track(spots_zsum.gene.unique(), description='[green]Projecting spots...')]
    
    # Sum spots in list to create a single image
    spot_2d_stack = sum_spots(spots_2d_list)
    
    ## Expand pixels in the list to a tensor of size args.tensor_size
    # spots_2d_list_exp10 = [pixel_expander(img,ts=args.tensor_size) for img in track(spots_2d_list,'[cyan]Rastering spots...')]
    # spots_2d_list_exp10 = [(exp_img/exp_img.max())*65535 for exp_img in spots_2d_list_exp10]
    ## Use numpy to stack an arbitrary number of images into a single image stack
    # spot_2d_stack = np.stack(spots_2d_list_exp10, axis=0)

    # # Use tifffile to write the image stack to disk 
    #tifffile.imwrite(args.output, spot_2d_stack, metadata={'axes': 'CYX'})
    OmeTiffWriter.save(spot_2d_stack,
                       args.output, 
                       dim_order = "YX")