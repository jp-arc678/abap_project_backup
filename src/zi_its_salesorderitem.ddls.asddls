@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order Item - Data Model View'
define view entity ZI_ITS_SALESORDERITEM
  as select from zits_soitem
  association to parent ZI_ITS_SALESORDER as _SalesOrder on $projection.ParentUUID = _SalesOrder.SOUUID
  association [0..1] to ZI_ITS_PRODUCT    as _Product    on $projection.ProductID = _Product.ProductID
{
      @EndUserText.label: 'Item UUID'
  key soitem_uuid           as SOItemUUID,

      @EndUserText.label: 'Parent UUID'
      parent_uuid           as ParentUUID,

      @EndUserText.label: 'Item Position'
      item_pos              as ItemPos,

      @EndUserText.label: 'Product'
      product_id            as ProductID,

      @EndUserText.label: 'Quantity'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      quantity              as Quantity,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @EndUserText.label: 'Sale Price'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sale_price            as SalePrice,

      @EndUserText.label: 'Cost Price'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      cost_price            as CostPrice,

      @EndUserText.label: 'Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      amount                as Amount,

      @EndUserText.label: 'Currency'
      currency_code         as CurrencyCode,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _SalesOrder,
      _Product
}
