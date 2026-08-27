@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - GL Account'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ITS_VH_GLACCT
  as select from zits_glacct
{
      @EndUserText.label: 'GL Account'
  key gl_account     as GLAccount,

      @EndUserText.label: 'Account Name'
      account_name   as AccountName,

      @EndUserText.label: 'Account Type'
      account_type   as AccountType,

      @EndUserText.label: 'Normal Balance'
      normal_balance as NormalBalance
}
where is_active = 'X'
