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

      @ObjectModel.text.element: [ 'SupplierName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_PARTNER', element: 'PartnerID' } } ]
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
      ApprovedBy,
      ApprovedAt,
      RejectionReason,
      LocalLastChangedAt,
      LastChangedAt,
      _Item : redirected to composition child ZC_ITS_PURCHASEORDERITEM,
      _Base
}
