//
// TRANSLATE TRANSCRIPTS INTO PROTEIN SEQUENCES
//

include { TRANSDECODER_LONGORF       } from '../../../modules/nf-core/transdecoder/longorf/main'
include { BLAST_BLASTP               } from '../../../modules/nf-core/blast/blastp/main'
include { HMMER_HMMPRESS             } from '../../../modules/nf-core/hmmer/hmmpress/main'
include { HMMER_HMMSEARCH            } from '../../../modules/nf-core/hmmer/hmmsearch/main'
include { GUNZIP as GUNZIP_HMM       } from '../../../modules/nf-core/gunzip/main'
include { GUNZIP as GUNZIP_DOMTBL    } from '../../../modules/nf-core/gunzip/main'
include { TRANSDECODER_PREDICT       } from '../../../modules/nf-core/transdecoder/predict/main'

workflow TRANSCRIPTS_TO_PROTEIN {

    take:
    ch_transcript_fasta // channel: [ val(meta), path(fasta) ]

    main:
    //
    // MODULE: Run TransDecoder LongOrfs
    //
    TRANSDECODER_LONGORF (
        ch_transcript_fasta
    )

    //
    // MODULE: Run BLASTP
    //
    ch_blast_hits = Channel.of([[:], []]).collect()
    if (!params.skip_blastp && params.blastp_db) {
        ch_blastpdb = channel.fromPath(params.blastp_db).map { db -> [ [id:'db'], db ] }.collect()

        BLAST_BLASTP (
            TRANSDECODER_LONGORF.out.pep,
            ch_blastpdb,
            'tsv'
        )
        ch_blast_hits = BLAST_BLASTP.out.tsv
    }

    //
    // MODULE: Run HMMSEARCH
    //
    ch_pfam_hits = Channel.of([[:], []]).collect()
    if (!params.skip_hmmsearch && params.hmmsearch_db) {
        ch_hmmdb = channel.fromPath(params.hmmsearch_db).map { db -> [ [id:'db'], db ] }.collect()

        //
        // Unzip HMM if required
        //
        ch_hmmdb_branched = ch_hmmdb.branch {
            meta, file ->
                gz: file.extension == 'gz'
                rest: true
        }
        GUNZIP_HMM ( ch_hmmdb_branched.gz )
        ch_hmmdb_unzipped = GUNZIP_HMM.out.gunzip.mix(ch_hmmdb_branched.rest)

        //
        // Run HMMPRESS
        //
        HMMER_HMMPRESS ( ch_hmmdb_unzipped )

        //
        // Run HMMSEARCH
        //
        ch_hmmer_hmmsearch_input = TRANSDECODER_LONGORF.out.pep
            .combine(ch_hmmdb_unzipped)
            .combine(HMMER_HMMPRESS.out.compressed_db)
            .map { meta, pep, hmm_meta, hmm, pressed_meta, pressed ->
                [ meta, [hmm, pressed].flatten(), pep, false, true, true ]
            }
        HMMER_HMMSEARCH ( ch_hmmer_hmmsearch_input )

        //
        // Unzip domain summary
        //
        GUNZIP_DOMTBL ( HMMER_HMMSEARCH.out.domain_summary )
        ch_pfam_hits = GUNZIP_DOMTBL.out.gunzip
    }

    //
    // MODULE: Run TransDecoder Predict
    //
    TRANSDECODER_PREDICT (
        ch_transcript_fasta,
        TRANSDECODER_LONGORF.out.folder,
        ch_blast_hits,
        ch_pfam_hits
    )

    emit:
    pep  = TRANSDECODER_PREDICT.out.pep  // channel: [ val(meta), path(pep) ]
    gff3 = TRANSDECODER_PREDICT.out.gff3 // channel: [ val(meta), path(gff3) ]
    cds  = TRANSDECODER_PREDICT.out.cds  // channel: [ val(meta), path(cds) ]
    bed  = TRANSDECODER_PREDICT.out.bed  // channel: [ val(meta), path(bed) ]
}
