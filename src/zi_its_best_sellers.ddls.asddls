@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Best Selling Products by Branch'
@Metadata.allowExtensions: true

// One row per product per branch: how much of it sold, in units, value
// and margin.
//
// Prices come from the ITEM, never from the product master: sale_price
// and cost_price on ZITS_SOITEM are what the goods actually changed hands
// for, snapshotted at the moment of sale. The product master only supplies
// the name and category, which are descriptive and may change freely.
//
// Deliberately NOT ranked or topped here - sorting belongs in the Fiori
// app, so the same view serves "best by units" and "best by margin".
define view entity ZI_ITS_BEST_SELLERS
  as select from zits_soitem as item

    // INNER on both: an item always has a parent order and always has a
    // product, and the status filter has to bite through this join
    inner join      zits_so      as so     on so.so_uuid = item.parent_uuid
    inner join      zits_product as prod   on prod.product_id = item.product_id

    left outer join zits_branch  as branch on branch.branch_id = so.branch_id

{
      @EndUserText.label: 'Branch'
      @ObjectModel.text.element: [ 'BranchName' ]
  key so.branch_id       as BranchID,

      @EndUserText.label: 'Product'
      @ObjectModel.text.element: [ 'ProductName' ]
  key item.product_id    as ProductID,

      @EndUserText.label: 'Branch Name'
      branch.branch_name as BranchName,

      @EndUserText.label: 'Product Name'
      prod.product_name  as ProductName,

      @EndUserText.label: 'Category'
      prod.category      as Category,

      @EndUserText.label: 'Unit'
      item.unit          as Unit,

      @EndUserText.label: 'Currency'
      so.currency_code   as CurrencyCode,

      @EndUserText.label: 'Quantity Sold'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      sum( item.quantity ) as TotalQuantitySold,

      @EndUserText.label: 'Total Revenue'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( cast( item.amount as abap.dec(15,2) ) ) as TotalRevenue,

      // what those goods cost us, at the cost snapshotted on the line
      @EndUserText.label: 'Total Cost'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( cast( item.quantity * item.cost_price as abap.dec(15,2) ) ) as TotalCost,

      // revenue minus cost. Makes "best seller" mean most profitable, not
      // merely most numerous - a cheap accessory can outsell a laptop on
      // units and still earn less.
      @EndUserText.label: 'Total Margin'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( cast( item.amount as abap.dec(15,2) ) )
    - sum( cast( item.quantity * item.cost_price as abap.dec(15,2) ) ) as TotalMargin,

      // distinct, because one order can carry several lines and this counts
      // orders that contained the product, not lines
      @EndUserText.label: 'Orders'
      count( distinct so.so_uuid ) as OrderCount
}

where so.overall_status = 'F'

group by
  so.branch_id,
  item.product_id,
  branch.branch_name,
  prod.product_name,
  prod.category,
  item.unit,
  so.currency_code
