@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Sales Order - Base with computed fields'
define view entity ZI_ITS_SO_BASE
  as select from zits_so
{
  key so_uuid          as SOUUID,

      case overall_status
        when 'D' then 'Draft'
        when 'S' then 'Submitted'
        when 'P' then 'Pending Approval'
        when 'C' then 'Confirmed'
        when 'F' then 'Completed'
        when 'X' then 'Rejected'
        else ''
      end               as OverallStatusText,

      cast(
        case overall_status
          when 'F' then 3
          when 'C' then 3
          when 'P' then 2
          when 'X' then 1
          else 0
        end as abap.int1 ) as StatusCriticality,

      // Sales period, split out here for the same reason the posting period
      // lives in ZI_ITS_JE_BASE: an aggregating view can only GROUP BY plain
      // field references, never expressions, so the year and month have to
      // already be fields by the time ZI_ITS_SALES_BY_BRANCH groups on them.
      //
      // ABAP CDS has no EXTRACT_YEAR / EXTRACT_MONTH for abap.dats. A DATS is
      // physically YYYYMMDD, so casting to CHAR(8) and slicing is the portable
      // way to get period keys; NUMC keeps them sorting with leading zeros.
      @EndUserText.label: 'Sales Year'
      cast( substring( cast( sales_date as abap.char( 8 ) ), 1, 4 ) as abap.numc( 4 ) ) as SalesYear,

      @EndUserText.label: 'Sales Month'
      cast( substring( cast( sales_date as abap.char( 8 ) ), 5, 2 ) as abap.numc( 2 ) ) as SalesMonth
}
