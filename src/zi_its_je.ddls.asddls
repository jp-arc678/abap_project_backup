@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Journal Entry - Data Model View'
define root view entity ZI_ITS_JE
  as select from zits_je
  composition [0..*] of ZI_ITS_JEITEM as _Item
  association [0..1] to ZI_ITS_BRANCH  as _Branch on $projection.BranchID = _Branch.BranchID
  association [1..1] to ZI_ITS_JE_BASE as _Base   on $projection.JEUUID   = _Base.JEUUID
{
      @EndUserText.label: 'Journal Entry UUID'
  key je_uuid               as JEUUID,

      @EndUserText.label: 'Journal Entry Number'
      je_number             as JENumber,

      @EndUserText.label: 'Posting Date'
      posting_date          as PostingDate,

      @EndUserText.label: 'Document Type'
      doc_type              as DocType,

      @EndUserText.label: 'Branch ID'
      branch_id             as BranchID,

      @EndUserText.label: 'Header Text'
      header_text           as HeaderText,

      @EndUserText.label: 'Reference Doc Type'
      ref_doc_type          as RefDocType,

      @EndUserText.label: 'Reference Doc Number'
      ref_doc_number        as RefDocNumber,

      @EndUserText.label: 'Reference Doc UUID'
      ref_doc_uuid          as RefDocUUID,

      @EndUserText.label: 'Total Debit'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_debit           as TotalDebit,

      @EndUserText.label: 'Total Credit'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_credit          as TotalCredit,

      @EndUserText.label: 'Currency'
      currency_code         as CurrencyCode,

      @EndUserText.label: 'Posting Status'
      posting_status        as PostingStatus,

      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @EndUserText.label: 'Last Changed By'
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,

      @EndUserText.label: 'Last Changed At'
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      @EndUserText.label: 'Last Changed At (Total)'
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _Item,
      _Branch,
      _Base
}
