process SQANTI3_PROTEIN {
    tag "${meta.id}"
    label 'process_medium'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'gsheynkmanlab/sqanti_protein:sing' :
    'gsheynkmanlab/sqanti_protein:sing' }"

    input:
    tuple val(meta), path(classification), path(gtf)
    tuple val(meta2), path(fasta), path(fai)

    output:
    tuple val(meta), path("*.cds.gff3")               , emit: gff3
    tuple val(meta), path("*.protein_classification.txt"), emit: classification
    tuple val(meta), path("*.faa")                    , emit: faa
    tuple val("${task.process}"), val('sqanti3'), eval("sqanti3_qc.py --version | sed 's/sqanti3_qc.py //'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    sqanti3_protein.py \\
        ${classification} \\
        ${gtf} \\
        ${fasta} \\
        -o ${prefix} \\
        -d . \\
        --cpus ${task.cpus} \\
        ${args}
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.cds.gff3
    touch ${prefix}.protein_classification.txt
    touch ${prefix}.faa
    """
}
