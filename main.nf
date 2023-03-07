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



// /* custom processes */
// process BLURRED_SPOTS_TEST{
    
//     input:
//     tuple val(meta), path(spots)

//     output:
//     tuple val(meta), path("${spots.baseName}_subsampled.tiff"), emit: image_spots

//     script:
//     """
//     sleep 5
//     cp $spots "${spots.baseName}_subsampled.tiff"
//     """
// }

/* custom processes */
process RSTR_SPOTS{

    container 'rasterize_spots:latest'

    input:
    tuple val(meta), path(spots)
    path(img)
    val(tensor_size)
    val(genes)

    output:
    tuple val(meta), path("${spots.baseName}.stack.tiff"), emit: imgs_spots

    script:
    """
    rasterize_spots.py \
    --input "${spots}" \
    --output "${spots.baseName}.stack.tiff" \
    --img_dims $img \
    --tensor_size $tensor_size \
    --genes $genes
    """
}

process MKIMG_STACKS{
    
    container 'rasterize_spots:latest'
    
    input:
    tuple val(meta), val(stacks)

    output:
    tuple val(meta), path("${meta.id}.stack.ome.tiff") , emit: mcimage

    script:
    """
    make_img_stacks.py --input ${stacks} --output "${meta.id}.stack.ome.tiff"
    """
}

process TIFF_TO_H5{
    container 'kbestak/tiff_to_hdf5:v0.0.1'

    input:
    tuple val(meta), path(image_stack)

    output:
    tuple val(meta), path("${meta.id}.stack.hdf5"), emit: hdf5

    script:
    """
    python /convert_hdf5/CommandIlastikPrepOME.py \
    --input $image_stack \
    --output . \
    --axes 'tzyxc' \
    --channelIDs 1 2 3 4 5
    """
}

workflow {

    samples = Channel.fromPath(params.sample_sheet)
        .splitCsv(header: true, strip : true)
        .branch{
            meta ->
                image : meta.type == "image"
                    return tuple(id: meta.sample, params.imgs_path + meta.filename)
                spots : meta.type == "spot_table"
                    return tuple(id: meta.sample, params.spots_path + meta.filename, params.imgs_path + meta.sample + ".DAPI.tiff" )
        }

    // Blur spots from Molecular Cartography data to use for pixel classification in ilastik
    RSTR_SPOTS(samples.spots.map(it -> tuple(it[0],it[1]) ), 
        samples.spots.map(it -> it[2])  , 
        params.tensor_size,
        params.genes)

    // Use Mindagap to fill gridlines in Molecular Cartography images and create a list of tuples with image id and path to filled images
    MINDAGAP(samples.image)

    img2stack = MINDAGAP.out.tiff
        .groupTuple()
        .collect()
        .join(RSTR_SPOTS.out.imgs_spots)
        .map{it -> tuple(it[0], tuple(it[1] , it[2]).flatten().join(" "))}

    // Create stacks from mindagap filled images and blurred spots
    MKIMG_STACKS(img2stack)

    // // Convert tiff stack to h5
    TIFF_TO_H5(MKIMG_STACKS.out.mcimage)

    // Run ilastik pixel classification on image stacks
    ILASTIK_PIXELCLASSIFICATION(
        TIFF_TO_H5.out.hdf5,
        tuple([id:"ilastik project"],params.ilastik_pixelprob_model),
        )

    // Run ilastik multicut on boundery information from probability maps created in previous step
    ILASTIK_MULTICUT(
        TIFF_TO_H5.out.hdf5,
        tuple([id:"ilastik project"],params.ilastik_multicut_model),
        ILASTIK_PIXELCLASSIFICATION.out.output
        )

    // Quantify Ilastik
    // QUANTIFICATION()

}

workflow.onComplete {
	log.info ( workflow.success ? "\nDone!" : "Oops .. something went wrong" )
}