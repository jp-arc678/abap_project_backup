@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order - Data Model View'
define root view entity ZI_ITS_SALESORDER
  as select from zits_so
  composition [0..*] of ZI_ITS_SALESORDERITEM as _Item
  association [0..1] to ZI_ITS_EMPLOYEE as _Salesperson on $projection.SalespersonID = _Salesperson.EmployeeID
  association [0..1] to ZI_ITS_BRANCH as _Branch on $projection.BranchID = _Branch.BranchID
  association [0..1] to ZI_ITS_PARTNER as _Customer on $projection.CustomerID = _Customer.PartnerID
  association [1..1] to ZI_ITS_SO_BASE as _Base on $projection.SOUUID = _Base.SOUUID
{
      @EndUserText.label: 'Sales Order UUID'
  key so_uuid               as SOUUID,

      @EndUserText.label: 'Sales Order Number'
      so_number             as SONumber,

      @EndUserText.label: 'Branch ID'
      branch_id             as BranchID,

      @EndUserText.label: 'Order Type'
      order_type            as OrderType,

      @EndUserText.label: 'Status'
      overall_status        as OverallStatus,

      @EndUserText.label: 'Approval Level'
      approval_level        as ApprovalLevel,

      @EndUserText.label: 'Salesperson'
      salesperson_id        as SalespersonID,

      @EndUserText.label: 'Sales Date'
      sales_date            as SalesDate,

      @EndUserText.label: 'Total Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      total_amount          as TotalAmount,

      @EndUserText.label: 'Currency'
      currency_code         as CurrencyCode,

      @EndUserText.label: 'Payment Method'
      payment_method        as PaymentMethod,

      // Optional, unlike the purchase order's SupplierID. Blank means a
      // walk-in sale, which is the normal case for a retail counter.
      @EndUserText.label: 'Customer'
      customer_id           as CustomerID,

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
      _Salesperson,
      _Branch,
      _Customer,
      _Base
}
