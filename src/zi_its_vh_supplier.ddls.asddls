@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Supplier'
@ObjectModel.resultSet.sizeCategory: #XS

// Suppliers only, so the picker on a purchase order cannot offer a
// customer. Mirror of ZI_ITS_VH_CUSTOMER; 'B' is included because a
// partner flagged as both sells as well as buys.
//
// Inactive partners are filtered out here but NOT in validateSupplier: a
// partner can be deactivated after an order was raised, and that must not
// make the old order un-saveable.
define view entity ZI_ITS_VH_SUPPLIER
  as select from zits_partner
{
      @EndUserText.label: 'Supplier ID'
  key partner_id   as PartnerID,

      @EndUserText.label: 'Supplier Name'
      partner_name as PartnerName,

      @EndUserText.label: 'Type'
      partner_type as PartnerType,

      @EndUserText.label: 'Phone'
      phone        as Phone
}
where ( partner_role = 'S' or partner_role = 'B' )
  and is_active = 'X'
