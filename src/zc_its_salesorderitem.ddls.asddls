@EndUserText.label: 'Sales Order Item - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity ZC_ITS_SALESORDERITEM
  as projection on ZI_ITS_SALESORDERITEM
{
  key SOItemUUID,
      ParentUUID,
      ItemPos,
      @ObjectModel.text.element: [ 'ProductName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_PRODUCT', element: 'ProductID' } } ]
      ProductID,
      _Product.ProductName as ProductName,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      Quantity,
      Unit,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      SalePrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      CostPrice,

      // The picker lists every active promotion; validateItemPromo is what
      // enforces type 'I' and the product match.
      @ObjectModel.text.element: [ 'PromoName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_VH_PROMO', element: 'PromoID' } } ]
      PromoID,

      _Promo.PromoName as PromoName,

      DiscountPercent,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      DiscountAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Amount,
       @Consumption.valueHelpDefinition: [ { entity: { name: 'I_CurrencyStdVH', element: 'Currency' } } ]
      CurrencyCode,
      LocalLastChangedAt,

      _SalesOrder : redirected to parent ZC_ITS_SALESORDER
      
}
