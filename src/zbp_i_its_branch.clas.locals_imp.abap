CLASS lhc_Branch DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Branch RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Branch~setDefaults.

    METHODS validateBranchID FOR VALIDATE ON SAVE
      IMPORTING keys FOR Branch~validateBranchID.

    METHODS validateBranchName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Branch~validateBranchName.

    METHODS validateRegion FOR VALIDATE ON SAVE
      IMPORTING keys FOR Branch~validateRegion.

    METHODS validateManager FOR VALIDATE ON SAVE
      IMPORTING keys FOR Branch~validateManager.

ENDCLASS.


CLASS lhc_Branch IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - set default values on create
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_branch IN LOCAL MODE
      ENTITY Branch
        FIELDS ( IsActive )
        WITH CORRESPONDING #( keys )
      RESULT DATA(branches).

    DATA updates TYPE TABLE FOR UPDATE zi_its_branch.

    LOOP AT branches INTO DATA(branch).
      IF branch-IsActive IS INITIAL.
        APPEND VALUE #( %tky     = branch-%tky
                        IsActive = 'X' ) TO updates.
      ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_branch IN LOCAL MODE
        ENTITY Branch
          UPDATE FIELDS ( IsActive )
          WITH updates
        REPORTED DATA(modify_reported).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Branch ID must exist and be unique
*--------------------------------------------------------------------*
  METHOD validateBranchID.

    READ ENTITIES OF zi_its_branch IN LOCAL MODE
      ENTITY Branch
        FIELDS ( BranchID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(branches).

    LOOP AT branches INTO DATA(branch).

      IF branch-BranchID IS INITIAL.
        APPEND VALUE #( %tky = branch-%tky ) TO failed-branch.
        APPEND VALUE #( %tky              = branch-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch ID must be entered' )
                      ) TO reported-branch.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_branch
        FIELDS branch_id
        WHERE branch_id = @branch-BranchID
        INTO @DATA(existing_id).

      IF existing_id IS NOT INITIAL.
        APPEND VALUE #( %tky = branch-%tky ) TO failed-branch.
        APPEND VALUE #( %tky              = branch-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch ID already exists' )
                      ) TO reported-branch.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Branch Name must be entered
*--------------------------------------------------------------------*
  METHOD validateBranchName.

    READ ENTITIES OF zi_its_branch IN LOCAL MODE
      ENTITY Branch
        FIELDS ( BranchName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(branches).

    LOOP AT branches INTO DATA(branch).

      IF branch-BranchName IS INITIAL.
        APPEND VALUE #( %tky = branch-%tky ) TO failed-branch.
        APPEND VALUE #( %tky                = branch-%tky
                        %element-BranchName = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch Name must be entered' )
                      ) TO reported-branch.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Region must be entered and must exist
*--------------------------------------------------------------------*
  METHOD validateRegion.

    READ ENTITIES OF zi_its_branch IN LOCAL MODE
      ENTITY Branch
        FIELDS ( RegionID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(branches).

    LOOP AT branches INTO DATA(branch).

      IF branch-RegionID IS INITIAL.
        APPEND VALUE #( %tky = branch-%tky ) TO failed-branch.
        APPEND VALUE #( %tky              = branch-%tky
                        %element-RegionID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Region must be entered' )
                      ) TO reported-branch.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_region
        FIELDS region_id
        WHERE region_id = @branch-RegionID
        INTO @DATA(existing_region).

      IF existing_region IS INITIAL.
        APPEND VALUE #( %tky = branch-%tky ) TO failed-branch.
        APPEND VALUE #( %tky              = branch-%tky
                        %element-RegionID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Region does not exist' )
                      ) TO reported-branch.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Branch Manager, if entered, must be a valid employee
*--------------------------------------------------------------------*
  METHOD validateManager.

    READ ENTITIES OF zi_its_branch IN LOCAL MODE
      ENTITY Branch
        FIELDS ( BranchManagerID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(branches).

    LOOP AT branches INTO DATA(branch).

      IF branch-BranchManagerID IS INITIAL.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_employee
        FIELDS employee_id
        WHERE employee_id = @branch-BranchManagerID
        INTO @DATA(existing_employee).

      IF existing_employee IS INITIAL.
        APPEND VALUE #( %tky = branch-%tky ) TO failed-branch.
        APPEND VALUE #( %tky                     = branch-%tky
                        %element-BranchManagerID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch manager must be a valid employee' )
                      ) TO reported-branch.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
