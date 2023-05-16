# README

## !!! This pipeline is in active development. Please feel free to use, but be ware that things can change drastically.

`nf-MolCart` is a pipeline for processing [Molecular Cartography data from Resolve Bioscience](https://resolvebiosciences.com/). It allows for processing of DAPI and additional antibody based membrane stainings to use for cell segmentation. Nf-MolCart currently supports three different segmentation algorithms (Mesmer, Cellpose and Ilastik Multicut). After segmentation, deduplicated RNA spots are assigned to cell masks for downstream processing. This pipeline is highly inspired by and uses many similar components as [MCMICRO](https://mcmicro.org/).

# How to run the pipeline


# Pipeline usage

## Mandatory arguments

There are a couple of mandatory arguments you have to set for the pipeline to work:

| First Header                  | Second Header |
| -------------                 | ------------- |
| `--outdir`                    | Path to main directory to write pipeline output  |
| `--segmentation`              | Comma separated list of segmentation methods to be used. Currently supported options = "mesmer_nuclear, measmer_wc, cellpose, ilastik"  |
| `--ilastik_model_dir`         | Required if ilastik segmentation is selected. Path to ilastik pixel classification and multicut models. The model names by default are assumed to be `ilastik_pixelprob.ilp` and `ilastik_multicut.ilp` respectively.  |
| `--cellpose_model`            | Optional if Cellpose segmentation is selected and a custom model should be used.  |
| `--create_training_set`       | Boolean (True, False). Whether to run cell segmentation or to create training datasets in `.h5` format and .tiff format. |

## Optional arguments



# Citation
If you use this pipeline in your research, please cite this github repository.
