
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for promotions'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_PROMO provider contract transactional_query
  as projection on ZI_ITS_PROMO
{   
     @Search.defaultSearchElement: true
    key PromoId,
    PromoName,
    PromoType,
    ProductId,
    DiscountPercent,
    ThresholdQty,
    Unit,
    ThresholdAmount,
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
