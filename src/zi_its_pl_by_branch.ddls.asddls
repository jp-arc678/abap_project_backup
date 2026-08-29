@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Profit and Loss by Branch and Month'
@Metadata.allowExtensions: true

// One row per branch per posting month, built entirely from posted
// journal entry lines.
//
// Each figure is a single SUM over a signed CASE rather than two SUMs
// subtracted: the inner CASE flips the sign of the wrong-side postings,
// so a reversal nets itself out automatically. Revenue is credit-normal
// (credit positive), cost and expense are debit-normal (debit positive),
// which is why the two inner CASEs are mirror images of each other.
define view entity ZI_ITS_PL_BY_BRANCH
  as select from zits_jeitem as item

    inner join      zits_je       as je     on  je.je_uuid   = item.parent_uuid

    // the period comes from ZI_ITS_JE_BASE rather than being computed here:
    // GROUP BY accepts only plain field references, so the year and month
    // have to already be fields before this view can group on them
    inner join      ZI_ITS_JE_BASE as period on period.JEUUID = item.parent_uuid

    left outer join zits_branch   as branch on  branch.branch_id = je.branch_id

{
      @EndUserText.label: 'Branch'
  key je.branch_id       as BranchID,

      @EndUserText.label: 'Year'
  key period.PostingYear  as PostingYear,

      @EndUserText.label: 'Month'
  key period.PostingMonth as PostingMonth,

      @EndUserText.label: 'Branch Name'
      branch.branch_name as BranchName,

      @EndUserText.label: 'Currency'
      je.currency_code   as CurrencyCode,

      //--- 400000 Sales Revenue - credit normal ---
      @EndUserText.label: 'Revenue'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.gl_account = '400000'
                then case when item.dc_indicator = 'C'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end ) as Revenue,

      //--- 500000 Cost of Goods Sold - debit normal ---
      @EndUserText.label: 'Cost of Goods Sold'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.gl_account = '500000'
                then case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end ) as CostOfGoodsSold,

      //--- 600000 Operating Expense - debit normal ---
      @EndUserText.label: 'Operating Expense'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.gl_account = '600000'
                then case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end ) as OperatingExpense,

      //--- Revenue - CostOfGoodsSold. CDS cannot reference an alias
      //    declared earlier in the same select list, so the expressions
      //    are repeated rather than reused.
      @EndUserText.label: 'Gross Profit'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.gl_account = '400000'
                then case when item.dc_indicator = 'C'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end )
    - sum( case when item.gl_account = '500000'
                then case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end ) as GrossProfit,

      //--- GrossProfit - OperatingExpense ---
      @EndUserText.label: 'Net Profit'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.gl_account = '400000'
                then case when item.dc_indicator = 'C'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end )
    - sum( case when item.gl_account = '500000'
                then case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end )
    - sum( case when item.gl_account = '600000'
                then case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end ) as NetProfit
}

where je.posting_status = 'P'

group by
  je.branch_id,
  period.PostingYear,
  period.PostingMonth,
  branch.branch_name,
  je.currency_code
