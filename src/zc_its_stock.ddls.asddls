@EndUserText.label: 'Stock - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_STOCK
  provider contract transactional_query
  as projection on ZI_ITS_STOCK
{
      @Search.defaultSearchElement: true
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_BRANCH', element: 'BranchID' } } ]
  key BranchID,

      @Search.defaultSearchElement: true
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_PRODUCT', element: 'ProductID' } } ]
  key ProductID,

      _Branch.BranchName   as BranchName,
      _Product.ProductName as ProductName,

      QtyOnHand,
      QtyReserved,
      ReorderLevel,
      Unit,
      LastMovementDate,

      case when QtyOnHand < ReorderLevel then 1 else 3 end as StockCriticality,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
