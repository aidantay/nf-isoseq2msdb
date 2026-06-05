process ISOSEQ3_COLLAPSE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'quay.io/biocontainers/isoseq3:4.0.0--h9ee0642_0' :
        'quay.io/biocontainers/isoseq3:4.0.0--h9ee0642_0' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.gff")          , emit: gff
    tuple val(meta), path("*.abundance.txt"), emit: abundance
    tuple val(meta), path("*.fasta")        , emit: fasta
    tuple val(meta), path("*.read_stat.txt"), emit: read_stat
    tuple val(meta), path("*.group.txt")    , emit: group
    tuple val(meta), path("*.report.json")  , emit: report
    tuple val("${task.process}"), val('isoseq3'), eval("isoseq3 --version | sed 's/isoseq3 //; s/isoseq //'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}.collapsed"
    """
    isoseq3 \\
        collapse \\
        $args \\
        $bam \\
        ${prefix}.gff
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}.collapsed"
    """
    touch ${prefix}.gff
    touch ${prefix}.abundance.txt
    touch ${prefix}.fasta
    touch ${prefix}.read_stat.txt
    touch ${prefix}.group.txt
    touch ${prefix}.report.json
    """
}
