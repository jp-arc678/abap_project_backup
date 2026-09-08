@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Accounts Payable Aging'
@Metadata.allowExtensions: true

// What the company still owes its suppliers, and how late it is.
//
// Every figure here is derived against the CURRENT DATE on each read -
// nothing about "overdue" is stored, so there is no flag to go stale and
// no job to keep it fresh. The same principle as the trial balance, which
// derives a balance from the ledger rather than storing one.
//
// Only received, unpaid orders appear: an order that has not arrived is
// not a debt yet, and a paid one is not a debt any more.
define view entity ZI_ITS_AP_AGING
  as select from zits_po as po

    // LEFT OUTER on both name lookups: a payable must never drop off the
    // report because a master record is missing - the money is still owed
    left outer join zits_partner as sup    on sup.partner_id  = po.supplier_id
    left outer join zits_branch  as branch on branch.branch_id = po.branch_id

{
      @EndUserText.label: 'Purchase Order UUID'
  key po.po_uuid        as POUUID,

      @EndUserText.label: 'PO Number'
      po.po_number      as PONumber,

      @EndUserText.label: 'Branch'
      @ObjectModel.text.element: [ 'BranchName' ]
      po.branch_id      as BranchID,

      @EndUserText.label: 'Branch Name'
      branch.branch_name as BranchName,

      @EndUserText.label: 'Supplier'
      @ObjectModel.text.element: [ 'SupplierName' ]
      po.supplier_id    as SupplierID,

      @EndUserText.label: 'Supplier Name'
      sup.partner_name  as SupplierName,

      @EndUserText.label: 'Terms'
      sup.payment_terms as PaymentTerms,

      @EndUserText.label: 'Received'
      po.received_date  as ReceivedDate,

      @EndUserText.label: 'Due'
      po.due_date       as DueDate,

      @EndUserText.label: 'Amount Owed'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      po.total_cost     as TotalCost,

      @EndUserText.label: 'Currency'
      po.currency_code  as CurrencyCode,

      // 0 while the debt is still within its terms, then the number of
      // days it has been late.
      @EndUserText.label: 'Days Overdue'
      cast(
        case when po.due_date < $session.system_date
             then dats_days_between( po.due_date, $session.system_date )
             else 0
        end as abap.int4 ) as DaysOverdue,

      @EndUserText.label: 'Aging Bucket'
      case
        when po.due_date >= $session.system_date                              then 'Not due'
        when dats_days_between( po.due_date, $session.system_date ) <= 30     then '1-30 days'
        when dats_days_between( po.due_date, $session.system_date ) <= 60     then '31-60 days'
        else                                                                       'Over 60 days'
      end as AgingBucket,

      // 3 green still within terms - 2 amber recently late
      // 1 red badly late. Deliberately only three levels: Fiori has no
      // fourth colour, so 31-60 and over-60 share red and the bucket text
      // carries the distinction.
      @EndUserText.label: 'Aging Criticality'
      cast(
        case
          when po.due_date >= $session.system_date                          then 3
          when dats_days_between( po.due_date, $session.system_date ) <= 30 then 2
          else                                                                  1
        end as abap.int1 ) as AgingCriticality
}

// unpaid, and actually received - 'R' is the status Receive sets
where po.payment_status = ' '
  and po.overall_status = 'R'
