#!/usr/bin/env python
import numpy as np
import skimage.io as io
from skimage.measure import label, regionprops
import argparse
import time

# Function for plotting a mask and a filtered mask based on size next to it using plotly express
def filter_masks(image, min_area, max_area):
    print(image)
    image = io.imread(image)
    start = time.time()
    label_img = label(image, background=0)
    print(f'Label: {time.time() - start} seconds')
    start = time.time()
    props = regionprops(label_img)
    print(f'Regionprops: {time.time() - start} seconds')

     # Create a mapping between label and area
    label_area_map = {prop.label: prop.area for prop in props}
    
    start = time.time()
    # Vectorized calculation of valid and invalid masks
    valid_labels = np.array([label for label, area in label_area_map.items() if min_area < area < max_area])
    retained_masks = np.isin(label_img, valid_labels) * label_img
    
    invalid_labels = np.array([label for label, area in label_area_map.items() if not min_area < area < max_area])
    discarded_masks = np.isin(label_img, invalid_labels) * label_img

    print(f'Loop: {time.time() - start} seconds')
    start = time.time()
    io.imsave("retained_masks.tiff", retained_masks)
    io.imsave("discarded_masks.tiff", discarded_masks)
    print(f'Saving: {time.time() - start} seconds')

    # discarded_masks = np.copy(label_img)
    # start = time.time()
    # for prop in props:
    #     if prop.area > min_area and prop.area < max_area:
    #         label_img[label_img == prop.label] = prop.label
    #         discarded_masks[discarded_masks == prop.label] = False
    #     else:
    #         label_img[label_img == prop.label] = False
    #         discarded_masks[discarded_masks == prop.label] = prop.label
    # print(f'Loop: {time.time() - start} seconds')
    # start = time.time()
    # io.imsave("retained_masks.tiff", label_img)
    # io.imsave("discarded_masks.tiff", discarded_masks)
    # print(f'Saving: {time.time() - start} seconds')
    
    

if __name__ == "__main__":
    # Make a command line interface for plot_size_filter with argparse and call the function with the arguments from the command line
    parser = argparse.ArgumentParser()
    parser.add_argument("-i","--image", help="path to image")
    parser.add_argument("-min","--min_area",default = 100, type=int, help="minimum mask area in pixels")
    parser.add_argument("-max","--max_area",default = 50000, type=int, help="maximum mask area in pixels")
    args = parser.parse_args()
    filter_masks(args.image, args.min_area, args.max_area)