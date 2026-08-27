
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for journal item'
@Metadata.allowExtensions: true
define view entity ZC_ITS_JEITEM
  as projection on ZI_ITS_JEITEM
{
    key JeitemUuid,
    ParentUuid,
    ItemPos,
    GlAccount,
    DcIndicator,
    Amount,
    CurrencyCode,
    CostCenterId,
    LineText,
    LocalLastChangedAt,
    _JournalEntry : redirected to parent ZC_ITS_JE
    
}
