
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'cash account checking'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ITS_CASH_POSITION as select from zits_glacct
{
    key gl_account
} 
// these are place holders not the correct or actual code 
