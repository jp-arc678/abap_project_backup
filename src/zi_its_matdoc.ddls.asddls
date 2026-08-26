@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Material Document - Data Model View'
define root view entity ZI_ITS_MATDOC
  as select from zits_matdoc
  association [0..1] to ZI_ITS_BRANCH  as _Branch  on $projection.BranchID  = _Branch.BranchID
  association [0..1] to ZI_ITS_PRODUCT as _Product on $projection.ProductID = _Product.ProductID
{
      @EndUserText.label: 'Material Document UUID'
  key matdoc_uuid    as MatDocUUID,

      @EndUserText.label: 'Material Document Number'
      matdoc_number   as MatDocNumber,

      @EndUserText.label: 'Posting Date'
      posting_date    as PostingDate,

      @EndUserText.label: 'Movement Type'
      movement_type   as MovementType,

      @EndUserText.label: 'Movement Type Description'
      case movement_type
        when '101' then cast( 'Goods Receipt' as abap.char( 40 ) )
        when '601' then cast( 'Goods Issue'   as abap.char( 40 ) )
        when '301' then cast( 'Transfer Out'  as abap.char( 40 ) )
        when '302' then cast( 'Transfer In'   as abap.char( 40 ) )
        else            cast( 'Unknown'       as abap.char( 40 ) )
      end                as MovementTypeText,

      @EndUserText.label: 'Branch ID'
      branch_id       as BranchID,

      @EndUserText.label: 'Product ID'
      product_id      as ProductID,

      @EndUserText.label: 'Quantity'
      @Semantics.quantity.unitOfMeasure: 'Unit'
      quantity        as Quantity,

      @EndUserText.label: 'Quantity Criticality'
      cast( case when quantity < 0 then 1 else 3 end as abap.int1 ) as QuantityCriticality,

      @EndUserText.label: 'Unit'
      unit            as Unit,

      @EndUserText.label: 'Reference Document Type'
      ref_doc_type    as RefDocType,

      @EndUserText.label: 'Reference Document Number'
      ref_doc_number  as RefDocNumber,

      @EndUserText.label: 'Reference Document UUID'
      ref_doc_uuid    as RefDocUUID,

      @EndUserText.label: 'Reference Item Position'
      ref_item_pos    as RefItemPos,

      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      created_by      as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      created_at      as CreatedAt,

      _Branch,
      _Product
}
