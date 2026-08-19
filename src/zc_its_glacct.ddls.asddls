@EndUserText.label: 'GL Account - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_GLACCT
  provider contract transactional_query
  as projection on ZI_ITS_GLACCT
{
      @Search.defaultSearchElement: true
  key GLAccount,

      @Search.defaultSearchElement: true
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
