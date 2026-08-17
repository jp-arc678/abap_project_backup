@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Company - Data Model View'
define root view entity ZI_ITS_COMPANY
  as select from zits_company
  association [0..1] to I_Currency as _Currency on $projection.Currency = _Currency.Currency
{
      @EndUserText.label: 'Company ID'
  key company_id            as CompanyID,

      @EndUserText.label: 'Company Name'
      company_name          as CompanyName,

      @EndUserText.label: 'Legal Name'
      legal_name            as LegalName,

      @EndUserText.label: 'Tax ID'
      tax_id                as TaxID,

      @EndUserText.label: 'Currency'
      currency              as Currency,

      @EndUserText.label: 'Address'
      address               as Address,

      @EndUserText.label: 'Phone'
      phone                 as Phone,

      @EndUserText.label: 'Active'
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

      _Currency
}
