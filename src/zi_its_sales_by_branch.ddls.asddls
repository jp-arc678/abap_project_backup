@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales by Branch and Month'
@Metadata.allowExtensions: true

// One row per branch per sales month: how much each branch sold and when.
//
// Only orders that reached 'F' (Completed) count. That is the status
// SalesOrder's Complete action sets, and it sets it LAST - after the
// material document is written, the journal entry posted and stock
// deducted, all inside the per-order all-or-nothing rule. So 'F' is the
// only status that guarantees a sale actually happened. A draft, a
// pending approval or a rejected order has sold nothing.
//
// Header-level only: no join to the items, so summing TotalAmount cannot
// fan out. ZI_ITS_BRANCH_COMPARISON needs the items and therefore has to
// take a different route - see the comment there.
define view entity ZI_ITS_SALES_BY_BRANCH
  as select from zits_so as so

    // the period comes from ZI_ITS_SO_BASE rather than being computed here:
    // GROUP BY accepts only plain field references, not expressions
    inner join      ZI_ITS_SO_BASE as period on period.SOUUID = so.so_uuid

    // LEFT OUTER on both text lookups: an order whose branch or region
    // record is missing must still be counted, or the revenue silently
    // shrinks and no longer reconciles with the journal
    left outer join zits_branch    as branch on branch.branch_id = so.branch_id
    left outer join zits_region    as region on region.region_id = branch.region_id

{
      @EndUserText.label: 'Branch'
      @ObjectModel.text.element: [ 'BranchName' ]
  key so.branch_id        as BranchID,

      @EndUserText.label: 'Year'
  key period.SalesYear    as PostingYear,

      @EndUserText.label: 'Month'
  key period.SalesMonth   as PostingMonth,

      @EndUserText.label: 'Branch Name'
      branch.branch_name  as BranchName,

      @EndUserText.label: 'Region'
      branch.region_id    as RegionID,

      @EndUserText.label: 'Region Name'
      region.region_name  as RegionName,

      @EndUserText.label: 'Currency'
      so.currency_code    as CurrencyCode,

      @EndUserText.label: 'Orders'
      count( * )          as OrderCount,

      @EndUserText.label: 'Total Revenue'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( cast( so.total_amount as abap.dec(15,2) ) ) as TotalRevenue,

      // The CASE guard is belt and braces: a GROUP BY row only exists when
      // at least one order fell into it, so count( * ) is always >= 1 here
      // and the division can never see a zero. Kept anyway so the guard is
      // visible rather than something a reader has to reason out.
      @EndUserText.label: 'Average Order Value'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      case when count( * ) > 0
           then division( sum( cast( so.total_amount as abap.dec(15,2) ) ), count( * ), 2 )
           else cast( 0 as abap.dec(15,2) )
      end                 as AverageOrderValue
}

where so.overall_status = 'F'

group by
  so.branch_id,
  period.SalesYear,
  period.SalesMonth,
  branch.branch_name,
  branch.region_id,
  region.region_name,
  so.currency_code
