process PIGEON_PREPARE {
    tag "$input"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'quay.io/biocontainers/pbpigeon:1.4.0--h9948957_0' :
        'quay.io/biocontainers/pbpigeon:1.4.0--h9948957_0' }"

    input:
    path input
    path fasta

    output:
    path "*.sorted.*", emit: prepared
    tuple val("${task.process}"), val('pigeon'), eval("pigeon --version | sed 's/pigeon //'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def fasta_arg = fasta ? "$fasta" : ""
    """
    pigeon prepare $input $fasta_arg
    """

    stub:
    def suffix = input.getExtension()
    """
    touch ${input.baseName}.sorted.${suffix}
    touch ${input.baseName}.sorted.${suffix}.index
    """
}
