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
        end as abap.int1 ) as StatusCriticality
}
