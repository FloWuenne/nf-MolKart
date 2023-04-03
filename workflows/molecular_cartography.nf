/* nf-core modules */
// MODULE: Installed directly from nf-core/modules
include { MINDAGAP_MINDAGAP } from '../modules/nf-core/mindagap/mindagap/main'
include { ILASTIK_PIXELCLASSIFICATION } from '../modules/nf-core/ilastik/pixelclassification/main'
include { ILASTIK_MULTICUT } from '../modules/nf-core/ilastik/multicut/main'
include { DEEPCELL_MESMER } from '../modules/nf-core/deepcell/mesmer/main'
include { CELLPOSE } from '../modules/nf-core/cellpose/main'
include { MCQUANT as MCQUANT_ILASTIK } from '../modules/nf-core/mcquant/main'
include { MCQUANT as MCQUANT_MESMER } from '../modules/nf-core/mcquant/main'
include { MCQUANT as MCQUANT_CELLPOSE } from '../modules/nf-core/mcquant/main'
include { SCIMAP_MCMICRO as SCIMAP_MCMICRO_MESMER } from '../modules/nf-core/scimap/mcmicro/main'
include { SCIMAP_MCMICRO as SCIMAP_MCMICRO_CELLPOSE } from '../modules/nf-core/scimap/mcmicro/main'
include { SCIMAP_MCMICRO as SCIMAP_MCMICRO_ILASTIK } from '../modules/nf-core/scimap/mcmicro/main'


/* custom processes */
include { PROJECT_SPOTS; MKIMG_STACKS; MK_ILASTIK_TRAINING_STACKS; TIFF_TO_H5; APPLY_CLAHE_DASK } from '../nf_processes.nf'

workflow MOLECULAR_CARTOGRAPHY{

    // Read in sample sheet
    samples = Channel.fromPath(params.sample_sheet)
        .splitCsv(header: true, strip : true)
        .branch{
            meta ->
                image : meta.type == "image"
                    return tuple(meta, params.imgs_path + meta.filename)
                spots : meta.type == "spot_table"
                    return tuple(meta, params.spots_path + meta.filename, params.imgs_path + meta.id + ".DAPI.tiff" )
        }

    // Use Mindagap to fill gridlines in Molecular Cartography images and create a list of tuples with image id and path to filled images
    MINDAGAP_MINDAGAP(samples.image, params.mindagap_boxsize, params.mindagap_loopnum)

    // Use the mindagap output to create an image stack from the filled images
    img2stack = MINDAGAP_MINDAGAP.out.tiff
            .map{
                meta,tiff -> [meta.id,tiff]}
            .groupTuple()
            .map { id, tiffs -> tuple([id: id], tiffs.sort{it.name} ) }

    // Create stacks from mindagap filled images and blurred spots
    MKIMG_STACKS(img2stack)

    // Apply CLAHE to select channels
    APPLY_CLAHE_DASK(MKIMG_STACKS.out.mcimage)

    // Check if Ilastik training images should be created or training applied to the full image stacks
    if (params.create_training_set) {  
    
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
    // Project spots from Molecular Cartography data to 2d numpy arrays for quantification
    PROJECT_SPOTS(samples.spots.map(it -> tuple(it[0],it[1]) ),
        samples.spots.map(it -> it[2])
    )

    if (params.use_mesmer){
    // // Mesmer whole-cell segmentation
    DEEPCELL_MESMER(img2stack.map(it -> tuple(it[0],it[1][0])),
                    [[:],[]])
                    // img2stack.map(it -> tuple(it[0],it[1][1])

    // // Quantify spot counts over masks
    MCQUANT_MESMER(PROJECT_SPOTS.out.img_spots,
            DEEPCELL_MESMER.out.mask,
            PROJECT_SPOTS.out.channel_names)
    }


    //SCIMAP_MCMICRO_MESMER(MCQUANT_MESMER.out.csv)

    // Cellpose segmentation and quantification
    CELLPOSE(APPLY_CLAHE_DASK.out.img_clahe,
            [])

    cellpose_mask = CELLPOSE.out.mask
        .map{
            meta,tiff -> [meta.id,tiff]}

    mcquant_cellpose_in = PROJECT_SPOTS.out.img_spots
        .join(PROJECT_SPOTS.out.channel_names)
        .map{
            meta,tiff,channels -> [meta.id,tiff,channels]}
        .join(cellpose_mask)

    // Quantify spot counts over masks
    MCQUANT_CELLPOSE(mcquant_cellpose_in.map{it -> tuple([id:it[0]],it[1])},
            mcquant_cellpose_in.map{it -> tuple([id:it[0]],it[3])},
            mcquant_cellpose_in.map{it -> tuple([id:it[0]],it[2])})

    // Create Scimap object
    // SCIMAP_MCMICRO_CELLPOSE(MCQUANT_CELLPOSE.out.csv)

    //// Ilastik segmentation and quantification
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


    ILASTIK_MULTICUT.out.out_tiff
        .map{
            meta,tiff -> [meta.id,tiff]}
        .set{ilastik_mask}

    mcquant_multicut_in = PROJECT_SPOTS.out.img_spots
        .join(PROJECT_SPOTS.out.channel_names)
        .map{
            meta,tiff,channels -> [meta.id,tiff,channels]}
        .join(ilastik_mask)

    // Quantify spot counts over masks
    MCQUANT_ILASTIK(mcquant_multicut_in.map{it -> tuple([id:it[0]],it[1])},
            mcquant_multicut_in.map{it -> tuple([id:it[0]],it[3])},
            mcquant_multicut_in.map{it -> tuple([id:it[0]],it[2])})
    
    // Create Scimap object
    // SCIMAP_MCMICRO_ILASTIK(MCQUANT_ILASTIK.out.csv)
    }
}

workflow.onComplete {
	log.info ( workflow.success ? "\nDone!" : "Oops .. something went wrong" )
}
