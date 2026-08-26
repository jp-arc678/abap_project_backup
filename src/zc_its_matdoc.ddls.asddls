@EndUserText.label: 'Material Document - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_MATDOC
  provider contract transactional_query
  as projection on ZI_ITS_MATDOC
{
  key MatDocUUID,

      @Search.defaultSearchElement: true
      MatDocNumber,

      PostingDate,

      @ObjectModel.text.element: [ 'MovementTypeText' ]
      MovementType,

      MovementTypeText,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_BRANCH', element: 'BranchID' } } ]
      BranchID,

      _Branch.BranchName as BranchName,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_PRODUCT', element: 'ProductID' } } ]
      ProductID,

      _Product.ProductName as ProductName,

      @Semantics.quantity.unitOfMeasure: 'Unit'
      Quantity,

      QuantityCriticality,

      Unit,

      RefDocType,
      RefDocNumber,
      RefDocUUID,
      RefItemPos,

      CreatedBy,
      CreatedAt
}
