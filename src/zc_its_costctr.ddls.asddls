
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for cost center'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_COSTCTR
  provider contract transactional_query
  as projection on ZI_ITS_COSTCTR
{
    @Search.defaultSearchElement: true
    key CostCenterId,
    CcName,
    BranchId,
    CcType,
    IsActive,
    CreatedBy,
    CreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt
}
