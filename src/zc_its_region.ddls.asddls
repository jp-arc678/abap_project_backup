@EndUserText.label: 'Region - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_REGION
  provider contract transactional_query
  as projection on ZI_ITS_REGION
{
      @Search.defaultSearchElement: true
  key RegionID,

      @Search.defaultSearchElement: true
      RegionName,
      CompanyID,
      RegionManagerID,
      IsActive,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
