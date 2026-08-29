@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Cash Position by Branch'
@Metadata.allowExtensions: true

// How much money each branch actually has right now, built entirely from
// posted journal entry lines.
//
// 100000 Cash and 102000 Bank are both debit-normal assets, so
// debit-minus-credit is correct for both and no normal_balance lookup is
// needed. The account numbers are owned by ZCL_ITS_GL_MAPPING
// (gc_cash / gc_bank) - CDS cannot read ABAP constants, so they are
// repeated here as literals. Change them in both places or neither.
define view entity ZI_ITS_CASH_POSITION
  as select from zits_jeitem as item

    inner join      zits_je     as je     on  je.je_uuid = item.parent_uuid
    left outer join zits_branch as branch on  branch.branch_id = je.branch_id

{
      @EndUserText.label: 'Branch'
  key je.branch_id      as BranchID,

      @EndUserText.label: 'Branch Name'
      branch.branch_name as BranchName,

      @EndUserText.label: 'Region'
      branch.region_id   as RegionID,

      @EndUserText.label: 'Currency'
      je.currency_code   as CurrencyCode,

      //--- 100000 Cash ---
      @EndUserText.label: 'Cash Balance'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.gl_account = '100000'
                then case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end ) as CashBalance,

      //--- 102000 Bank ---
      @EndUserText.label: 'Bank Balance'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.gl_account = '102000'
                then case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end ) as BankBalance,

      //--- cash + bank, expressions repeated because CDS cannot reuse an
      //    alias from the same select list ---
      @EndUserText.label: 'Total Liquidity'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.gl_account = '100000'
                then case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end )
    + sum( case when item.gl_account = '102000'
                then case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( item.amount as abap.dec(15,2) ) * -1
                     end
                else cast( 0 as abap.dec(15,2) )
           end ) as TotalLiquidity
}

where je.posting_status = 'P'

group by
  je.branch_id,
  branch.branch_name,
  branch.region_id,
  je.currency_code
