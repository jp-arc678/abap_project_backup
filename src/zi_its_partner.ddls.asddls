@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Business Partner - Data Model View'
define root view entity ZI_ITS_PARTNER
  as select from zits_partner
{
      @EndUserText.label: 'Partner ID'
  key partner_id           as PartnerID,

      @EndUserText.label: 'Partner Name'
      partner_name         as PartnerName,

      @EndUserText.label: 'Partner Role'
      partner_role         as PartnerRole,

      @EndUserText.label: 'Partner Type'
      partner_type         as PartnerType,

      @EndUserText.label: 'Tax ID'
      tax_id               as TaxID,

      @EndUserText.label: 'Address'
      address              as Address,

      @EndUserText.label: 'Phone'
      phone                as Phone,

      @EndUserText.label: 'Email'
      email                as Email,

      @EndUserText.label: 'Payment Terms'
      payment_terms        as PaymentTerms,

      @EndUserText.label: 'Active'
      is_active            as IsActive,

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
      last_changed_at       as LastChangedAt
}
