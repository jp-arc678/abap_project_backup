
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for journal entry'

define root view entity ZI_ITS_JE as select from zits_je 
composition [0..*] of ZI_ITS_JEITEM as _Item
{
    key je_uuid as JeUuid,
    je_number as JeNumber,
    posting_date as PostingDate,
    doc_type as DocType,
    branch_id as BranchId,
    header_text as HeaderText,
    ref_doc_type as RefDocType,
    ref_doc_number as RefDocNumber,
    ref_doc_uuid as RefDocUuid,
    total_debit as TotalDebit,
    total_credit as TotalCredit,
    currency_code as CurrencyCode,
    posting_status as PostingStatus,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt,
    _Item
   
}
