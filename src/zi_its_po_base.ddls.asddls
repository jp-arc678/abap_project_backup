@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Purchase Order - Base with computed fields'
define view entity ZI_ITS_PO_BASE
  as select from zits_po
{
  key po_uuid as POUUID,

      case overall_status
        when 'D' then 'Draft'
        when 'P' then 'Pending Approval'
        when 'A' then 'Approved'
        when 'R' then 'Received'
        when 'X' then 'Rejected'
        else ''
      end as OverallStatusText,

      cast(
        case overall_status
          when 'R' then 3
          when 'A' then 3
          when 'P' then 2
          when 'X' then 1
          else 0
        end as abap.int1 ) as StatusCriticality,

      // PAYMENT STATE IS DERIVED, NEVER STORED.
      //
      // The table holds only two facts: the due date, and whether payment
      // has happened. 'Overdue' is worked out against the current date on
      // every single read, so it is correct by construction - there is no
      // nightly job to flip a flag, and therefore no window in which the
      // flag is silently wrong. Same principle as the trial balance, which
      // derives every balance from the ledger instead of storing one.
      //
      // A blank due date means the order has not been received yet, so
      // there is nothing owed and nothing to say about it.
      case
        when payment_status = 'X'                   then 'Paid'
        when due_date       = '00000000'            then ''
        when due_date      >= $session.system_date  then 'Open'
        else                                             'Overdue'
      end as PaymentStatusText,

      // Signed: positive = days still to run, negative = days overdue.
      cast(
        case
          when payment_status = 'X'        then 0
          when due_date       = '00000000' then 0
          else dats_days_between( $session.system_date, due_date )
        end as abap.int4 ) as DaysToDue,

      // 3 green paid - 2 amber still open - 1 red overdue - 0 grey nothing owed
      cast(
        case
          when payment_status = 'X'                   then 3
          when due_date       = '00000000'            then 0
          when due_date      >= $session.system_date  then 2
          else                                             1
        end as abap.int1 ) as PaymentCriticality
}
