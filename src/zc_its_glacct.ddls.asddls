
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for gl account'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_GLACCT
  provider contract transactional_query
  as projection on ZI_ITS_GLACCT
{
    @Search.defaultSearchElement: true
    key GlAccount,
    AccountName,
    AccountType,
    AccountGroup,
    NormalBalance,
    IsActive,
    CreatedBy,
    CreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt
}
