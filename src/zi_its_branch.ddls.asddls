
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for branch'

define root view entity ZI_ITS_BRANCH as select from zits_branch
{
    key branch_id as BranchId,
    branch_name as BranchName,
    region_id as RegionId,
    branch_manager_id as BranchManagerId,
    address as Address,
    phone as Phone,
    opening_date as OpeningDate,
    is_active as IsActive,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt
}
