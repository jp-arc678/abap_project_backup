
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for material document'

define root view entity ZI_ITS_MATDOC as select from zits_matdoc
{
    key matdoc_uuid as MatdocUuid,
    matdoc_number as MatdocNumber,
    posting_date as PostingDate,
    movement_type as MovementType,
    branch_id as BranchId,
    product_id as ProductId,
    quantity as Quantity,
    unit as Unit,
    ref_doc_type as RefDocType,
    ref_doc_number as RefDocNumber,
    ref_doc_uuid as RefDocUuid,
    ref_item_pos as RefItemPos,
    created_by as CreatedBy,
    created_at as CreatedAt
}
