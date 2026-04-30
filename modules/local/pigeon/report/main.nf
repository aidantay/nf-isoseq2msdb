process PIGEON_REPORT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'quay.io/biocontainers/pbpigeon:1.4.0--h9948957_0' :
        'quay.io/biocontainers/pbpigeon:1.4.0--h9948957_0' }"

    input:
    tuple val(meta), path(classification)

    output:
    tuple val(meta), path("*.pdf"), emit: report
    tuple val("${task.process}"), val('pigeon'), eval("pigeon --version | sed 's/pigeon //'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    pigeon report \\
        $classification \\
        ${prefix}_pigeon_report.pdf \\
        $args
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_pigeon_report.pdf
    """
}
