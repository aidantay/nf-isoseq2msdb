//
// MERGE INDEX BAM
//

include { SAMTOOLS_INDEX as INDEX_MERGE_BAM } from '../../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_MERGE as MERGE_BAM       } from '../../../modules/nf-core/samtools/merge/main'

workflow BAM_MERGE_INDEX {

    take:
    bam // channel: [mandatory] meta, bam

    main:
    // Figuring out if there is one or more bam(s) from the same sample
    bam_to_merge = bam.branch{ meta, bam_ ->
        // bam is a list, so use bam.size() to asses number of intervals
        single:   bam_.size() <= 1
            return [ meta, bam_[0] ]
        multiple: bam_.size() > 1
    }

    // Only when using intervals
    MERGE_BAM ( bam_to_merge.multiple.map{ meta, bams -> [meta, bams, []] }, [ [:], [], [], [] ] )

    // Mix intervals and no_intervals channels together
    bam_all = MERGE_BAM.out.bam.mix(bam_to_merge.single)

    // Index bam
    INDEX_MERGE_BAM ( bam_all )

    // Join with the bai file
    bam_bai = bam_all
        .join(INDEX_MERGE_BAM.out.index, failOnDuplicate: true, failOnMismatch: true)

    emit:
    bam_bai  = bam_bai // channel: [meta, bam, bai]
}
