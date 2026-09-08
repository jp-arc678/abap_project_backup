@EndUserText.label: 'Purchase Order - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_PURCHASEORDER
  provider contract transactional_query
  as projection on ZI_ITS_PURCHASEORDER
{
      @Search.defaultSearchElement: true
  key POUUID,
      PONumber,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_BRANCH', element: 'BranchID' } } ]
      BranchID,

      _Branch.BranchName as BranchName,

      // Filtered to supplier partners only. Pointing this at ZC_ITS_PARTNER
      // offered the whole list, so a customer could be picked and only
      // rejected later by validateSupplier - now the wrong choice is simply
      // not on the menu.
      @ObjectModel.text.element: [ 'SupplierName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_VH_SUPPLIER', element: 'PartnerID' } } ]
      SupplierID,

      _Supplier.PartnerName as SupplierName,

      @ObjectModel.text.element: [ 'OverallStatusText' ]
      OverallStatus,
      ApprovalLevel,
      _Base.OverallStatusText as OverallStatusText,
      _Base.StatusCriticality as StatusCriticality,
      @ObjectModel.text.element: [ 'WarehouseStaffName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_VH_WAREHOUSE', element: 'EmployeeID' } } ]
      WarehouseStaffID,
      _WarehouseStaff.EmployeeName as WarehouseStaffName,
      OrderDate,
      ReceivedDate,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      TotalCost,
      CurrencyCode,

      // C = Cash, R = Bank - the arrangement agreed with the supplier
      PaymentMethod,

      //--- the two stored payment facts ---
      PaymentStatus,
      DueDate,
      PaidDate,

      //--- and the three derived from them on every read ---
      _Base.PaymentStatusText   as PaymentStatusText,
      _Base.DaysToDue           as DaysToDue,
      _Base.PaymentCriticality  as PaymentCriticality,
      ApprovedBy,
      ApprovedAt,
      RejectionReason,
      LocalLastChangedAt,
      LastChangedAt,
      _Item : redirected to composition child ZC_ITS_PURCHASEORDERITEM,
      _Base
}
