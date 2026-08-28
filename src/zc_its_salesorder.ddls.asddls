@EndUserText.label: 'Sales Order - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_SALESORDER
  provider contract transactional_query
  as projection on ZI_ITS_SALESORDER
{
      @Search.defaultSearchElement: true
  key SOUUID,
      SONumber,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_BRANCH', element: 'BranchID' } } ]
      BranchID,

      _Branch.BranchName as BranchName,

      OrderType,
      @ObjectModel.text.element: [ 'OverallStatusText' ]
      OverallStatus,
      ApprovalLevel,

      _Base.OverallStatusText as OverallStatusText,
      _Base.StatusCriticality as StatusCriticality,
       @ObjectModel.text.element: [ 'SalespersonName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_VH_SALESPERSON', element: 'EmployeeID' } } ]
      SalespersonID,

      _Salesperson.EmployeeName as SalespersonName,
      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_CurrencyStdVH', element: 'Currency' } } ]
      CurrencyCode,

      // C = Cash, R = Credit card, T = Transfer - decides which account
      // the sale is debited to when the journal entry is posted
      PaymentMethod,

      SalesDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalAmount,
      ApprovedBy,
      ApprovedAt,
      RejectionReason,
      LocalLastChangedAt,
      LastChangedAt,

      _Item : redirected to composition child ZC_ITS_SALESORDERITEM
      
}
