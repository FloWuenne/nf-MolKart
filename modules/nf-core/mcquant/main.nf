process MCQUANT {
    tag "$meta.id"
    label 'process_single'

    // WARN: Version information not provided by tool on CLI. Please update version string below when bumping container versions.
    container "labsyspharm/quantification:1.5.4"

    input:
    tuple val(meta), path(image)
    tuple val(meta2), path(mask)
    tuple val(meta3), path(markerfile)

    output:
    tuple val(meta), path("*.mcquant_fix.csv"), emit: csv
    tuple val(meta3), path(markerfile), emit : ex_cols
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '1.5.4' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    python /app/CommandSingleCellExtraction.py \
        --masks $mask \
        --image $image \
        --channel_names $markerfile \
        --output . \
        $args

    mapfile row_names < $markerfile
    header_line=\$(head -n 1 ${image.baseName}_${mask.baseName}.csv)
    column_indices=\$(echo "\${header_line}" | awk -v names="\${row_names[*]}" 'BEGIN{FS=",";OFS=","; split(names, nameArr, " ")} {for (i=1; i<=NF; i++) {exclude=0; for (name in nameArr) if (\$i == nameArr[name]) {exclude=1; break;} if (exclude == 0) printf "%d,", i}}')
    column_indices="\${column_indices%,}"
    cut -d',' -f"\${column_indices}" ${image.baseName}_${mask.baseName}.csv > ${prefix}.mcquant_fix.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mcquant: $VERSION
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = '1.5.4'
    """
    touch ${prefix}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        mcquant: $VERSION
    END_VERSIONS
    """
}
