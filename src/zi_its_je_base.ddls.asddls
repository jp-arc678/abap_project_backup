@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Journal Entry - Base with computed fields'
define view entity ZI_ITS_JE_BASE
  as select from zits_je
{
      @EndUserText.label: 'Journal Entry UUID'
  key je_uuid as JEUUID,

      // 3 = green (balanced and not empty), 1 = red (out of balance)
      // Computed here, not in ZI_ITS_JE, because ZI_ITS_JE is draft-enabled
      // and its draft table ZITS_JE_D has no column for a calculated field
      // (hard-won rule 1). Reached from the projection through association _Base.
      @EndUserText.label: 'Balance Criticality'
      cast(
        case when total_debit = total_credit and total_debit > 0
             then 3
             else 1
        end as abap.int1 ) as BalanceCriticality,

      // Posting period, split out here for the same reason as the
      // criticality above: an aggregating view can only GROUP BY plain
      // field references, never expressions, so the year and month have to
      // already be fields by the time ZI_ITS_PL_BY_BRANCH groups on them.
      //
      // ABAP CDS has no EXTRACT_YEAR / EXTRACT_MONTH for abap.dats - the
      // DATS_* functions only validate, compare or shift dates. A DATS is
      // physically YYYYMMDD, so casting to CHAR(8) and slicing is the
      // portable way to get period keys. NUMC keeps them sorting correctly
      // and displaying with leading zeros.
      @EndUserText.label: 'Posting Year'
      cast( substring( cast( posting_date as abap.char( 8 ) ), 1, 4 ) as abap.numc( 4 ) ) as PostingYear,

      @EndUserText.label: 'Posting Month'
      cast( substring( cast( posting_date as abap.char( 8 ) ), 5, 2 ) as abap.numc( 2 ) ) as PostingMonth
}
