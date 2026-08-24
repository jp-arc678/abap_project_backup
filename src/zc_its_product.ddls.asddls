@EndUserText.label: 'Product - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_PRODUCT
  provider contract transactional_query
  as projection on ZI_ITS_PRODUCT
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.90
  key ProductID,

      @Search.defaultSearchElement: true
      ProductName,
      Category,
      Brand,
      Description,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      SalePrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      CostPrice,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_CurrencyStdVH', element: 'Currency' },
                                            useForValidation: true } ]
      CurrencyCode,

      Unit,

      IsActive,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
