@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Daily Purchase'
@Analytics.dataCategory: #CUBE
@Metadata.allowExtensions: true
define view entity ZI_ITS_DAILY_PURCHASE
  as select from zits_ledger
{
      @EndUserText.label: 'Date'
  key posting_date as PostingDate,
      @EndUserText.label: 'Currency'
  key currency_code as CurrencyCode,
      @EndUserText.label: 'Purchase Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( cast( amount as abap.dec(15,2) ) ) as PurchaseAmount
}
where entry_type = 'E' and ref_doc_type = 'PO'
group by posting_date, currency_code

