//
// VARIANT CALLING FROM BAM
//

include { CLAIR3                     } from '../../../modules/nf-core/clair3/main'
include { DEEPVARIANT_RUNDEEPVARIANT } from '../../../modules/nf-core/deepvariant/rundeepvariant/main'
include { BCFTOOLS_FILTER            } from '../../../modules/nf-core/bcftools/filter/main'

workflow BAM_VARIANTCALLING {

    take:
    bam_bai // channel: [ val(meta), path(bam), path(bai) ]
    fasta   // channel: [ val(meta), path(fasta) ]
    fai     // channel: [ val(meta), path(fai) ]
    gzi     // channel: [ val(meta), path(gzi) ]

    main:
    //
    // MODULE: Run Clair3
    //
    ch_clair3_input = bam_bai
        .map { meta, bam, bai ->
            [ meta, bam, bai,
                params.clair3_variant_model ?: [],
                params.clair3_user_variant_model ? file(params.clair3_user_variant_model) : [],
                params.clair3_platform
            ]
        }
    CLAIR3 (
        ch_clair3_input,
        fasta.first(),
        fai.first()
    )
    ch_clair3_vcf_tbi = CLAIR3.out.vcf
        .join(CLAIR3.out.tbi, remainder: true)
        .map { meta, vcf, tbi -> [ meta + [variant_caller: "Clair3"], vcf, tbi ] }

    //
    // MODULE: Run DeepVariant
    //
    ch_deepvariant_vcf_tbi = Channel.empty()
    if (!params.skip_deepvariant) {
        ch_deepvariant_input = bam_bai
            .map { meta, bam, bai -> [ meta, bam, bai, [], params.deepvariant_model ] }

        DEEPVARIANT_RUNDEEPVARIANT (
            ch_deepvariant_input,
            fasta.first(),
            fai.first(),
            gzi.mix(channel.value([[:], []])).first(),
            [ [:], [] ]
        )
        ch_deepvariant_vcf_tbi = DEEPVARIANT_RUNDEEPVARIANT.out.vcf
            .join(DEEPVARIANT_RUNDEEPVARIANT.out.vcf_index, remainder: true)
            .map { meta, vcf, tbi -> [ meta + [variant_caller: "DeepVariant"], vcf, tbi ] }
    }

    // Combine results
    ch_vcf_tbi = ch_clair3_vcf_tbi
        .mix(ch_deepvariant_vcf_tbi)

    //
    // MODULE: Filter VCFs using bcftools
    //
    BCFTOOLS_FILTER (
        ch_vcf_tbi
    )
    ch_vcf_filtered_tbi = BCFTOOLS_FILTER.out.vcf
        .join(BCFTOOLS_FILTER.out.tbi, remainder: true)

    emit:
    vcf_tbi  = ch_vcf_filtered_tbi // channel: [meta, vcf, tbi]
}
