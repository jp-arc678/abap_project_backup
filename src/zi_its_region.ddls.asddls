@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Region - Data Model View'
define root view entity ZI_ITS_REGION
  as select from zits_region
{
      @EndUserText.label: 'Region ID'
  key region_id            as RegionID,

      @EndUserText.label: 'Region Name'
      region_name          as RegionName,

      @EndUserText.label: 'Company ID'
      company_id           as CompanyID,

      @EndUserText.label: 'Region Manager ID'
      region_manager_id    as RegionManagerID,

      @EndUserText.label: 'Active'
      @Semantics.booleanIndicator: true
      is_active            as IsActive,

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
      last_changed_at       as LastChangedAt
}
