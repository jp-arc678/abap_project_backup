
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for partners list'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_PARTNER
  provider contract transactional_query
  as projection on ZI_ITS_PARTNER
{
    @Search.defaultSearchElement: true
    key PartnerId,
    PartnerName,
    PartnerRole,
    PartnerType,
    TaxId,
    Address,
    Phone,
    Email,
    PaymentTerms,
    IsActive,
    CreatedBy,
    CreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt
}
