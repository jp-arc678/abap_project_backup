
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for partners list'

define root view entity ZI_ITS_PARTNER as select from zits_partner
{
    key partner_id as PartnerId,
    partner_name as PartnerName,
    partner_role as PartnerRole,
    partner_type as PartnerType,
    tax_id as TaxId,
    address as Address,
    phone as Phone,
    email as Email,
    payment_terms as PaymentTerms,
    is_active as IsActive,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt
}
