@EndUserText.label: 'Employee - Projection View'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_ITS_EMPLOYEE
  provider contract transactional_query
  as projection on ZI_ITS_EMPLOYEE
{
      @Search.defaultSearchElement: true
  key EmployeeID,

      @Search.defaultSearchElement: true
      EmployeeName,

      RoleCode,
      RoleName,

      UserName,
      IsActive,

      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt
}
