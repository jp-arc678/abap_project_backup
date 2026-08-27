
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for journal entry'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_JE
  provider contract transactional_query
  as projection on ZI_ITS_JE
{
    @Search.defaultSearchElement: true
    key JeUuid,
    JeNumber,
    PostingDate,
    DocType,
    BranchId,
    HeaderText,
    RefDocType,
    RefDocNumber,
    RefDocUuid,
    TotalDebit,
    TotalCredit,
    CurrencyCode,
    PostingStatus,
    CreatedBy,
    CreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt,
    _Item : redirected to composition child ZC_ITS_JEITEM
}
