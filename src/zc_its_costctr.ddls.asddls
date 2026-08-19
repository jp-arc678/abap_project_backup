@EndUserText.label: 'Cost Center - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_COSTCTR
  provider contract transactional_query
  as projection on ZI_ITS_COSTCTR
{
      @Search.defaultSearchElement: true
  key CostCenterID,

      @Search.defaultSearchElement: true
      CCName,
      BranchID,
      CCType,
      IsActive,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
