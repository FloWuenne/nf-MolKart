#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Pipeline for processing Molecular Cartography data for myocardial infarction
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/* Author : Florian Wuennemann */
nextflow.enable.dsl = 2

/* log info */
log.info """\
NEXTFLOW - DSL2 - Nextflow Molecular Cartography pipeline
"""

/* Local modules */
include { MINDAGAP } from './modules/local/mindagap'
include { ILASTIK_PIXELCLASSIFICATION } from './modules/local/ilastik/pixelclassification'
include { ILASTIK_MULTICUT } from './modules/local/ilastik/multicut'

/* nf-core modules */
// MODULE: Installed directly from nf-core/modules

/* vanilla MCMICRO modules */



/* custom processes */
process BLURRED_SPOTS{
    input:
     tuple val(meta), path(spots)

    output:
    tuple val(meta), path("${spots.baseName}_subsampled.tiff"), emit: image_spots

    script:
    """
    sleep 5
    cp $spots "${spots.baseName}_subsampled.tiff"
    """
}

process MKIMG_STACKS{
    
    container 'jacksonmaxfield/aicsimageio:latest'
    
    input:
    tuple val(meta), val(stacks)

    output:
    path("image_stack_stack.txt"), emit: stack

    script:
    """
    echo $stacks > image_stack_stack.txt
    """
}

process convert_to_hdf5{
    container 'kbestak/tiff_to_hdf5:v0.0.1'

    input:
    tuple val(meta), path(image_stack)

    output:
    path("image_stack_stack.h5"), emit: h5

    script:
    """
    python CommandIlastikPrepOME.py \
    --input "${image_stack}" \
    --output h5 \
    --axes 'tzyxc'
    """
}

workflow {
    // Identify marker information
    //chMrk = Channel.fromPath( "${params.in}/markers.csv", checkIfExists: true )

    samples = Channel.fromPath(params.sample_sheet)
        .splitCsv(header: true, strip : true)
        .branch{
            meta ->
                image : meta.type == "image"
                    return tuple(id: meta.sample, params.imgs_path + meta.filename)
                spots : meta.type == "spot_table"
                    return tuple(id: meta.sample, params.spots_path + meta.filename)
        }

    // Blur spots from Molecular Cartography data to use for pixel classification in ilastik
    BLURRED_SPOTS(samples.spots)

    // Use Mindagap to fill gridlines in Molecular Cartography images and create a list of tuples with image id and path to filled images
    MINDAGAP(samples.image)

    image_stack = MINDAGAP.out.tiff
        .groupTuple()
        .combine(BLURRED_SPOTS.out.image_spots, by : 0)
        .map{it -> tuple(it[0], tuple(it[1] , it[2]))}
        .view()

    // Create stacks from mindagap filled images and blurred spots
    // MKIMG_STACKS(image_stack)

    // Run ilastik pixel classification on image stacks
    // ILASTIK_PIXELCLASSIFICATION()

    // Run ilastik multicut on boundery information from probability maps created in previous step
    // ILASTIK_MULTICUT()

    // Quantify Ilastik

}

workflow.onComplete {
	log.info ( workflow.success ? "\nDone!" : "Oops .. something went wrong" )
}