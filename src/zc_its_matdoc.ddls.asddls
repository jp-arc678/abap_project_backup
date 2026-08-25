
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def projection for matdoc'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_MATDOC
  provider contract transactional_query
  as projection on ZI_ITS_MATDOC
{
    @Search.defaultSearchElement: true
    key MatdocUuid,
    MatdocNumber,
    PostingDate,
    MovementType,
    BranchId,
    ProductId,
    Quantity,
    Unit,
    RefDocType,
    RefDocNumber,
    RefDocUuid,
    RefItemPos,
    CreatedBy,
    CreatedAt
}
