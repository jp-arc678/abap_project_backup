@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Customer'
@ObjectModel.resultSet.sizeCategory: #XS

// Customers only, so the picker on a sales order cannot offer a supplier.
// 'B' is included because a partner flagged as both buys as well as sells -
// the same rule validateSupplier applies on the purchase side, mirrored.
//
// Inactive partners are filtered out here but NOT in validateCustomer: a
// partner can be deactivated after an order was raised, and that must not
// make the old order un-saveable.
define view entity ZI_ITS_VH_CUSTOMER
  as select from zits_partner
{
      @EndUserText.label: 'Customer ID'
  key partner_id   as PartnerID,

      @EndUserText.label: 'Customer Name'
      partner_name as PartnerName,

      @EndUserText.label: 'Type'
      partner_type as PartnerType,

      @EndUserText.label: 'Phone'
      phone        as Phone
}
where ( partner_role = 'C' or partner_role = 'B' )
  and is_active = 'X'
