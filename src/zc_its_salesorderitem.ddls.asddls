@EndUserText.label: 'Sales Order Item - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity ZC_ITS_SALESORDERITEM
  as projection on ZI_ITS_SALESORDERITEM
{
  key SOItemUUID,
      ParentUUID,
      ItemPos,
      ProductID,
      @Semantics.quantity.unitOfMeasure: 'Unit'
      Quantity,
      Unit,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      SalePrice,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      Amount,
      CurrencyCode,
      LocalLastChangedAt,

      _SalesOrder : redirected to parent ZC_ITS_SALESORDER
}
