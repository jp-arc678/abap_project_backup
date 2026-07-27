@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Financial Ledger - Data Model View'
define root view entity ZI_ITS_LEDGER
  as select from zits_ledger
{
      @EndUserText.label: 'Ledger UUID'
  key ledger_uuid    as LedgerUUID,

      @EndUserText.label: 'Posting Date'
      posting_date   as PostingDate,

      @EndUserText.label: 'Entry Type'
      @ObjectModel.text.element: [ 'EntryTypeName' ]
      entry_type     as EntryType,

      @EndUserText.label: 'Entry Type Name'
      case entry_type
        when 'I' then cast( 'Income'  as abap.char( 10 ) )
        when 'E' then cast( 'Expense' as abap.char( 10 ) )
        else          cast( 'Other'   as abap.char( 10 ) )
      end            as EntryTypeName,

      @EndUserText.label: 'Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      amount         as Amount,

      @EndUserText.label: 'Signed Amount'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      case entry_type
        when 'E' then amount * -1
        else          amount
      end            as SignedAmount,

      @EndUserText.label: 'Currency'
      currency_code  as CurrencyCode,

      @EndUserText.label: 'Reference Doc Type'
      ref_doc_type   as RefDocType,

      @EndUserText.label: 'Reference Doc Number'
      ref_doc_number as RefDocNumber,

      @EndUserText.label: 'Reference Doc UUID'
      ref_doc_uuid   as RefDocUUID,

      @EndUserText.label: 'Description'
      description    as Description,

      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      created_by     as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      created_at     as CreatedAt
}
