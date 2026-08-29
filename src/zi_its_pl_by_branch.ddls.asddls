
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'each branch calculated ROI'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ITS_PL_BY_BRANCH as select from zits_branch
{
    key branch_id
} // these are place holders not the correct or actual code 
