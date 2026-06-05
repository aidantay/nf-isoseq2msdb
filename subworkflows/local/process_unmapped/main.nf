//
// PROCESS UNMAPPED READS
//

include { SAMTOOLS_VIEW          } from '../../../modules/nf-core/samtools/view/main'
include { ISOSEQ3_CLUSTER        } from '../../../modules/local/isoseq3/cluster/main'
include { SAMTOOLS_FASTA         } from '../../../modules/nf-core/samtools/fasta/main'
include { FIND_CONCATENATE       } from '../../../modules/nf-core/find/concatenate/main'
include { GUNZIP                 } from '../../../modules/nf-core/gunzip/main'
include { TRANSCRIPTS_TO_PROTEIN } from '../transcripts_to_protein/main'

workflow PROCESS_UNMAPPED {

    take:
    bam_bai // channel: [mandatory] meta, bam, bai

    main:
    // Extract unmapped reads
    SAMTOOLS_VIEW ( bam_bai, [[:], [], []], [[:], []], [[:], []], [] )

    // Cluster unmapped reads
    ISOSEQ3_CLUSTER ( SAMTOOLS_VIEW.out.bam )

    // Convert BAM to FASTA
    ch_samtools_fasta_input = ISOSEQ3_CLUSTER.out.bam.map { meta, bam ->
        def new_meta = meta + [single_end: true]
        [ new_meta, bam ]
    }
    SAMTOOLS_FASTA ( ch_samtools_fasta_input, false )

    // Mix outputs (fasta, other, singleton) and group by meta
    ch_samtools_fasta_output = SAMTOOLS_FASTA.out.fasta
        .mix(SAMTOOLS_FASTA.out.other, SAMTOOLS_FASTA.out.singleton)
        .groupTuple()
        .map { meta, files -> [ meta, files.flatten() ] }

    // Concat outputs into a single .gz file
    FIND_CONCATENATE ( ch_samtools_fasta_output )

    // Unzip FASTA
    GUNZIP ( FIND_CONCATENATE.out.file_out )

    // Translate transcripts into protein sequences
    TRANSCRIPTS_TO_PROTEIN ( GUNZIP.out.gunzip )

    emit:
    fasta     = GUNZIP.out.gunzip              // channel: [meta, fasta]
    pep       = TRANSCRIPTS_TO_PROTEIN.out.pep // channel: [meta, pep]
    gff3      = TRANSCRIPTS_TO_PROTEIN.out.gff3// channel: [meta, gff3]
    cds       = TRANSCRIPTS_TO_PROTEIN.out.cds // channel: [meta, cds]
    bed       = TRANSCRIPTS_TO_PROTEIN.out.bed // channel: [meta, bed]
}
