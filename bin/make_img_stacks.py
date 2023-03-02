#!/usr/bin/python
import numpy as np
import argparse
from aicsimageio.writers import OmeTiffWriter

# Use numpy to stack an arbitrary number of images into a single image stack
def stack_images():
    img_stack = np.stack(imgs, axis=0)
    return img_stack 
 
if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('imgs', nargs='+', help='List of images to stack')
    args = parser.parse_args()
    stacked_imgs = stack_images(args.imgs)
    OmeTiffWriter.save(stacked_imgs, "img_stack.ome.tif",dim_order="CYX")