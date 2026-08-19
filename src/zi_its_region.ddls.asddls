
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for regions'

define root view entity ZI_ITS_REGION as select from zits_region
{
    key region_id as RegionId,
    region_name as RegionName,
    company_id as CompanyId,
    region_manager_id as RegionManagerId,
    is_active as IsActive,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt
}
