@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee - Data Model View'
define root view entity ZI_ITS_EMPLOYEE
  as select from zits_employee
{
      @EndUserText.label: 'Employee ID'
  key employee_id           as EmployeeID,

      @EndUserText.label: 'Employee Name'
      employee_name         as EmployeeName,

      @EndUserText.label: 'Role'
      @ObjectModel.text.element: [ 'RoleName' ]
      role_code             as RoleCode,

      @EndUserText.label: 'Role Description'
      case role_code
        when 'M' then cast( 'Manager'         as abap.char( 20 ) )
        when 'S' then cast( 'Salesperson'     as abap.char( 20 ) )
        when 'W' then cast( 'Warehouse Staff' as abap.char( 20 ) )
        else          cast( 'Unknown'         as abap.char( 20 ) )
      end                   as RoleName,

      @EndUserText.label: 'System User'
      user_name             as UserName,

      @EndUserText.label: 'Active'
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
      last_changed_at       as LastChangedAt
}
