@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for branch'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_BRANCH
  provider contract transactional_query
  as projection on ZI_ITS_BRANCH
 {
    @Search.defaultSearchElement: true
    key BranchId,
    BranchName,
    RegionId,
    BranchManagerId,
    Address,
    Phone,
    OpeningDate,
    IsActive,
    CreatedBy,
    CreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt
}
