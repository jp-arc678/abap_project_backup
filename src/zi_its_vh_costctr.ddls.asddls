@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Cost Center'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ITS_VH_COSTCTR
  as select from zits_costctr
{
      @EndUserText.label: 'Cost Center ID'
  key cost_center_id as CostCenterID,

      @EndUserText.label: 'Cost Center Name'
      cc_name        as CCName,

      @EndUserText.label: 'Branch ID'
      branch_id      as BranchID
}
where is_active = 'X'
