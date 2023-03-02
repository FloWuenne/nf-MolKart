## This script contains the commands for a very simple way to update local modules from Github branches
## !!! Has to be executed from the same directory it's in, due to relative filepaths

## ilastik/pixelclassification
mkdir ilastik
mkdir ilastik/pixelclassification
wget -O ./ilastik/pixelclassification/main.nf https://raw.githubusercontent.com/FloWuenne/modules/ilastik/pixelclassification/modules/nf-core/ilastik/pixelclassification/main.nf
wget -O ./ilastik/pixelclassification/meta.yml https://raw.githubusercontent.com/FloWuenne/modules/ilastik/pixelclassification/modules/nf-core/ilastik/pixelclassification/meta.yml

## Multicut
mkdir ilastik
mkdir ilastik/multicut
wget -O ./ilastik/multicut/main.nf https://raw.githubusercontent.com/FloWuenne/modules/ilastik/multicut/modules/nf-core/ilastik/multicut/main.nf
wget -O ./ilastik/multicut/meta.yml https://raw.githubusercontent.com/FloWuenne/modules/ilastik/multicut/modules/nf-core/ilastik/multicut/meta.yml

