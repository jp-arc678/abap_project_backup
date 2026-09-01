
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for promotions'

define root view entity ZI_ITS_PROMO as select from zits_promo
{
    key promo_id as PromoId,
    promo_name as PromoName,
    promo_type as PromoType,
    product_id as ProductId,
    discount_percent as DiscountPercent,
    threshold_qty as ThresholdQty,
    unit as Unit,
    threshold_amount as ThresholdAmount,
    currency_code as CurrencyCode,
    valid_from as ValidFrom,
    valid_to as ValidTo,
    is_active as IsActive,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt
}
