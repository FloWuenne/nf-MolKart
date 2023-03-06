#!/usr/bin/env python

### This script takes a list of images and stacks them into a single image stack

import numpy as np
import argparse
import tifffile

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "-i",
        "--input", 
        nargs="+", 
        help="List of images to stack"
        )
    parser.add_argument(
        "-o",
        "--output",
        dest="output",
        type=str,
    )
    
    args = parser.parse_args()

    # Use tifffile to read an arbitrary number of images into a list
    ### ! Maybe replace this with dask to reduce memory usage
    img_list = [tifffile.imread(img) for img in args.input]
    
    ## Create an empty list
    img_ch = []
    for img in img_list:
        if len(img.shape) > 2: ## Check if image is multi-channel
            print(img.shape)
            ch_list = np.split(img,img.shape[0], axis=0) ## If image is multi-channel, split into single-channel images
            for channel in ch_list:
                # Make channel a 2D image
                channel = np.squeeze(channel)
                img_ch.append(channel)
        else:
            img_ch.append(img)
    
    img_stack = np.stack(img_ch, axis=0) ## Stack all final images into a single image stack
    
    # Use tifffile to write the image stack to disk
    tifffile.imwrite(args.output, img_stack, metadata={'axes': 'CYX'})