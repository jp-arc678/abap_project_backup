@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Promotion'
@ObjectModel.resultSet.sizeCategory: #XS

// Serves BOTH the item PromoID and the header PromoID. Only active
// promotions appear, and PromoType is exposed so the picker shows which
// kind each one is:
//   I = one product   -> item level
//   Q = quantity      -> header level
//   A = order amount  -> header level
//
// A CDS value help cannot see the row that is consuming it, so it can
// neither filter to "type I only" for the item field nor match the item's
// own product. validateItemPromo and validateOrderPromo are what actually
// enforce that - the picker only narrows the list to what is live.
//
// Splitting this into ZI_ITS_VH_ITEM_PROMO (type 'I') and
// ZI_ITS_VH_ORDER_PROMO (types 'Q','A') would scope each picker properly;
// it needs one more ADT shell and two annotation changes.
define view entity ZI_ITS_VH_PROMO
  as select from zits_promo
{
      @EndUserText.label: 'Promotion'
  key promo_id         as PromoID,

      @EndUserText.label: 'Name'
      promo_name       as PromoName,

      @EndUserText.label: 'Type'
      promo_type       as PromoType,

      @EndUserText.label: 'Product'
      product_id       as ProductID,

      @EndUserText.label: 'Discount %'
      discount_percent as DiscountPercent,

      @EndUserText.label: 'Minimum Quantity'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      threshold_qty    as ThresholdQty,

      @EndUserText.label: 'Unit'
      unit             as Unit,

      @EndUserText.label: 'Minimum Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      threshold_amount as ThresholdAmount,

      @EndUserText.label: 'Currency'
      currency_code    as CurrencyCode,

      @EndUserText.label: 'Valid From'
      valid_from       as ValidFrom,

      @EndUserText.label: 'Valid To'
      valid_to         as ValidTo
}
where is_active = 'X'
