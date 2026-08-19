@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cost Center - Data Model View'
define root view entity ZI_ITS_COSTCTR
  as select from zits_costctr
{
      @EndUserText.label: 'Cost Center ID'
  key cost_center_id       as CostCenterID,

      @EndUserText.label: 'Cost Center Name'
      cc_name              as CCName,

      @EndUserText.label: 'Branch ID'
      branch_id            as BranchID,

      @EndUserText.label: 'Cost Center Type'
      cc_type              as CCType,

      @EndUserText.label: 'Active'
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
