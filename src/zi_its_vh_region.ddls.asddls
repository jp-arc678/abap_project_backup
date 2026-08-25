
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'value help for region'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_ITS_VH_REGION as select from zits_region
{
    key region_id
} 
