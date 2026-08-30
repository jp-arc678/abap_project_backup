
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for showing stock summary'
@Metadata.allowExtensions: true
define view entity ZI_ITS_STOCK_MOVEMENT_SUMMARY as select from zits_stock
{
    key branch_id
} // placeholding
