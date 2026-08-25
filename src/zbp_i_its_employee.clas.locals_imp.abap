CLASS lhc_Employee DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Employee RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Employee~setDefaults.

    METHODS validateEmployeeID FOR VALIDATE ON SAVE
      IMPORTING keys FOR Employee~validateEmployeeID.

    METHODS validateRole FOR VALIDATE ON SAVE
      IMPORTING keys FOR Employee~validateRole.

    METHODS validateUserName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Employee~validateUserName.

    METHODS validateScope FOR VALIDATE ON SAVE
      IMPORTING keys FOR Employee~validateScope.

ENDCLASS.


CLASS lhc_Employee IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - default values
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_employee IN LOCAL MODE
      ENTITY Employee
        FIELDS ( IsActive )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    DATA updates TYPE TABLE FOR UPDATE zi_its_employee.

    LOOP AT employees INTO DATA(employee).
      IF employee-IsActive IS INITIAL.
        APPEND VALUE #( %tky     = employee-%tky
                        IsActive = 'X' ) TO updates.
      ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_employee IN LOCAL MODE
        ENTITY Employee
          UPDATE FIELDS ( IsActive )
          WITH updates
        REPORTED DATA(modify_reported).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Employee ID must exist and be unique
*--------------------------------------------------------------------*
  METHOD validateEmployeeID.

    READ ENTITIES OF zi_its_employee IN LOCAL MODE
      ENTITY Employee
        FIELDS ( EmployeeID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    LOOP AT employees INTO DATA(employee).

      IF employee-EmployeeID IS INITIAL.
        APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
        APPEND VALUE #( %tky                = employee-%tky
                        %element-EmployeeID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Employee ID must be entered' )
                      ) TO reported-employee.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_employee
        FIELDS employee_id
        WHERE employee_id = @employee-EmployeeID
        INTO @DATA(existing_id).

      IF existing_id IS NOT INITIAL.
        APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
        APPEND VALUE #( %tky                = employee-%tky
                        %element-EmployeeID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Employee ID already exists' )
                      ) TO reported-employee.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - role must be valid, only ONE active manager allowed
*--------------------------------------------------------------------*
  METHOD validateRole.

    READ ENTITIES OF zi_its_employee IN LOCAL MODE
      ENTITY Employee
        FIELDS ( EmployeeID RoleCode IsActive )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    LOOP AT employees INTO DATA(employee).

      "--- allowed values ---
      IF employee-RoleCode <> 'M'
     AND employee-RoleCode <> 'S'
     AND employee-RoleCode <> 'W'
     AND employee-RoleCode <> 'R'
     AND employee-RoleCode <> 'A'.
        APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
        APPEND VALUE #( %tky              = employee-%tky
                        %element-RoleCode = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Role must be M, S, W, R or A' )
                      ) TO reported-employee.
        CONTINUE.
      ENDIF.

      "--- only one active manager in the shop ---
      IF employee-RoleCode = 'M' AND employee-IsActive = 'X'.

        SELECT SINGLE FROM zits_employee
          FIELDS employee_id
          WHERE role_code   = 'M'
            AND is_active   = 'X'
            AND employee_id <> @employee-EmployeeID
          INTO @DATA(other_manager).

        IF other_manager IS NOT INITIAL.
          APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
          APPEND VALUE #( %tky              = employee-%tky
                          %element-RoleCode = if_abap_behv=>mk-on
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'An active manager already exists in this shop' )
                        ) TO reported-employee.
        ENDIF.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - system user must be filled and unique
*--------------------------------------------------------------------*
  METHOD validateUserName.

    READ ENTITIES OF zi_its_employee IN LOCAL MODE
      ENTITY Employee
        FIELDS ( EmployeeID UserName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    LOOP AT employees INTO DATA(employee).

      IF employee-UserName IS INITIAL.
        APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
        APPEND VALUE #( %tky              = employee-%tky
                        %element-UserName = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'System user must be entered' )
                      ) TO reported-employee.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_employee
        FIELDS employee_id
        WHERE user_name   = @employee-UserName
          AND employee_id <> @employee-EmployeeID
        INTO @DATA(other_employee).

      IF other_employee IS NOT INITIAL.
        APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
        APPEND VALUE #( %tky              = employee-%tky
                        %element-UserName = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'This system user is already assigned to another employee' )
                      ) TO reported-employee.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - authorization scope: exactly one of Branch/Region,
* matching the role (S/W/M -> branch only, R -> region only, A -> neither)
*--------------------------------------------------------------------*
  METHOD validateScope.

    READ ENTITIES OF zi_its_employee IN LOCAL MODE
      ENTITY Employee
        FIELDS ( RoleCode BranchID RegionID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(employees).

    LOOP AT employees INTO DATA(employee).

      CASE employee-RoleCode.

        WHEN 'S' OR 'W' OR 'M'.

          IF employee-BranchID IS INITIAL.
            APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
            APPEND VALUE #( %tky              = employee-%tky
                            %element-BranchID = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Branch is required for this role' )
                          ) TO reported-employee.
            CONTINUE.
          ENDIF.

          IF employee-RegionID IS NOT INITIAL.
            APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
            APPEND VALUE #( %tky              = employee-%tky
                            %element-RegionID = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Region must be empty for a branch role' )
                          ) TO reported-employee.
            CONTINUE.
          ENDIF.

          SELECT SINGLE FROM zits_branch
            FIELDS branch_id
            WHERE branch_id = @employee-BranchID
              AND is_active = 'X'
            INTO @DATA(valid_branch).

          IF valid_branch IS INITIAL.
            APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
            APPEND VALUE #( %tky              = employee-%tky
                            %element-BranchID = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Branch is not valid or inactive' )
                          ) TO reported-employee.
          ENDIF.

        WHEN 'R'.

          IF employee-RegionID IS INITIAL.
            APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
            APPEND VALUE #( %tky              = employee-%tky
                            %element-RegionID = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Region is required for a regional manager' )
                          ) TO reported-employee.
            CONTINUE.
          ENDIF.

          IF employee-BranchID IS NOT INITIAL.
            APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
            APPEND VALUE #( %tky              = employee-%tky
                            %element-BranchID = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Branch must be empty for a regional manager' )
                          ) TO reported-employee.
            CONTINUE.
          ENDIF.

          SELECT SINGLE FROM zits_region
            FIELDS region_id
            WHERE region_id = @employee-RegionID
              AND is_active = 'X'
            INTO @DATA(valid_region).

          IF valid_region IS INITIAL.
            APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
            APPEND VALUE #( %tky              = employee-%tky
                            %element-RegionID = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Region is not valid or inactive' )
                          ) TO reported-employee.
          ENDIF.

        WHEN 'A'.

          IF employee-BranchID IS NOT INITIAL OR employee-RegionID IS NOT INITIAL.
            APPEND VALUE #( %tky = employee-%tky ) TO failed-employee.
            APPEND VALUE #( %tky              = employee-%tky
                            %element-BranchID = if_abap_behv=>mk-on
                            %element-RegionID = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'Accounting must have no branch and no region' )
                          ) TO reported-employee.
          ENDIF.

      ENDCASE.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
