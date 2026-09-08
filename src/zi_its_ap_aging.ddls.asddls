
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'for aging PO'
@Metadata.allowExtensions: true

define view entity ZI_ITS_AP_AGING as select from zits_po
{
    key po_uuid
} // place holding
