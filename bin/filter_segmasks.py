#!/usr/bin/env python
import numpy as np
import skimage.io as io
from skimage.measure import label, regionprops
import argparse

# Function for plotting a mask and a filtered mask based on size next to it using plotly express
def filter_masks(image, min_area, max_area):
    image = io.imread(image)
    label_img = label(image, background=0)
    props = regionprops(label_img)
    discarded_masks = np.copy(label_img)
    for prop in props:
        if prop.area > min_area and prop.area < max_area:
            label_img[label_img == prop.label] = prop.label
            discarded_masks[discarded_masks == prop.label] = False
        else:
            label_img[label_img == prop.label] = False
            discarded_masks[discarded_masks == prop.label] = prop.label
    io.imsave("retained_masks.tiff", label_img)
    io.imsave("discarded_masks.tiff", discarded_masks)
    
    

if __name__ == "__main__":
    # Make a command line interface for plot_size_filter with argparse and call the function with the arguments from the command line
    parser = argparse.ArgumentParser()
    parser.add_argument("-i","--image", help="path to image")
    parser.add_argument("-min","--min_area",default = 100, type=int, help="minimum mask area in pixels")
    parser.add_argument("-max","--max_area",default = 50000, type=int, help="maximum mask area in pixels")
    args = parser.parse_args()
    filter_masks(args.image, args.min_area, args.max_area)