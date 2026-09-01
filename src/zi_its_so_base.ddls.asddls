@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order - Base with computed fields'
define view entity ZI_ITS_SO_BASE
  as select from zits_so as so

    // only to resolve the customer's name; LEFT OUTER because most orders
    // are walk-ins and have no customer at all
    left outer join zits_partner as cust on cust.partner_id = so.customer_id

{
  key so.so_uuid       as SOUUID,

      case so.overall_status
        when 'D' then 'Draft'
        when 'S' then 'Submitted'
        when 'P' then 'Pending Approval'
        when 'C' then 'Confirmed'
        when 'F' then 'Completed'
        when 'X' then 'Rejected'
        else ''
      end               as OverallStatusText,

      cast(
        case so.overall_status
          when 'F' then 3
          when 'C' then 3
          when 'P' then 2
          when 'X' then 1
          else 0
        end as abap.int1 ) as StatusCriticality,

      // The name shown for the customer. An order with no customer is a
      // walk-in sale, which is a real and normal thing - it should say so
      // rather than render as an empty '-' in Fiori.
      //
      // Tested on the joined name being null rather than on customer_id
      // being blank: a blank id matches no partner, so the join misses and
      // the name is null. (A customer_id pointing at a partner that was
      // later deleted would also read as Walk-in, but validateCustomer
      // stops such a value being saved in the first place.)
      @EndUserText.label: 'Customer Name'
      case when cust.partner_name is null
           then cast( 'Walk-in' as abap.char( 60 ) )
           else cust.partner_name
      end               as CustomerName,

      // Sales period, split out here for the same reason the posting period
      // lives in ZI_ITS_JE_BASE: an aggregating view can only GROUP BY plain
      // field references, never expressions, so the year and month have to
      // already be fields by the time ZI_ITS_SALES_BY_BRANCH groups on them.
      //
      // ABAP CDS has no EXTRACT_YEAR / EXTRACT_MONTH for abap.dats. A DATS is
      // physically YYYYMMDD, so casting to CHAR(8) and slicing is the portable
      // way to get period keys; NUMC keeps them sorting with leading zeros.
      @EndUserText.label: 'Sales Year'
      cast( substring( cast( so.sales_date as abap.char( 8 ) ), 1, 4 ) as abap.numc( 4 ) ) as SalesYear,

      @EndUserText.label: 'Sales Month'
      cast( substring( cast( so.sales_date as abap.char( 8 ) ), 5, 2 ) as abap.numc( 2 ) ) as SalesMonth
}
