@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Stock - Data Model View'
define root view entity ZI_ITS_STOCK
  as select from zits_stock
  association [1..1] to ZI_ITS_PRODUCT as _Product on $projection.ProductID = _Product.ProductID
  association [1..1] to ZI_ITS_BRANCH  as _Branch  on $projection.BranchID  = _Branch.BranchID
{
      @EndUserText.label: 'Branch ID'
  key branch_id            as BranchID,

      @EndUserText.label: 'Product ID'
  key product_id           as ProductID,

      @EndUserText.label: 'Quantity on Hand'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      qty_on_hand           as QtyOnHand,

      @EndUserText.label: 'Quantity Reserved'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      qty_reserved          as QtyReserved,

      @EndUserText.label: 'Reorder Level'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      reorder_level         as ReorderLevel,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @EndUserText.label: 'Last Movement Date'
      last_movement_date    as LastMovementDate,

      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @EndUserText.label: 'Last Changed By'
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,

      @EndUserText.label: 'Last Changed At'
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      @EndUserText.label: 'Last Changed At (Total)'
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _Product,
      _Branch
}
