# README
`nf-MolCart` is a pipeline for processing [Molecular Cartography data from Resolve Bioscience](https://resolvebiosciences.com/). It allows for processing of DAPI and additional antibody based stainings to use for cell segmentation using various different segmentation algorithms and then assigns and sums up RNA spots to cell masks. This pipeline is highly inspired by and uses components of the [MCMICRO](https://mcmicro.org/).

# Pipeline usage

| First Header                  | Second Header |
| -------------                 | ------------- |
| `--outdir`                    | Path to main directory to write pipeline output  |
| `--segmentation`              | Comma separated list of segmentation methods to be used. Currently supported options = "mesmer_nuclear, measmer_wc, cellpose, ilastik"  |
| `--ilastik_model_dir`         | Required if ilastik segmentation is selected. Path to ilastik pixel classification and multicut models. The model names by default are assumed to be `ilastik_pixelprob.ilp` and `ilastik_multicut.ilp` respectively.  |
| `--cellpose_model`            | Optional if Cellpose segmentation is selected and a custom model should be used.  |
| `--create_training_set`       | Boolean (True, False). Whether to run cell segmentation or to create training datasets in `.h5` format and .tiff format. |




# Pipeline setup

This is a step-by-step how the pipeline was initially set up. This does not need to be re-run when wanting to execute the pipeline and is intended more like a recipe to be able to reproduce pipeline setup if required.

1) Create a dummy `.nf-core.yml` file to be able to install nf-core modules.
2) Setup `main.nf` script and workflows folder
3) Install nf-core components and copy the `include` statements for each tool into `main.nf`:

    - mindagap/mindagap: 
        - `nf-core modules install mindagap/mindagap`
        - include { MINDAGAP_MINDAGAP } from '../modules/nf-core/mindagap/mindagap/main'
    - ilastik/pixelclassification: 
        - `nf-core modules install ilastik/pixelclassification`
        - include { ILASTIK_PIXELCLASSIFICATION } from '../modules/nf-core/ilastik/pixelclassification/main'
    - ilastik/multicut: 
        - `nf-core modules install ilastik/multicut`
        - include { ILASTIK_MULTICUT } from '../modules/nf-core/ilastik/multicut/main'
    - deepcell/mesmer : 
        - `nf-core modules install deepcell/mesmer`
        - include { DEEPCELL_MESMER } from '../modules/nf-core/deepcell/mesmer/main'
    - cellpose : 
        - `nf-core modules install cellpose`
        - include { CELLPOSE } from '../modules/nf-core/cellpose/main'
    - mcquant : 
        - `nf-core modules install mcquant`
        - include { MCQUANT } from '../modules/nf-core/mcquant/main'
    - scimap : 
        - `nf-core modules install scimap/mcmicro`
        - include { SCIMAP_MCMICRO } from '../modules/nf-core/scimap/mcmicro/main'