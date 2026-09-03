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

      // Optional. The picker is filtered to customer partners only, unlike
      // the purchase order's SupplierID which points at the whole partner
      // list - a sales order should never be able to select a supplier.
      @ObjectModel.text.element: [ 'CustomerName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_VH_CUSTOMER', element: 'PartnerID' } } ]
      CustomerID,

      // from _Base, not from _Customer directly: the base view turns a
      // missing customer into 'Walk-in' instead of leaving it blank
      _Base.CustomerName as CustomerName,

      SalesDate,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      SubtotalAmount,

      // The picker lists every active promotion; validateOrderPromo is what
      // enforces type 'Q'/'A' and the threshold.
      @ObjectModel.text.element: [ 'OrderPromoName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_VH_PROMO', element: 'PromoID' } } ]
      PromoID,

      _OrderPromo.PromoName as OrderPromoName,

      DiscountPercent,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      DiscountAmount,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalAmount,
      ApprovedBy,
      ApprovedAt,
      RejectionReason,
      LocalLastChangedAt,
      LastChangedAt,

      _Item : redirected to composition child ZC_ITS_SALESORDERITEM
      
}
