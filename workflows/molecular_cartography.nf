/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def valid_params = [
    segmentation        : ['mesmer_dapi', 'mesmer_wholecell', 'cellpose', 'ilastik_multicut'],
]

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()

// MODULE: Installed directly from nf-core/modules
include { MINDAGAP_MINDAGAP } from '../modules/nf-core/mindagap/mindagap/main'
include { ILASTIK_PIXELCLASSIFICATION } from '../modules/nf-core/ilastik/pixelclassification/main'
include { ILASTIK_MULTICUT } from '../modules/nf-core/ilastik/multicut/main'
include { DEEPCELL_MESMER as DEEPCELL_MESMER_NUCLEAR  } from '../modules/nf-core/deepcell/mesmer/main'
include { DEEPCELL_MESMER as DEEPCELL_MESMER_WHOLECELL } from '../modules/nf-core/deepcell/mesmer/main'
include { CELLPOSE } from '../modules/nf-core/cellpose/main'
include { MCQUANT as MCQUANT_ILASTIK } from '../modules/nf-core/mcquant/main'
include { MCQUANT as MCQUANT_MESMER_NUCLEAR } from '../modules/nf-core/mcquant/main'
include { MCQUANT as MCQUANT_MESMER_WHOLECELL } from '../modules/nf-core/mcquant/main'
include { MCQUANT as MCQUANT_CELLPOSE } from '../modules/nf-core/mcquant/main'
include { SCIMAP_MCMICRO as SCIMAP_MCMICRO_MESMER_NUCLEAR } from '../modules/nf-core/scimap/mcmicro/main'
include { SCIMAP_MCMICRO as SCIMAP_MCMICRO_MESMER_WHOLECELL } from '../modules/nf-core/scimap/mcmicro/main'
include { SCIMAP_MCMICRO as SCIMAP_MCMICRO_CELLPOSE } from '../modules/nf-core/scimap/mcmicro/main'
include { SCIMAP_MCMICRO as SCIMAP_MCMICRO_ILASTIK } from '../modules/nf-core/scimap/mcmicro/main'
include { MULTIQC } from '../modules/nf-core/multiqc/main'

/* local modules */
include { MINDAGAP_DUPLICATEFINDER } from '../modules/local/mindagap/duplicatefinder'

/* custom processes */
include { PROJECT_SPOTS; MKIMG_STACKS; MK_ILASTIK_TRAINING_STACKS; TIFF_TO_H5; APPLY_CLAHE_DASK; CREATE_TIFF_TRAINING;  } from '../nf_processes.nf'
include {MOLCART_QC as MOLCART_QC_MESMER_NUCLEAR} from '../nf_processes.nf'
include {MOLCART_QC as MOLCART_QC_MESMER_WHOLECELL} from '../nf_processes.nf'
include {MOLCART_QC as MOLCART_QC_CELLPOSE} from '../nf_processes.nf'
include {MOLCART_QC as MOLCART_QC_ILASTIK} from '../nf_processes.nf'
include {FILTER_MASK as FILTER_MASK_MESMER_NUCLEAR} from '../nf_processes.nf'
include {FILTER_MASK as FILTER_MASK_MESMER_WHOLECELL} from '../nf_processes.nf'
include {FILTER_MASK as FILTER_MASK_CELLPOSE} from '../nf_processes.nf'
include {FILTER_MASK as FILTER_MASK_ILASTIK} from '../nf_processes.nf'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUT
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

