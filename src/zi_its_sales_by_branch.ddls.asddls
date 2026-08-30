
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'branch sales comparision'
@Metadata.allowExtensions: true

define view entity ZI_ITS_SALES_BY_BRANCH as select from zits_branch
{
    key branch_id
} //place holding not an actual code
