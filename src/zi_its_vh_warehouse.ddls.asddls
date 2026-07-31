@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help - Warehouse Staff'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_ITS_VH_WAREHOUSE
  as select from zits_employee
{
      @EndUserText.label: 'Warehouse Staff ID'
  key employee_id   as EmployeeID,
      @EndUserText.label: 'Name'
      employee_name as EmployeeName
}
where role_code = 'W' and is_active = 'X'
