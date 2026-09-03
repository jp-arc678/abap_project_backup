@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Promotion - Data Model View'
define root view entity ZI_ITS_PROMO
  as select from zits_promo
  association [0..1] to ZI_ITS_PRODUCT as _Product on $projection.ProductID = _Product.ProductID
{
      @EndUserText.label: 'Promotion ID'
  key promo_id              as PromoID,

      @EndUserText.label: 'Promotion Name'
      promo_name            as PromoName,

      // I = Item (one product), Q = Quantity threshold, A = Amount threshold
      @EndUserText.label: 'Promotion Type'
      promo_type            as PromoType,

      @EndUserText.label: 'Product'
      product_id            as ProductID,

      @EndUserText.label: 'Discount %'
      discount_percent      as DiscountPercent,

      @EndUserText.label: 'Minimum Quantity'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      threshold_qty         as ThresholdQty,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @EndUserText.label: 'Minimum Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      threshold_amount      as ThresholdAmount,

      @EndUserText.label: 'Currency'
      currency_code         as CurrencyCode,

      @EndUserText.label: 'Valid From'
      valid_from            as ValidFrom,

      @EndUserText.label: 'Valid To'
      valid_to              as ValidTo,

      @EndUserText.label: 'Active'
      @Semantics.booleanIndicator: true
      is_active             as IsActive,

      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @EndUserText.label: 'Last Changed By'
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,

      @EndUserText.label: 'Last Changed At'
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      @EndUserText.label: 'Last Changed At (Total)'
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _Product
}
