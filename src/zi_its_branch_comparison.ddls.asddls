@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Branch Comparison - All Time'
@Metadata.allowExtensions: true

// One all-time row per branch, for side-by-side comparison. No month
// breakdown - ZI_ITS_SALES_BY_BRANCH is the view for that.
//
// ⚠️ FAN-OUT: TotalUnitsSold needs the item rows, so the items are joined
// in. That multiplies every header down the join - an order with three
// lines appears three times. Two consequences, both handled:
//
//   * revenue is summed from item.amount, NOT from so.total_amount.
//     Summing the header would count the same total once per line and
//     inflate it. The two agree anyway: calcTotalAmount sets
//     TotalAmount = sum of the item Amounts, so item-level summing is the
//     same number arrived at safely.
//   * the order count is count( DISTINCT so_uuid ), not count( * ),
//     which would count lines.
//
// This is why it is one view rather than two aggregations joined together:
// the fan-out is containable with distinct-counting, and a second layer
// would need another view entity for no gain.
define view entity ZI_ITS_BRANCH_COMPARISON
  as select from zits_so as so

    inner join      zits_soitem as item   on item.parent_uuid = so.so_uuid

    left outer join zits_branch as branch on branch.branch_id = so.branch_id
    left outer join zits_region as region on region.region_id = branch.region_id

{
      @EndUserText.label: 'Branch'
      @ObjectModel.text.element: [ 'BranchName' ]
  key so.branch_id       as BranchID,

      @EndUserText.label: 'Branch Name'
      branch.branch_name as BranchName,

      @EndUserText.label: 'Region'
      branch.region_id   as RegionID,

      @EndUserText.label: 'Region Name'
      region.region_name as RegionName,

      @EndUserText.label: 'Currency'
      so.currency_code   as CurrencyCode,

      @EndUserText.label: 'Total Orders'
      count( distinct so.so_uuid ) as TotalOrders,

      @EndUserText.label: 'Total Revenue'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( cast( item.amount as abap.dec(15,2) ) ) as TotalRevenue,

      // Cast off the QUAN type deliberately. A QUAN element must carry
      // @Semantics.quantity.unitOfMeasure, and the only honest unit here
      // would be item.unit - which would have to join the GROUP BY and
      // split a branch into one row per unit, breaking the one-row-per-
      // branch contract this view exists to keep.
      //
      // A branch-wide unit total mixes products anyway, so it is a rough
      // count rather than a typed quantity. Every product is currently EA;
      // if that ever stops being true this figure adds unlike things and
      // BestSellers (which does keep the unit) is the view to trust.
      @EndUserText.label: 'Total Units Sold'
      sum( cast( item.quantity as abap.dec(15,3) ) ) as TotalUnitsSold,

      // Same guard as ZI_ITS_SALES_BY_BRANCH: a group only exists when at
      // least one order fell into it, so the divisor is always >= 1.
      @EndUserText.label: 'Average Order Value'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      case when count( distinct so.so_uuid ) > 0
           then division( sum( cast( item.amount as abap.dec(15,2) ) ),
                          count( distinct so.so_uuid ), 2 )
           else cast( 0 as abap.dec(15,2) )
      end                as AverageOrderValue
}

where so.overall_status = 'F'

group by
  so.branch_id,
  branch.branch_name,
  branch.region_id,
  region.region_name,
  so.currency_code
