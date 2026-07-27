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
      OrderType,
      OverallStatus,
      SalespersonID,
      SalesDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalAmount,
      CurrencyCode,
      ApprovedBy,
      ApprovedAt,
      RejectionReason,
      LocalLastChangedAt,
      LastChangedAt,

      _Item : redirected to composition child ZC_ITS_SALESORDERITEM
}
