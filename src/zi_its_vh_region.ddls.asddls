@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Region'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ITS_VH_REGION
  as select from zits_region
{
      @EndUserText.label: 'Region ID'
  key region_id   as RegionID,

      @EndUserText.label: 'Region Name'
      region_name as RegionName
}
where is_active = 'X'
