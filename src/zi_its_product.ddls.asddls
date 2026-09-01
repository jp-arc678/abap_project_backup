@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Product - Data Model View'
define root view entity ZI_ITS_PRODUCT
  as select from zits_product
  association [0..1] to I_Currency as _Currency on $projection.CurrencyCode = _Currency.Currency
{
      @EndUserText.label: 'Product ID'
  key product_id            as ProductID,

      @EndUserText.label: 'Product Name'
      product_name          as ProductName,

      @EndUserText.label: 'Category'
      category              as Category,

      @EndUserText.label: 'Brand'
      brand                 as Brand,

      @EndUserText.label: 'Description'
      description           as Description,

      @EndUserText.label: 'Sale Price'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      sale_price            as SalePrice,

      @EndUserText.label: 'Cost Price'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      cost_price            as CostPrice,

      @EndUserText.label: 'Currency'
      currency_code         as CurrencyCode,

      @EndUserText.label: 'Unit'
      unit                  as Unit,

      @EndUserText.label: 'Active'
      @Semantics.booleanIndicator: true
      is_active             as IsActive,

      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,

      @EndUserText.label: 'Last Changed By'
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,

      @EndUserText.label: 'Last Changed At'
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      @EndUserText.label: 'Last Changed At (Total)'
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _Currency
}
