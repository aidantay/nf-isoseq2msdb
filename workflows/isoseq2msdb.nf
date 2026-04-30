/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { PREPARE_GENOME         } from '../subworkflows/local/prepare_genome/main'
include { BAM_MERGE_INDEX        } from '../subworkflows/local/bam_merge_index/main'
include { BAM_VARIANTCALLING     } from '../subworkflows/local/bam_variantcalling/main'
include { CONSENSUS_TRANSCRIPTS  } from '../subworkflows/local/consensus_transcripts/main'
include { BED_TO_GTF             } from '../subworkflows/local/bed_to_gtf/main'
include { TRANSCRIPTS_TO_PROTEIN } from '../subworkflows/local/transcripts_to_protein/main'
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_isoseq2msdb_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow ISOSEQ2MSDB {

    take:
    ch_samplesheet          // channel: samplesheet read in from --input
    ch_variantcalling_input // channel: variantcalling_input read in from --variantcalling_input
    outdir

    main:
    ch_versions      = channel.empty()

    /*
    ================================================================================
                                    Prepare reference files
    ================================================================================
    */

    ch_fasta_raw      = params.fasta ? channel.fromPath(params.fasta).map { fasta -> [ [id:file(fasta).baseName], fasta ] }.collect() : channel.empty()
    ch_annotation_raw = params.gtf   ? channel.fromPath(params.gtf).map   { gtf -> [ [id:file(gtf).baseName], gtf ] }.collect() :
                        params.gff   ? channel.fromPath(params.gff).map   { gff -> [ [id:file(gff).baseName], gff ] }.collect() : channel.empty()

    PREPARE_GENOME ( ch_fasta_raw, ch_annotation_raw )

    ch_fasta      = PREPARE_GENOME.out.fasta
    ch_fai        = PREPARE_GENOME.out.fai
    ch_gzi        = PREPARE_GENOME.out.gzi
    ch_annotation = PREPARE_GENOME.out.annotation

    /*
    ================================================================================
                                    BAM concatenation and indexing
    ================================================================================
    */

    BAM_MERGE_INDEX (
        ch_samplesheet.map { meta, bams, beds -> [ meta, bams ] }
    )

    /*
    ================================================================================
                                    Variant calling
    ================================================================================
    */

    if (!params.variantcalling_input) {
        BAM_VARIANTCALLING (
            BAM_MERGE_INDEX.out.bam_bai,
            ch_fasta,
            ch_fai,
            ch_gzi
        )
        ch_vcf_tbi = BAM_VARIANTCALLING.out.vcf_tbi

    } else {
        ch_vcf_tbi = ch_variantcalling_input
    }

    /*
    ================================================================================
                                    Convert BED to GTF
    ================================================================================
    */

    BED_TO_GTF (
        ch_fasta.join(ch_fai),
        ch_annotation,
        ch_samplesheet.map { meta, bams, beds -> [ meta, beds ] }
    )

    /*
    ================================================================================
                                    Extract variant-aware transcript sequences
    ================================================================================
    */

    CONSENSUS_TRANSCRIPTS (
        ch_fasta.join(ch_fai),
        ch_vcf_tbi,
        BED_TO_GTF.out.transcript_annotation,
    )

    /*
    ================================================================================
                                    Translate transcripts into protein sequences
    ================================================================================
    */

    TRANSCRIPTS_TO_PROTEIN (
        CONSENSUS_TRANSCRIPTS.out.transcript_fasta
    )

    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'isoseq2msdb_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        )

    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
