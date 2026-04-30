process GSTAMA_CONVERT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gs-tama:1.0.3--hdfd78af_0' :
        'biocontainers/gs-tama:1.0.3--hdfd78af_0' }"

    input:
    tuple val(meta), path(bed)

    output:
    tuple val(meta), path("*.gtf")             , emit: gtf
    tuple val("${task.process}"), val('gstama'), eval("tama_merge.py -version | head -n1"), emit: versions_gstama, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    tama_convert_bed_gtf_ensembl_no_cds.py \\
        $bed \\
        ${prefix}.gtf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gstama: \$( tama_merge.py -version | head -n1 )
    END_VERSIONS
    """
}