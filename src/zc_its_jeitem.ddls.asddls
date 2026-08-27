@EndUserText.label: 'Journal Entry Item - Projection'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
define view entity ZC_ITS_JEITEM
  as projection on ZI_ITS_JEITEM
{
  key JEItemUUID,
      ParentUUID,
      ItemPos,

      @ObjectModel.text.element: [ 'AccountName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_VH_GLACCT', element: 'GLAccount' } } ]
      GLAccount,

      _GLAccount.AccountName as AccountName,

      DCIndicator,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      Amount,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'I_CurrencyStdVH', element: 'Currency' } } ]
      CurrencyCode,

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_VH_COSTCTR', element: 'CostCenterID' } } ]
      CostCenterID,

      _CostCenter.CCName as CostCenterName,

      LineText,
      LocalLastChangedAt,

      _JournalEntry : redirected to parent ZC_ITS_JE
}
