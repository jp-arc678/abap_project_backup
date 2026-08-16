@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Daily Sales'
@Analytics.dataCategory: #CUBE
@Metadata.allowExtensions: true
define view entity ZI_ITS_DAILY_SALES
  as select from zits_ledger
{
      @EndUserText.label: 'Date'
  key posting_date as PostingDate,
      @EndUserText.label: 'Currency'
  key currency_code as CurrencyCode,
      @EndUserText.label: 'Sales Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( cast( amount as abap.dec(15,2) ) ) as SalesAmount
}
where entry_type = 'I' and ref_doc_type = 'SO'
group by posting_date, currency_code

