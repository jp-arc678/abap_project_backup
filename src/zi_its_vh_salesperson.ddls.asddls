@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Salesperson'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ITS_VH_SALESPERSON
  as select from zits_employee
{
      @EndUserText.label: 'Salesperson ID'
  key employee_id   as EmployeeID,
      @EndUserText.label: 'Name'
      employee_name as EmployeeName
}
where role_code = 'S' and is_active = 'X'
