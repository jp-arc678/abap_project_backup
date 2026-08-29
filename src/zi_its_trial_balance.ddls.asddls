@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Trial Balance by Branch and GL Account'
@Metadata.allowExtensions: true

// One row per branch x GL account, built entirely from posted journal
// entry lines. Nothing here reads a stored balance, because nothing in
// the system stores one - the ledger IS the balance. Same reconciliation
// principle as the material document in Step 4.
//
// Summed across every row, TotalDebit must equal TotalCredit. That is the
// proof double-entry actually holds end to end.
define view entity ZI_ITS_TRIAL_BALANCE
  as select from zits_jeitem as item

    inner join      zits_je     as je     on  je.je_uuid = item.parent_uuid

    // LEFT OUTER on purpose: a journal entry typed by accounting has no
    // branch, and an account could in principle be removed from the chart
    // later. An INNER join would silently drop those lines and the trial
    // balance would stop balancing - the one thing it exists to prove.
    left outer join zits_glacct as acct   on  acct.gl_account = item.gl_account
    left outer join zits_branch as branch on  branch.branch_id = je.branch_id

{
      @EndUserText.label: 'Branch'
  key je.branch_id       as BranchID,

      @EndUserText.label: 'GL Account'
  key item.gl_account    as GLAccount,

      @EndUserText.label: 'Branch Name'
      branch.branch_name as BranchName,

      @EndUserText.label: 'Account Name'
      acct.account_name  as AccountName,

      @EndUserText.label: 'Account Type'
      acct.account_type  as AccountType,

      @EndUserText.label: 'Normal Balance'
      acct.normal_balance as NormalBalance,

      @EndUserText.label: 'Currency'
      je.currency_code   as CurrencyCode,

      @EndUserText.label: 'Total Debit'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.dc_indicator = 'D'
                then cast( item.amount as abap.dec(15,2) )
                else cast( 0 as abap.dec(15,2) )
           end )        as TotalDebit,

      @EndUserText.label: 'Total Credit'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sum( case when item.dc_indicator = 'C'
                then cast( item.amount as abap.dec(15,2) )
                else cast( 0 as abap.dec(15,2) )
           end )        as TotalCredit,

      // Signed to the account's own normal side, so every balance reads
      // positive when the account behaves as expected. Credit-normal is
      // the tested case and debit-normal is the default, so an account
      // with no chart entry still nets debit-minus-credit rather than
      // silently flipping sign.
      @EndUserText.label: 'Balance'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      case when acct.normal_balance = 'C'
           then sum( case when item.dc_indicator = 'C'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( 0 as abap.dec(15,2) )
                     end )
              - sum( case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( 0 as abap.dec(15,2) )
                     end )
           else sum( case when item.dc_indicator = 'D'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( 0 as abap.dec(15,2) )
                     end )
              - sum( case when item.dc_indicator = 'C'
                          then cast( item.amount as abap.dec(15,2) )
                          else cast( 0 as abap.dec(15,2) )
                     end )
      end                as Balance
}

// posted entries only. A draft entry may be unbalanced and can still be
// edited or deleted, so including one would produce a trial balance that
// does not balance.
where je.posting_status = 'P'

group by
  je.branch_id,
  item.gl_account,
  branch.branch_name,
  acct.account_name,
  acct.account_type,
  acct.normal_balance,
  je.currency_code
