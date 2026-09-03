@EndUserText.label: 'Promotion - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_PROMO
  provider contract transactional_query
  as projection on ZI_ITS_PROMO
{
      @Search.defaultSearchElement: true
  key PromoID,

      @Search.defaultSearchElement: true
      PromoName,

      PromoType,

      // only meaningful for type 'I'; validateTypeFields keeps it empty
      // for the other two types
      @ObjectModel.text.element: [ 'ProductName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_PRODUCT', element: 'ProductID' } } ]
      ProductID,

      _Product.ProductName as ProductName,

      DiscountPercent,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      ThresholdQty,
      Unit,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      ThresholdAmount,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_CurrencyStdVH', element: 'Currency' } } ]
      CurrencyCode,

      ValidFrom,
      ValidTo,
      IsActive,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
