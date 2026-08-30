
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'best selling product'
@Metadata.allowExtensions: true
define view entity ZI_ITS_BEST_SELLERS as select from zits_branch
{
    key branch_id
} //place holding not an actual code
