process FILTER_MASK{
    debug true
    tag "Filtering mask $meta.id"

    container 'kbestak/tiff_to_hdf5:v0.0.2'
    
    input:
    tuple val(meta), path(mask_image)
    val(mask_min_area)
    val(mask_max_area)

    output:
    tuple val(meta), path("retained_masks.tiff") , emit: filt_mask
    tuple val(meta), path("discarded_masks.tiff")

    script:
    """
    filter_segmasks.py --image ${mask_image} --min_area ${mask_min_area} --max_area ${mask_max_area}
    """
}

process PROJECT_SPOTS{
    debug false
    tag "Projecting spots $meta"

    container 'wuennemannflorian/project_spots:latest'

    input: 
    tuple val(meta), path(spots)
    path(img)

    output:
    tuple val(meta), path("${spots.baseName}.tiff"), emit: img_spots
    tuple val(meta), path("${spots.baseName}.channel_names.csv"), emit: channel_names

    script:
    """
    project_spots.dask.py \
    --input ${spots} \
    --sample_id ${spots.baseName} \
    --img_dims $img
    """
}

process APPLY_CLAHE{
    debug true
    tag "Applying CLAHE to $meta.id"

    container 'ghcr.io/schapirolabor/background_subtraction:v0.3.3'

    input: 
    tuple val(meta), path(image)

    output:
    tuple val(meta), path("*.clahe.tiff") , emit: img_clahe

    script:
    """
    apply_clahe.py \
    --raw ${image} \
    --output ${image.baseName}.clahe.tiff \
    --clip_limit 0.02 \
    --kernel_size 50 \
    --nbins 256
    """

}

process APPLY_CLAHE_DASK{
    debug false
    tag "Applying CLAHE to $meta.id"

    container 'ghcr.io/schapirolabor/background_subtraction:v0.3.3'

    input: 
    tuple val(meta), path(image)

    output:
    tuple val(meta), path("*.clahe.tiff") , emit: img_clahe

    script:
    """
    apply_clahe.dask.py \
    --raw ${image} \
    --output ${image.baseName}.clahe.tiff \
    --cliplimit 0.01 \
    --kernel 25 \
    --nbins 256 \
    --channel 1 \
    --pixel-size 0.138
    """

}

process TIFF_TO_H5{
    container 'labsyspharm/mcmicro-ilastik:1.6.1'

    input:
    tuple val(meta), path(image_stack)
    val(channel_ids)

    output:
    tuple val(meta), path("${meta.id}.stack.*.hdf5"), emit: hdf5

    script:
    """
    python /app/CommandIlastikPrepOME.py \
    --input $image_stack \
    --output . \
    --channelIDs $channel_ids
    """
}

process CREATE_TIFF_TRAINING{
    container 'labsyspharm/mcmicro-ilastik:1.6.1'

    publishDir params.tiff_training_dir, mode:"copy", pattern:"*crop*.tiff"
    publishDir params.crop_overview_dir, mode:"copy", pattern:"*crop_overview.png"

    input:
    tuple val(meta), path(image_stack)
    tuple val(meta), path(crop_summary)

    output:
    tuple val(meta), path("*crop*.tiff"), emit: crop_tiff
    tuple val(meta), path("*crop_overview.png")

    script:
    """
    crop_tiff.py --input $image_stack --crop_summary $crop_summary
    """
}

process MKIMG_STACKS{
    
    container 'kbestak/tiff_to_hdf5:v0.0.2'
    
    input:
    tuple val(meta), path(stacks)

    output:
    tuple val(meta), path("${meta.id}.stack.tiff") , emit: mcimage

    script:
    """
    make_img_stacks.py --input ${stacks} --output ./${meta.id}.stack.tiff
    """
}

// Process to extract sub stacks for training ilastik pixel classification
process MK_ILASTIK_TRAINING_STACKS{
    container 'labsyspharm/mcmicro-ilastik:1.6.1'
    
    publishDir params.ilastik_training_dir, mode:"copy", pattern:"*crop*.hdf5"
    publishDir params.crop_sum_dir, mode:"copy", pattern:"*_CropSummary.txt"

    input:
    tuple val(meta)         , path(image_stack)
    tuple val(crop_size_x)  , val(crop_size_y)
    val   nonzero_fraction
    val   crop_amount
    val   num_channels
    val   channel_ids

    output:
    tuple val(meta), path("*crop*.hdf5")        , emit: ilastik_training
    tuple val(meta), path("*_CropSummary.txt")  , emit: crop_summary

    script:
    """
    python /app/CommandIlastikPrepOME.py \
        --input $image_stack \
        --output . \
        --crop \
        --nuclei_index 1 \
        --crop_size $crop_size_x $crop_size_y \
        --nonzero_fraction $nonzero_fraction \
        --crop_amount $crop_amount \
        --num_channels $num_channels \
        --channelIDs $channel_ids
    """
}

// Process to generate QC measures for NF_MOLCART
process MOLCART_QC{
    container 'wuennemannflorian/project_spots:latest'

    input:
    tuple val(meta), path(mcquant)
    tuple val(meta), path(spot_table)
    val(segmethod)

    output:
    path("${meta.id}.${segmethod}.spot_QC.csv"), emit: qc

    script:
    def sample_id = "${meta.id}"
    """
    collect_QC.py \
    --mcquant $mcquant \
    --spots $spot_table \
    --sample_id $sample_id \
    --segmentation_method $segmethod \
    --outdir .
    """
}