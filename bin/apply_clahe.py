#!/usr/bin/env python

# Write a function to apply skimage's CLAHE to an image and return the result
def apply_clahe(img, kernel_size=50, clip_limit=0.02, bins= 256):
    # Normalize image to 0-1
    img = (img/img.max())*65535
    # Apply CLAHE
    img = exposure.equalize_adapthist(img, clip_limit=clip_limit, nbins=nbins, kernel_size=grid_size)
    # Transform image to 16 bit
    img = (img/img.max())*65535
    return img

if __name__ == "__main__":
    # Write a python argument parser with options for input, output, clip limit and grid size
    import argparse
    from skimage import exposure
    import tifffile

    parser = argparse.ArgumentParser()
    parser.add_argument("-i", "--input", required=True, help="Input image")
    parser.add_argument("-o", "--output", required=True, help="Output image")
    parser.add_argument("-k", "--kernel_size", required=False, type=float, default=50, help="Kernel size")
    parser.add_argument("-c", "--clip_limit", required=False, type=int, default=0.02, help="Clip limit")
    parser.add_argument("-b", "--nbins", required=False, type=int, default=256, help="Number of bins")
    args = parser.parse_args()

    # Read image
    img = tifffile.imread(args.input)

    # Apply CLAHE
    img = apply_clahe(img, clip_limit=args.clip, grid_size=args.grid, nbins = args.nbins)

    # Save image
    tifffile.imsave(args.output, img)