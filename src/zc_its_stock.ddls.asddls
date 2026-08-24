
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for stock'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_STOCK
  provider contract transactional_query
  as projection on ZI_ITS_STOCK
{
      @Search.defaultSearchElement: true
    key BranchId,
      @Search.defaultSearchElement: true
    key ProductId,
    QtyOnHand,
    QtyReserved,
    ReorderLevel,
    Unit,
    LastMovementDate,
    CreatedBy,
    CreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt
}
