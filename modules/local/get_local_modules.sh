## This script contains the commands for a very simple way to update local modules from Github branches
## !!! Has to be executed from the same directory it's in, due to relative filepaths

## mindaga/duplicatefinder
mkdir mindagap/duplicatefinder
wget -O ./mindagap/duplicatefinder/main.nf https://raw.githubusercontent.com/FloWuenne/modules/mindagap_duplicatefinder/modules/nf-core/mindagap/duplicatefinder/main.nf
wget -O ./mindagap/duplicatefinder/meta.yml https://raw.githubusercontent.com/FloWuenne/modules/mindagap_duplicatefinder/modules/nf-core/mindagap/duplicatefinder/meta.yml

## mindagap/mindagap
wget -O ./mindagap/duplicatefinder/main.nf https://raw.githubusercontent.com/FloWuenne/modules/mindagap/modules/nf-core/mindagap/mindagap/main.nf
wget -O ./mindagap/duplicatefinder/meta.yml https://raw.githubusercontent.com/FloWuenne/modules/mindagap/modules/nf-core/mindagap/mindagap/meta.yml

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

## MCQUANT
mkdir mcquant
wget -O ./mcquant/main.nf https://raw.githubusercontent.com/FloWuenne/modules/mcquant/modules/nf-core/mcquant/main.nf
wget -O ./mcquant/meta.yml https://raw.githubusercontent.com/FloWuenne/modules/mcquant/modules/nf-core/mcquant/meta.yml