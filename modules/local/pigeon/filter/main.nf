process PIGEON_FILTER {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'quay.io/biocontainers/pbpigeon:1.4.0--h9948957_0' :
        'quay.io/biocontainers/pbpigeon:1.4.0--h9948957_0' }"

    input:
    tuple val(meta), path(classification)
    path gff

    output:
    tuple val(meta), path("*_filtered_classification.txt"), emit: classification
    tuple val(meta), path("*_filtered.gff")               , emit: gff
    tuple val("${task.process}"), val('pigeon'), eval("pigeon --version | sed 's/pigeon //'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    pigeon filter \\
        $classification \\
        --isoforms $gff \\
        $args
    """

    stub:
    def prefix = classification.baseName
    """
    touch ${prefix}_filtered_classification.txt
    touch ${prefix}_filtered.gff
    """
}
