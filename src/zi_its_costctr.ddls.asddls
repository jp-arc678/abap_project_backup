
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for cost center'
define root view entity ZI_ITS_COSTCTR as select from zits_costctr
{
    key cost_center_id as CostCenterId,
    cc_name as CcName,
    branch_id as BranchId,
    cc_type as CcType,
    is_active as IsActive,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt
}
