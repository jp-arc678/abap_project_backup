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

      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZC_ITS_BRANCH', element: 'BranchID' } } ]
      BranchID,

      _Branch.BranchName as BranchName,

      @ObjectModel.text.element: [ 'RegionName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'ZI_ITS_VH_REGION', element: 'RegionID' },
                                            useForValidation: true } ]
      RegionID,

      _Region.RegionName as RegionName,

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
