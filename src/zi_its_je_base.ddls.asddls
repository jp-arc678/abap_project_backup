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
        end as abap.int1 ) as BalanceCriticality
}
