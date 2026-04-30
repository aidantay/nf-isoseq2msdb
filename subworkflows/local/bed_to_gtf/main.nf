//
// CONVERT BED TO GTF/GFF AND COMPARE
//

include { GSTAMA_CONVERT         } from '../../../modules/local/gstama/convert/main'
include { GFFREAD as GFFREAD_GFF } from '../../../modules/nf-core/gffread/main'
include { GFFREAD as GFFREAD_GTF } from '../../../modules/nf-core/gffread/main'
include { GFFCOMPARE             } from '../../../modules/nf-core/gffcompare/main'

workflow BED_TO_GTF {

    take:
    fasta_fai    // channel: [ val(meta), path(fasta), path(fai) ]
    annotation   // channel: [ val(meta), path(gtf/gff) ]
    bed          // channel: [ val(meta), path(bed) ]

    main:
    //
    // MODULE: Convert BED to GTF using GSTAMA
    //
    GSTAMA_CONVERT ( bed )
    ch_gstama_gtf = GSTAMA_CONVERT.out.gtf
        .map { meta, gtf -> [ meta + [bed2gtf: "gstama"], gtf ] }

    //
    // MODULE: Convert BED to GTF/GFF using gffread
    //
    ch_gffread_gtf = Channel.empty()
    ch_gffread_gff = Channel.empty()
    if (!params.skip_gffread) {
        GFFREAD_GTF ( bed, [] )
        ch_gffread_gtf = GFFREAD_GTF.out.gtf
            .map { meta, gff -> [ meta + [bed2gtf: "gffread_gtf"], gff ] }

        GFFREAD_GFF ( bed, [] )
        ch_gffread_gff = GFFREAD_GFF.out.gffread_gff
            .map { meta, gff -> [ meta + [bed2gtf: "gffread_gff"], gff ] }
    }

    //
    // MODULE: Compare all annotations and the reference
    // -- Only works with a ANNOTATION GFF file and GSTAMA GTF file
    //
    ch_gffcompare_input = ch_gstama_gtf
        .map { meta, gtf -> gtf }
        .collect()
        .map { gtfs -> [ [id: 'all_annotations'], gtfs ] }

    GFFCOMPARE (
        ch_gffcompare_input,
        fasta_fai.first(),
        annotation.first()
    )

    // Combine results
    ch_annotations = ch_gstama_gtf
        .mix(ch_gffread_gtf)
        .mix(ch_gffread_gff)

    emit:
    transcript_annotation = ch_annotations // channel: [meta, gtf/gff]
}

