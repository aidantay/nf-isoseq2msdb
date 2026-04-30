//
// CREATE CONSENSUS AND EXTRACT TRANSCRIPTS
//

include { BCFTOOLS_CONSENSUS             } from '../../../modules/nf-core/bcftools/consensus/main'
include { SAMTOOLS_FAIDX                 } from '../../../modules/nf-core/samtools/faidx/main'
include { BED_TO_GTF                     } from '../bed_to_gtf/main'
include { GFFREAD as GFFREAD_TRANSCRIPTS } from '../../../modules/nf-core/gffread/main'
include { SEQKIT_GREP                    } from '../../../modules/nf-core/seqkit/grep/main'
include { SEQKIT_RMDUP                   } from '../../../modules/nf-core/seqkit/rmdup/main'
include { SEQKIT_HEAD                    } from '../../../modules/nf-core/seqkit/head/main'

workflow CONSENSUS_TRANSCRIPTS {

    take:
    fasta_fai  // channel: [ val(meta), path(fasta), path(fai) ]
    vcf_tbi    // channel: [ val(meta), path(vcf), path(tbi) ]
    gtf_gff    // channel: [ val(meta), path(gtf/gff) ]

    main:
    //
    // MODULE: Create and index consensus genome
    //
    ch_bcftools_consensus_input = vcf_tbi
            .combine(fasta_fai.map { meta, fasta, fai -> fasta }.first())
            .map { meta, vcf, tbi, fasta -> [ meta, vcf, tbi ?: [], fasta, [] ] }
    BCFTOOLS_CONSENSUS (
        ch_bcftools_consensus_input
    )
    SAMTOOLS_FAIDX (
        BCFTOOLS_CONSENSUS.out.fasta.map { meta, fasta -> [ meta, fasta, [] ] },
        false
    )

    // Join gtf/gff + Consensus Fasta
    ch_gtfgff_fasta = gtf_gff
        .map { meta, gtf_gff_file -> [ meta.id, meta, gtf_gff_file ] }
        .join(BCFTOOLS_CONSENSUS.out.fasta.map { meta, fasta -> [ meta.id, meta, fasta ] })
        .map { id, meta_gtfgff, gtf_gff_file, meta_fasta, fasta_file -> [ meta_gtfgff + meta_fasta, gtf_gff_file, fasta_file ] }

    //
    // MODULE: Extract transcript sequences using gffread
    //
    GFFREAD_TRANSCRIPTS (
        ch_gtfgff_fasta.map { meta, gtf_gff_file, fasta_file -> [ meta, gtf_gff_file ] },
        ch_gtfgff_fasta.map { meta, gtf_gff_file, fasta_file -> fasta_file }
    )
    ch_gffread_fasta = GFFREAD_TRANSCRIPTS.out.gffread_fasta

    //
    // MODULE: Filter transcript sequences using seqkit
    // * Remove duplicate transcripts
    // * Remove sequences containing N's
    // * Limit the number of transcripts (for testing purposes)
    //
    SEQKIT_RMDUP (
        ch_gffread_fasta
    )

    SEQKIT_GREP (
        SEQKIT_RMDUP.out.fastx,
        []
    )

    ch_transcripts = SEQKIT_GREP.out.filter
    if (!params.skip_transcripts_subset) {
        ch_seqkit_head_input = SEQKIT_GREP.out.filter
            .map { meta, fasta -> [ meta, fasta, params.transcripts_head_count ] }

        SEQKIT_HEAD (
            ch_seqkit_head_input
        )
        ch_transcripts = SEQKIT_HEAD.out.subset
    }

    emit:
    consensus_fasta  = BCFTOOLS_CONSENSUS.out.fasta // channel: [ val(meta), path(fasta) ]
    consensus_fai    = SAMTOOLS_FAIDX.out.fai       // channel: [ val(meta), path(fai) ]
    transcript_fasta = ch_transcripts               // channel: [ val(meta), path(fasta) ]
}
