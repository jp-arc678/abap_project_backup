@EndUserText.label: 'Journal Entry - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_JE
  provider contract transactional_query
  as projection on ZI_ITS_JE
{
      @Search.defaultSearchElement: true
  key JEUUID,
      JENumber,

      PostingDate,
      DocType,

      @ObjectModel.text.element: [ 'BranchName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_BRANCH', element: 'BranchID' } } ]
      BranchID,

      _Branch.BranchName as BranchName,

      HeaderText,

      RefDocType,
      RefDocNumber,
      RefDocUUID,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalDebit,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalCredit,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_CurrencyStdVH', element: 'Currency' } } ]
      CurrencyCode,

      PostingStatus,

      // green when debits = credits and the entry is not empty, red otherwise
      _Base.BalanceCriticality as BalanceCriticality,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,

      _Item : redirected to composition child ZC_ITS_JEITEM
}
