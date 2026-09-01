@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Branch - Data Model View'
define root view entity ZI_ITS_BRANCH
  as select from zits_branch
{
      @EndUserText.label: 'Branch ID'
  key branch_id            as BranchID,

      @EndUserText.label: 'Branch Name'
      branch_name          as BranchName,

      @EndUserText.label: 'Region ID'
      region_id            as RegionID,

      @EndUserText.label: 'Branch Manager ID'
      branch_manager_id    as BranchManagerID,

      @EndUserText.label: 'Address'
      address              as Address,

      @EndUserText.label: 'Phone'
      phone                as Phone,

      @EndUserText.label: 'Opening Date'
      opening_date         as OpeningDate,

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
