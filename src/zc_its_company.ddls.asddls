
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for company'
@Metadata.allowExtensions: true
define root view entity ZC_ITS_COMPANY provider contract transactional_query
  as projection on ZI_ITS_COMPANY
{
    key CompanyID,
    CompanyName,
    LegalName,
    TaxID,
    Currency,
    Address,
    Phone,
    IsActive,
    CreatedBy,
    CreatedAt,
    LocalLastChangedBy,
    LocalLastChangedAt,
    LastChangedAt
}
