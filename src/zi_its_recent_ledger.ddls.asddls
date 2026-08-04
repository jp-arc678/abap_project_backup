@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Recent Ledger Entries'
@Metadata.allowExtensions: true
define view entity ZI_ITS_RECENT_LEDGER
  as select from ZI_ITS_LEDGER
{
      @EndUserText.label: 'Entry'
  key LedgerUUID,
      @EndUserText.label: 'Date'
      PostingDate,
      @EndUserText.label: 'Type'
      EntryTypeName,
      @EndUserText.label: 'Reference'
      RefDocNumber,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      @EndUserText.label: 'Amount'
      Amount,
      CurrencyCode,
      Description,
      @EndUserText.label: 'Criticality'
      cast(
        case EntryType
          when 'I' then 3   // income = เขียว
          when 'E' then 1   // expense = แดง
          else 0
        end as abap.int1 ) as EntryCriticality
}
