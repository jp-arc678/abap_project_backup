@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for region'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_REGION
  provider contract transactional_query
  as projection on ZI_ITS_REGION
{
    @Search.defaultSearchElement: true
    key RegionId,
    RegionName,
    CompanyId,
    RegionManagerId,
    IsActive,
    CreatedBy,
    CreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt
}
