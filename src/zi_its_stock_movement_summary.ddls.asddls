@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock Movement Summary by Branch and Product'
@Metadata.allowExtensions: true

// ZI_ITS_MATDOC lists every movement, one row per event. This view answers
// a different question: over time, how much of a product moved in and out
// of a branch, and what is the net effect.
//
// It exists to make the document principle checkable in one place:
//
//     opening quantity (seeded by ZCL_ITS_GEN_MASTER, never a document)
//   + NetMovement (every material document since)
//   = ZITS_STOCK.qty_on_hand
//
// Quantity on ZITS_MATDOC is SIGNED - receipts positive, issues negative -
// unlike journal amounts, which are always positive with the direction in
// dc_indicator. So the issue total comes out negative already and must not
// be negated a second time, and the net is a plain sum.
define view entity ZI_ITS_STOCK_MOVEMENT_SUMMARY
  as select from zits_matdoc as doc

    // LEFT OUTER on both: a movement must never vanish from the report
    // because a name lookup failed - that would silently break the
    // reconciliation the view exists to demonstrate
    left outer join zits_branch  as branch on branch.branch_id  = doc.branch_id
    left outer join zits_product as prod   on prod.product_id   = doc.product_id

{
      @EndUserText.label: 'Branch'
      @ObjectModel.text.element: [ 'BranchName' ]
  key doc.branch_id      as BranchID,

      @EndUserText.label: 'Product'
      @ObjectModel.text.element: [ 'ProductName' ]
  key doc.product_id     as ProductID,

      @EndUserText.label: 'Branch Name'
      branch.branch_name as BranchName,

      @EndUserText.label: 'Product Name'
      prod.product_name  as ProductName,

      @EndUserText.label: 'Unit'
      doc.unit           as Unit,

      // '101' mirrors ZCL_ITS_MOVEMENT=>gc_goods_receipt. CDS cannot read
      // ABAP constants (Round A finding), so the literal is repeated here -
      // change it in both places or neither. Stored positive.
      @EndUserText.label: 'Total Received'
      sum( case when doc.movement_type = '101'
                then cast( doc.quantity as abap.dec(13,3) )
                else cast( 0 as abap.dec(13,3) )
           end )         as TotalReceived,

      // '601' mirrors ZCL_ITS_MOVEMENT=>gc_goods_issue. Already stored
      // negative, so this total comes out negative and is NOT negated again.
      @EndUserText.label: 'Total Issued'
      sum( case when doc.movement_type = '601'
                then cast( doc.quantity as abap.dec(13,3) )
                else cast( 0 as abap.dec(13,3) )
           end )         as TotalIssued,

      // Summed over EVERY movement type rather than TotalReceived +
      // TotalIssued. Identical today - only 101 and 601 exist, because
      // Stock Transfer (Step 6) was skipped - but this keeps the figure
      // honest the moment 301/302 start being written, instead of quietly
      // under-reporting the net and breaking the reconciliation above.
      @EndUserText.label: 'Net Movement'
      sum( cast( doc.quantity as abap.dec(13,3) ) ) as NetMovement,

      @EndUserText.label: 'Movements'
      count( * )         as MovementCount,

      @EndUserText.label: 'First Movement'
      min( doc.posting_date ) as FirstMovementDate,

      @EndUserText.label: 'Last Movement'
      max( doc.posting_date ) as LastMovementDate
}

group by
  doc.branch_id,
  doc.product_id,
  branch.branch_name,
  prod.product_name,
  doc.unit
