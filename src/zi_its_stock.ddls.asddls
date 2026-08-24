
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for stocks'

define root view entity ZI_ITS_STOCK as select from zits_stock
{
    key branch_id as BranchId,
    key product_id as ProductId,
    qty_on_hand as QtyOnHand,
    qty_reserved as QtyReserved,
    reorder_level as ReorderLevel,
    unit as Unit,
    last_movement_date as LastMovementDate,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt
}
