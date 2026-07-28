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
        end as abap.int1 ) as StatusCriticality
}
