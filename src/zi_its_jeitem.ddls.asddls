@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Journal Entry Item - Data Model View'
define view entity ZI_ITS_JEITEM
  as select from zits_jeitem
  association        to parent ZI_ITS_JE as _JournalEntry on $projection.ParentUUID   = _JournalEntry.JEUUID
  association [0..1] to ZI_ITS_GLACCT    as _GLAccount    on $projection.GLAccount    = _GLAccount.GLAccount
  association [0..1] to ZI_ITS_COSTCTR   as _CostCenter   on $projection.CostCenterID = _CostCenter.CostCenterID
{
      @EndUserText.label: 'Item UUID'
  key jeitem_uuid           as JEItemUUID,

      @EndUserText.label: 'Parent UUID'
      parent_uuid           as ParentUUID,

      @EndUserText.label: 'Line'
      item_pos              as ItemPos,

      @EndUserText.label: 'GL Account'
      gl_account            as GLAccount,

      @EndUserText.label: 'Debit/Credit'
      dc_indicator          as DCIndicator,

      @EndUserText.label: 'Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      amount                as Amount,

      @EndUserText.label: 'Currency'
      currency_code         as CurrencyCode,

      @EndUserText.label: 'Cost Center'
      cost_center_id        as CostCenterID,

      @EndUserText.label: 'Line Text'
      line_text             as LineText,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _JournalEntry,
      _GLAccount,
      _CostCenter
}
