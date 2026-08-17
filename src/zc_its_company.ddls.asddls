@EndUserText.label: 'Company - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_COMPANY
  provider contract transactional_query
  as projection on ZI_ITS_COMPANY
{
      @Search.defaultSearchElement: true
  key CompanyID,

      @Search.defaultSearchElement: true
      CompanyName,
      LegalName,
      TaxID,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_CurrencyStdVH', element: 'Currency' },
                                            useForValidation: true } ]
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
