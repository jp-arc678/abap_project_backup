@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Shop Balance - Aggregated'
define view entity ZI_ITS_SHOP_BALANCE
  as select from zits_ledger
{
      @EndUserText.label: 'Currency'
  key currency_code as CurrencyCode,

      @EndUserText.label: 'Total Income'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case entry_type
             when 'I' then cast( amount as abap.dec(15,2) )
             else cast( 0 as abap.dec(15,2) )
           end ) as TotalIncome,

      @EndUserText.label: 'Total Expense'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case entry_type
             when 'E' then cast( amount as abap.dec(15,2) )
             else cast( 0 as abap.dec(15,2) )
           end ) as TotalExpense,

      @EndUserText.label: 'Balance'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case entry_type
             when 'I' then cast( amount as abap.dec(15,2) )
             when 'E' then cast( amount as abap.dec(15,2) ) * -1
             else cast( 0 as abap.dec(15,2) )
           end ) as Balance
}
group by currency_code
