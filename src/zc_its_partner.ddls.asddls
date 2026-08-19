@EndUserText.label: 'Business Partner - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_PARTNER
  provider contract transactional_query
  as projection on ZI_ITS_PARTNER
{
      @Search.defaultSearchElement: true
  key PartnerID,

      @Search.defaultSearchElement: true
      PartnerName,
      PartnerRole,
      PartnerType,
      TaxID,
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
