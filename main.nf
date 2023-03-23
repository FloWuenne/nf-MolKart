#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Pipeline for processing Molecular Cartography data
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/* Author : Florian Wuennemann */
nextflow.enable.dsl = 2

/* log info */
log.info """\
NEXTFLOW - DSL2 - Nextflow Molecular Cartography pipeline
"""

/* Local modules */
include { MINDAGAP_MINDAGAP } from './modules/local/mindagap/mindagap'
include { ILASTIK_PIXELCLASSIFICATION } from './modules/local/ilastik/pixelclassification'
include { ILASTIK_MULTICUT } from './modules/local/ilastik/multicut'
include { MCQUANT } from './modules/local/mcquant'

/* nf-core modules */
// MODULE: Installed directly from nf-core/modules

/* vanilla MCMICRO modules */

/* custom processes */
include { PROJECT_SPOTS; MKIMG_STACKS; MK_ILASTIK_TRAINING_STACKS; TIFF_TO_H5; APPLY_CLAHE_DASK } from './nf_processes.nf'

workflow {

    // Read in sample sheet
    samples = Channel.fromPath(params.sample_sheet)
        .splitCsv(header: true, strip : true)
        .branch{
            meta ->
                image : meta.type == "image"
                    return tuple(meta, params.imgs_path + meta.filename)
                spots : meta.type == "spot_table"
                    return tuple(meta, params.spots_path + meta.filename, params.imgs_path + meta.id + ".DAPI.small_crop.tiff" )
        }

    // Use Mindagap to fill gridlines in Molecular Cartography images and create a list of tuples with image id and path to filled images
    MINDAGAP_MINDAGAP(samples.image)

    // Project spots from Molecular Cartography data to 2d numpy arrays for quantification
    PROJECT_SPOTS(samples.spots.map(it -> tuple(it[0],it[1]) ),
        samples.spots.map(it -> it[2])
    )

    // Check if spots should be blurred to use for pixel classification in ilastik
    if (params.use_rasterize_spots) {
            // Blur spots from Molecular Cartography data to use for pixel classification in ilastik
        RSTR_SPOTS(samples.spots.map(it -> tuple(it[0],it[1]) ), 
            samples.spots.map(it -> it[2])  , 
            params.tensor_size,
            params.genes)

        // img2stack = MINDAGAP.out.tiff
        //     .groupTuple()
        //     .collect()
        //     .join(RSTR_SPOTS.out.imgs_spots)
        //     .map{it -> tuple(it[0], tuple(it[1] , it[2]).flatten().join(" "))}

        img2stack = MINDAGAP_MINDAGAP.out.tiff
            .map{
                meta,tiff -> [meta.id,tiff]}
            .groupTuple()
            .join(RSTR_SPOTS.out.imgs_spots)
            .map { id, tiffs -> tuple( [id: id], tiffs.sort{it.name} ) }
    }else{
        img2stack = MINDAGAP_MINDAGAP.out.tiff
            .map{
                meta,tiff -> [meta.id,tiff]}
            .groupTuple()
            .map { id, tiffs -> tuple([id: id], tiffs.sort{it.name} ) }
    }

    // Create stacks from mindagap filled images and blurred spots
    MKIMG_STACKS(img2stack)

    // Apply CLAHE to select channels
    APPLY_CLAHE_DASK(MKIMG_STACKS.out.mcimage)

    // Check if Ilastik training images should be created or training applied to the full image stacks
    if (params.create_ilastik_training) {  
    
    // Create training stacks for ilastik pixel classification
    nr_chan = img2stack
        .map{meta, tiffs -> tiffs.size()}

    MK_ILASTIK_TRAINING_STACKS(
        APPLY_CLAHE_DASK.out.img_clahe,
        tuple(params.crop_size_x,params.crop_size_y),
        params.nonzero_fraction,
        params.crop_amount,
        nr_chan, 
        params.channel_ids)

    }else{
    // Convert tiff stack to h5
    TIFF_TO_H5(
        APPLY_CLAHE_DASK.out.img_clahe,
        params.channel_ids)

    // Run ilastik pixel classification on image stacks
    ILASTIK_PIXELCLASSIFICATION(
        TIFF_TO_H5.out.hdf5,
        tuple([id:"ilastik pixel classification"],params.ilastik_pixelprob_model),
        )

    // Run ilastik multicut on boundery information from probability maps created in previous step
    ILASTIK_MULTICUT(
        TIFF_TO_H5.out.hdf5,
        tuple([id:"ilastik multicut"],params.ilastik_multicut_model),
        ILASTIK_PIXELCLASSIFICATION.out.output
        )

        // 

    // Quantify spot counts over masks
    MCQUANT(PROJECT_SPOTS.out.img_spots,
            ILASTIK_MULTICUT.out.out_tiff,
            PROJECT_SPOTS.out.channel_names) // TODO : Add marker list for 2d spots here!
    }
}

workflow.onComplete {
	log.info ( workflow.success ? "\nDone!" : "Oops .. something went wrong" )
}
