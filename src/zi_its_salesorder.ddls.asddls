@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order - Data Model View'
define root view entity ZI_ITS_SALESORDER
  as select from zits_so
  composition [0..*] of ZI_ITS_SALESORDERITEM as _Item
  association [0..1] to ZI_ITS_EMPLOYEE as _Salesperson on $projection.SalespersonID = _Salesperson.EmployeeID
  association [0..1] to ZI_ITS_BRANCH as _Branch on $projection.BranchID = _Branch.BranchID
  association [0..1] to ZI_ITS_PARTNER as _Customer on $projection.CustomerID = _Customer.PartnerID
  // different alias from the item's _Promo: same entity, different relationship
  association [0..1] to ZI_ITS_PROMO as _OrderPromo on $projection.PromoID = _OrderPromo.PromoID
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

      // Sum of the item Amounts, which are already net of any item-level
      // discount. This is what an amount-threshold promotion is measured
      // against - a stable figure that does not shrink as the order
      // discount is applied to it.
      @EndUserText.label: 'Subtotal'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      subtotal_amount       as SubtotalAmount,

      // Order-level promotion (type 'Q' or 'A'). Optional and independent
      // of the item-level ones.
      @EndUserText.label: 'Order Promotion'
      promo_id              as PromoID,

      @EndUserText.label: 'Discount %'
      discount_percent      as DiscountPercent,

      @EndUserText.label: 'Discount Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      discount_amount       as DiscountAmount,

      // NET: SubtotalAmount - DiscountAmount. Everything downstream -
      // approval routing, the journal entry, the sales reports - reads
      // this field, so they all became post-discount automatically.
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
      _OrderPromo,
      _Base
}
