process PIGEON_CLASSIFY {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'quay.io/biocontainers/pbpigeon:1.4.0--h9948957_0' :
        'quay.io/biocontainers/pbpigeon:1.4.0--h9948957_0' }"

    input:
    tuple val(meta), path(gff)
    path fasta
    path gtf
    path flnc
    path cage_bed
    path polya_list

    output:
    tuple val(meta), path("*.classification.txt"), emit: classification
    tuple val(meta), path("*.junctions.txt")     , emit: junctions
    tuple val("${task.process}"), val('pigeon'), eval("pigeon --version | sed 's/pigeon //'"), emit: versions, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def flnc_arg = flnc ? "--flnc $flnc" : ""
    def cage_arg = cage_bed ? "--cage-peak $cage_bed" : ""
    def polya_arg = polya_list ? "--poly-a $polya_list" : ""
    """
    # Pigeon requires sorted and indexed GFF/GTF
    # We create copies to ensure we don't try to write to a read-only input or shared reference
    cp $gff input.gff
    cp $gtf reference.gtf

    pigeon prepare input.gff
    pigeon prepare reference.gtf $fasta

    pigeon classify \\
        input.sorted.gff \\
        reference.sorted.gtf \\
        $fasta \\
        --out-dir . \\
        --out-prefix $prefix \\
        $flnc_arg \\
        $cage_arg \\
        $polya_arg \\
        $args
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.classification.txt
    touch ${prefix}.junctions.txt
    """
}