workflow MOLECULAR_CARTOGRAPHY{

    // Read in sample sheet and create channels for images and spots
    samples = Channel.fromPath(ch_input)
        .splitCsv(header: true, strip : true)
        .branch{
            meta ->
                images : meta.type == "image"
                    return tuple(meta, meta.filename)
                spots : meta.type == "spot_table"
                    return tuple(meta, meta.filename)
        }

    // Use Mindagap to fill gridlines in Molecular Cartography images and create a list of tuples with image id and path to filled images
    MINDAGAP_MINDAGAP(samples.images, params.mindagap_boxsize, params.mindagap_loopnum)

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

    //////////////////////////////////////////
    // Check if Ilastik training images should be created or training applied to the full image stacks
    if (params.create_training_set) {  
    
    // Create training stacks for ilastik pixel classification
    nr_chan = img2stack
        .map{meta, tiffs -> tiffs.size()}

    // Create subsets of the image for training an ilastik model
    MK_ILASTIK_TRAINING_STACKS(
        APPLY_CLAHE_DASK.out.img_clahe,
        tuple(params.crop_size_x,params.crop_size_y),
        params.nonzero_fraction,
        params.crop_amount,
        nr_chan, 
        params.channel_ids)

    // Combine CLAHE corrected image with crop_summary for making the same training tiff stacks as ilastik
    tiff_crop = APPLY_CLAHE_DASK.out.img_clahe
    .join(MK_ILASTIK_TRAINING_STACKS.out.crop_summary)

    // Create tiff training sets for the same regions as ilastik for Cellpose training
    CREATE_TIFF_TRAINING(
        tiff_crop.map(it -> tuple(it[0],it[1])),
        tiff_crop.map(it -> tuple(it[0],it[2])),
        )
    //////////////////////////////////////////

    }else{
    // Mark duplicate spots from Molecular Cartography data
    MINDAGAP_DUPLICATEFINDER(samples.spots.map(it -> tuple(it[0],it[1])))
    
    image_id = samples.images
        .map{meta,image -> tuple(meta.id,image)}

    // Join Duplicatefinder output with samples.spots DAPI image for image size in projecting spots
    dedup_spots = MINDAGAP_DUPLICATEFINDER.out.marked_dups_spots
        .map{
            meta,spots -> tuple(meta.id,spots)}
        .join(image_id)

    // Prepare spot table for QC
    qc_spots = dedup_spots.map(it -> tuple([id: it[0]],it[1]))

    // Project spots from Molecular Cartography data to 2d numpy arrays for quantification
    PROJECT_SPOTS(
        dedup_spots.map(it -> tuple(it[0],it[1])),
        dedup_spots.map(it -> it[2])
    )

    if (!params.skip_mesmer_nuclear){
        // // Mesmer whole-cell segmentation
        DEEPCELL_MESMER_NUCLEAR(img2stack.map(it -> tuple(it[0],it[1][0])),
                        [[:],[]])

        // Size filter the cell mask from Cellpose
        FILTER_MASK_MESMER_NUCLEAR(DEEPCELL_MESMER_NUCLEAR.out.mask, 0, 50000)

        mesmer_mask_nuc_filt = FILTER_MASK_MESMER_NUCLEAR.out.filt_mask
            .map{meta,tiff -> [meta.id,tiff]}

        mcquant_mesmer_nuc_in = PROJECT_SPOTS.out.img_spots
            .join(PROJECT_SPOTS.out.channel_names)
            .map{
                meta,tiff,channels -> [meta,tiff,channels]}
            .join(mesmer_mask_nuc_filt)

        // // Quantify spot counts over masks
        MCQUANT_MESMER_NUCLEAR(mcquant_mesmer_nuc_in.map{it -> tuple([id:it[0]],it[1])},
                mcquant_mesmer_nuc_in.map{it -> tuple([id:it[0]],it[3])},
                mcquant_mesmer_nuc_in.map{it -> tuple([id:it[0]],it[2])}
                )

        qc_in_mesmer = MCQUANT_MESMER_NUCLEAR.out.csv
            .join(qc_spots)

        MOLCART_QC_MESMER_NUCLEAR(
            qc_in_mesmer.map{meta,mcquant,spots -> tuple(meta,mcquant)},
            qc_in_mesmer.map{meta,mcquant,spots -> tuple(meta,spots)},
            "mesmer_nuclear"
        )
                
        // Create Scimap object
        // SCIMAP_MCMICRO_MESMER_NUCLEAR(MCQUANT_MESMER_NUCLEAR.out.csv)
    }

    if (!params.skip_mesmer_wholecell){
        // // Mesmer whole-cell segmentation
        DEEPCELL_MESMER_WHOLECELL(img2stack.map(it -> tuple(it[0],it[1][0])),
                        img2stack.map(it -> tuple(it[0],it[1][1])))

        // Size filter the cell mask from Cellpose
        FILTER_MASK_MESMER_WHOLECELL(DEEPCELL_MESMER_WHOLECELL.out.mask, params.mask_min_area, params.mask_max_area)

        mesmer_mask_filt = FILTER_MASK_MESMER_WHOLECELL.out.filt_mask
            .map{meta,tiff -> [meta.id,tiff]}

        mcquant_mesmer_in = PROJECT_SPOTS.out.img_spots
            .join(PROJECT_SPOTS.out.channel_names)
            .map{
                meta,tiff,channels -> [meta,tiff,channels]}
            .join(mesmer_mask_filt)

        // // Quantify spot counts over masks
        MCQUANT_MESMER_WHOLECELL(mcquant_mesmer_in.map{it -> tuple([id:it[0]],it[1])},
                mcquant_mesmer_in.map{it -> tuple([id:it[0]],it[3])},
                mcquant_mesmer_in.map{it -> tuple([id:it[0]],it[2])}
                )

        qc_in_mesmer = MCQUANT_MESMER_WHOLECELL.out.csv
            .join(qc_spots)

        MOLCART_QC_MESMER_WHOLECELL(
            qc_in_mesmer.map{meta,mcquant,spots -> tuple(meta,mcquant)},
            qc_in_mesmer.map{meta,mcquant,spots -> tuple(meta,spots)},
            "mesmer_wholecell"
        )
                
        // Create Scimap object
        // SCIMAP_MCMICRO_MESMER_WHOLECELL(MCQUANT_MESMER_WHOLECELL.out.csv)
    }

    if (!params.skip_cellpose){

         // Cellpose segmentation and quantification
        CELLPOSE(APPLY_CLAHE_DASK.out.img_clahe,
                params.cellpose_model)

        // Size filter the cell mask from Cellpose
        FILTER_MASK_CELLPOSE(CELLPOSE.out.mask, params.mask_min_area, params.mask_max_area)
        
        cellpose_mask_filt = FILTER_MASK_CELLPOSE.out.filt_mask
                .map{
                meta,tiff -> [meta.id,tiff]}

        mcquant_cellpose_in = PROJECT_SPOTS.out.img_spots
            .join(PROJECT_SPOTS.out.channel_names)
            .map{
                meta,tiff,channels -> [meta,tiff,channels]}
            .join(cellpose_mask_filt)

        // Quantify spot counts over masks
        MCQUANT_CELLPOSE(mcquant_cellpose_in.map{it -> tuple([id:it[0]],it[1])},
                mcquant_cellpose_in.map{it -> tuple([id:it[0]],it[3])},
                mcquant_cellpose_in.map{it -> tuple([id:it[0]],it[2])})

        qc_in_cellpose = MCQUANT_CELLPOSE.out.csv
            .join(qc_spots)

        MOLCART_QC_CELLPOSE(
            qc_in_cellpose.map{meta,mcquant,spots -> tuple(meta,mcquant)},
            qc_in_cellpose.map{meta,mcquant,spots -> tuple(meta,spots)},
            "cellpose"
        )

        // Create Scimap object
        // SCIMAP_MCMICRO_CELLPOSE(MCQUANT_CELLPOSE.out.csv)
    }

    if (!params.skip_ilastik){
            // Convert tiff stack to h5
            TIFF_TO_H5(
                APPLY_CLAHE_DASK.out.img_clahe,
                params.channel_ids)

            // Run ilastik pixel classification on image stacks
            ILASTIK_PIXELCLASSIFICATION(
                TIFF_TO_H5.out.hdf5,
                tuple([id:"ilastik pixel classification"],params.ilastik_pixelprob_model),
                )

            ilastik_multicut_in = TIFF_TO_H5.out.hdf5.map{meta,h5 -> [meta.id,h5]}
                .join(ILASTIK_PIXELCLASSIFICATION.out.output.map{meta,pixelprob -> [meta.id,pixelprob]})

            // Run ilastik multicut on boundery information from probability maps created in previous step
            ILASTIK_MULTICUT(
                ilastik_multicut_in.map{it -> tuple([id:it[0]],it[1])},
                tuple([id:"ilastik multicut"],params.ilastik_multicut_model),
                ilastik_multicut_in.map{it -> tuple([id:it[0]],it[2])}
                )

            // FILTER_MASK_ILASTIK(ILASTIK_MULTICUT.out.out_tiff)
            FILTER_MASK_ILASTIK(ILASTIK_MULTICUT.out.out_tiff, params.mask_min_area, params.mask_max_area)

            ilastik_mask_filt = FILTER_MASK_ILASTIK.out.filt_mask
                .map{
                meta,tiff -> [meta.id,tiff]}

            mcquant_ilastik_in = PROJECT_SPOTS.out.img_spots
                .join(PROJECT_SPOTS.out.channel_names)
                .map{meta,tiff,channels -> [meta,tiff,channels]}
                .join(ilastik_mask_filt)

            // Quantify spot counts over masks
            MCQUANT_ILASTIK(mcquant_ilastik_in.map{it -> tuple([id:it[0]],it[1])},
                mcquant_ilastik_in.map{it -> tuple([id:it[0]],it[3])},
                mcquant_ilastik_in.map{it -> tuple([id:it[0]],it[2])}
                    )

            qc_in_ilastik = MCQUANT_ILASTIK.out.csv
                .join(qc_spots)

            MOLCART_QC_ILASTIK(
                qc_in_ilastik.map{meta,mcquant,spots -> tuple(meta,mcquant)},
                qc_in_ilastik.map{meta,mcquant,spots -> tuple(meta,spots)},
                "ilastik_multicut"
            )
            
            // Create Scimap object
            // SCIMAP_MCMICRO_ILASTIK(MCQUANT_ILASTIK.out.csv)
        }


    /// Collect Quality metrics
    if (!params.skip_multiqc) {
    qc_final = MOLCART_QC_MESMER_NUCLEAR.out.qc
        .concat(MOLCART_QC_MESMER_WHOLECELL.out.qc,MOLCART_QC_CELLPOSE.out.qc,MOLCART_QC_ILASTIK.out.qc)
        .collectFile(name: 'final_QC.all_samples.csv',keepHeader: true, storeDir: "$params.outdir" )

    MULTIQC (
        qc_final,
        ch_multiqc_config.ifEmpty([]),
        ch_multiqc_custom_config.ifEmpty([]),
        ch_multiqc_logo.collect().ifEmpty([])
        )
        }
    }
}

workflow.onComplete {
	log.info ( workflow.success ? "\nDone!" : "Oops .. something went wrong" )
}
