CLASS lhc_Region DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Region RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Region~setDefaults.

    METHODS validateRegionID FOR VALIDATE ON SAVE
      IMPORTING keys FOR Region~validateRegionID.

    METHODS validateRegionName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Region~validateRegionName.

    METHODS validateCompany FOR VALIDATE ON SAVE
      IMPORTING keys FOR Region~validateCompany.

    METHODS validateManager FOR VALIDATE ON SAVE
      IMPORTING keys FOR Region~validateManager.

ENDCLASS.


CLASS lhc_Region IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - set default values on create
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_region IN LOCAL MODE
      ENTITY Region
        FIELDS ( IsActive )
        WITH CORRESPONDING #( keys )
      RESULT DATA(regions).

    DATA updates TYPE TABLE FOR UPDATE zi_its_region.

    LOOP AT regions INTO DATA(region).
      IF region-IsActive IS INITIAL.
        APPEND VALUE #( %tky     = region-%tky
                        IsActive = 'X' ) TO updates.
      ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_region IN LOCAL MODE
        ENTITY Region
          UPDATE FIELDS ( IsActive )
          WITH updates
        REPORTED DATA(modify_reported).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Region ID must exist and be unique
*--------------------------------------------------------------------*
  METHOD validateRegionID.

    READ ENTITIES OF zi_its_region IN LOCAL MODE
      ENTITY Region
        FIELDS ( RegionID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(regions).

    LOOP AT regions INTO DATA(region).

      IF region-RegionID IS INITIAL.
        APPEND VALUE #( %tky = region-%tky ) TO failed-region.
        APPEND VALUE #( %tky              = region-%tky
                        %element-RegionID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Region ID must be entered' )
                      ) TO reported-region.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_region
        FIELDS region_id
        WHERE region_id = @region-RegionID
        INTO @DATA(existing_id).

      IF existing_id IS NOT INITIAL.
        APPEND VALUE #( %tky = region-%tky ) TO failed-region.
        APPEND VALUE #( %tky              = region-%tky
                        %element-RegionID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Region ID already exists' )
                      ) TO reported-region.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Region Name must be entered
*--------------------------------------------------------------------*
  METHOD validateRegionName.

    READ ENTITIES OF zi_its_region IN LOCAL MODE
      ENTITY Region
        FIELDS ( RegionName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(regions).

    LOOP AT regions INTO DATA(region).

      IF region-RegionName IS INITIAL.
        APPEND VALUE #( %tky = region-%tky ) TO failed-region.
        APPEND VALUE #( %tky                = region-%tky
                        %element-RegionName = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Region Name must be entered' )
                      ) TO reported-region.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Company must be entered and must exist
*--------------------------------------------------------------------*
  METHOD validateCompany.

    READ ENTITIES OF zi_its_region IN LOCAL MODE
      ENTITY Region
        FIELDS ( CompanyID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(regions).

    LOOP AT regions INTO DATA(region).

      IF region-CompanyID IS INITIAL.
        APPEND VALUE #( %tky = region-%tky ) TO failed-region.
        APPEND VALUE #( %tky               = region-%tky
                        %element-CompanyID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Company must be entered' )
                      ) TO reported-region.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_company
        FIELDS company_id
        WHERE company_id = @region-CompanyID
        INTO @DATA(existing_company).

      IF existing_company IS INITIAL.
        APPEND VALUE #( %tky = region-%tky ) TO failed-region.
        APPEND VALUE #( %tky               = region-%tky
                        %element-CompanyID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Company does not exist' )
                      ) TO reported-region.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Region Manager, if entered, must be a valid employee
*--------------------------------------------------------------------*
  METHOD validateManager.

    READ ENTITIES OF zi_its_region IN LOCAL MODE
      ENTITY Region
        FIELDS ( RegionManagerID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(regions).

    LOOP AT regions INTO DATA(region).

      IF region-RegionManagerID IS INITIAL.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_employee
        FIELDS employee_id
        WHERE employee_id = @region-RegionManagerID
        INTO @DATA(existing_employee).

      IF existing_employee IS INITIAL.
        APPEND VALUE #( %tky = region-%tky ) TO failed-region.
        APPEND VALUE #( %tky                     = region-%tky
                        %element-RegionManagerID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Region manager must be a valid employee' )
                      ) TO reported-region.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
