
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for journal item'

define view entity ZI_ITS_JEITEM as select from zits_jeitem
association to parent ZI_ITS_JE as _JournalEntry on $projection.ParentUuid = _JournalEntry.JeUuid
{
    key jeitem_uuid as JeitemUuid,
    parent_uuid as ParentUuid,
    item_pos as ItemPos,
    gl_account as GlAccount,
    dc_indicator as DcIndicator,
    amount as Amount,
    currency_code as CurrencyCode,
    cost_center_id as CostCenterId,
    line_text as LineText,
    local_last_changed_at as LocalLastChangedAt,
    _JournalEntry
}
