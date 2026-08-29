
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'trial balance view'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ITS_TRIAL_BALANCE as select from zits_glacct {
@EndUserText.label: 'GL Account'
  key gl_account     as GLAccount 
  } where is_active = 'X' 
  // these are place holders not the correct or actual code 
