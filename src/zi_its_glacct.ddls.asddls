@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'GL Account - Data Model View'
define root view entity ZI_ITS_GLACCT
  as select from zits_glacct
{
      @EndUserText.label: 'GL Account'
  key gl_account           as GLAccount,

      @EndUserText.label: 'Account Name'
      account_name         as AccountName,

      @EndUserText.label: 'Account Type'
      account_type         as AccountType,

      @EndUserText.label: 'Account Group'
      account_group        as AccountGroup,

      @EndUserText.label: 'Normal Balance'
      normal_balance       as NormalBalance,

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
