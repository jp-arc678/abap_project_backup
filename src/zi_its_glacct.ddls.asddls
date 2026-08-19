
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'data def for gl account'

define root view entity ZI_ITS_GLACCT as select from zits_glacct
{
    key gl_account as GlAccount,
    account_name as AccountName,
    account_type as AccountType,
    account_group as AccountGroup,
    normal_balance as NormalBalance,
    is_active as IsActive,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt
}
