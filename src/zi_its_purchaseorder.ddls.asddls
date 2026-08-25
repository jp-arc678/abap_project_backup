@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order - Data Model View'
define root view entity ZI_ITS_PURCHASEORDER
  as select from zits_po
  composition [0..*] of ZI_ITS_PURCHASEORDERITEM as _Item
  association [0..1] to ZI_ITS_EMPLOYEE as _WarehouseStaff on $projection.WarehouseStaffID = _WarehouseStaff.EmployeeID
  association [0..1] to ZI_ITS_BRANCH as _Branch on $projection.BranchID = _Branch.BranchID
  association [0..1] to ZI_ITS_PARTNER as _Supplier on $projection.SupplierID = _Supplier.PartnerID
  association [1..1] to ZI_ITS_PO_BASE as _Base on $projection.POUUID = _Base.POUUID
{
      @EndUserText.label: 'Purchase Order UUID'
  key po_uuid               as POUUID,
      @EndUserText.label: 'PO Number'
      po_number             as PONumber,
      @EndUserText.label: 'Branch ID'
      branch_id             as BranchID,
      @EndUserText.label: 'Supplier'
      supplier_id           as SupplierID,
      @EndUserText.label: 'Status'
      overall_status        as OverallStatus,
      @EndUserText.label: 'Approval Level'
      approval_level        as ApprovalLevel,
      @EndUserText.label: 'Warehouse Staff'
      warehouse_staff_id    as WarehouseStaffID,
      @EndUserText.label: 'Order Date'
      order_date            as OrderDate,
      @EndUserText.label: 'Received Date'
      received_date         as ReceivedDate,
      @EndUserText.label: 'Total Cost'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_cost            as TotalCost,
      @EndUserText.label: 'Currency'
      currency_code         as CurrencyCode,
      @EndUserText.label: 'Approved By'
      approved_by           as ApprovedBy,
      @EndUserText.label: 'Approved At'
      approved_at           as ApprovedAt,
      @EndUserText.label: 'Rejection Reason'
      rejection_reason      as RejectionReason,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      _Item,
      _WarehouseStaff,
      _Branch,
      _Supplier,
      _Base
}
