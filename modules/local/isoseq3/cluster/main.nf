process ISOSEQ3_CLUSTER {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'quay.io/biocontainers/isoseq3:4.0.0--h9ee0642_0' :
        'quay.io/biocontainers/isoseq3:4.0.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.bam"), emit: bam
    tuple val("${task.process}"), val('isoseq3'), eval("isoseq3 --version | sed 's/isoseq3 //; s/isoseq //'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.clustered"
    """
    isoseq3 \\
        cluster \\
        -j ${task.cpus} \\
        $args \\
        $bam \\
        ${prefix}.bam
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}.clustered"
    """
    touch ${prefix}.bam
    """
}
