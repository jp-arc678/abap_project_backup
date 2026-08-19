@EndUserText.label: 'Branch - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_BRANCH
  provider contract transactional_query
  as projection on ZI_ITS_BRANCH
{
      @Search.defaultSearchElement: true
  key BranchID,

      @Search.defaultSearchElement: true
      BranchName,
      RegionID,
      BranchManagerID,
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
