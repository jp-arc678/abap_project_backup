CLASS lhc_CostCenter DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR CostCenter RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR CostCenter~setDefaults.

    METHODS validateCostCenterID FOR VALIDATE ON SAVE
      IMPORTING keys FOR CostCenter~validateCostCenterID.

    METHODS validateCCName FOR VALIDATE ON SAVE
      IMPORTING keys FOR CostCenter~validateCCName.

    METHODS validateBranch FOR VALIDATE ON SAVE
      IMPORTING keys FOR CostCenter~validateBranch.

    METHODS validateCCType FOR VALIDATE ON SAVE
      IMPORTING keys FOR CostCenter~validateCCType.

ENDCLASS.


CLASS lhc_CostCenter IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - set default values on create
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_costctr IN LOCAL MODE
      ENTITY CostCenter
        FIELDS ( IsActive )
        WITH CORRESPONDING #( keys )
      RESULT DATA(cost_centers).

    DATA updates TYPE TABLE FOR UPDATE zi_its_costctr.

    LOOP AT cost_centers INTO DATA(cost_center).
      IF cost_center-IsActive IS INITIAL.
        APPEND VALUE #( %tky     = cost_center-%tky
                        IsActive = 'X' ) TO updates.
      ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_costctr IN LOCAL MODE
        ENTITY CostCenter
          UPDATE FIELDS ( IsActive )
          WITH updates
        REPORTED DATA(modify_reported).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Cost Center ID must exist and be unique
*--------------------------------------------------------------------*
  METHOD validateCostCenterID.

    READ ENTITIES OF zi_its_costctr IN LOCAL MODE
      ENTITY CostCenter
        FIELDS ( CostCenterID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(cost_centers).

    LOOP AT cost_centers INTO DATA(cost_center).

      IF cost_center-CostCenterID IS INITIAL.
        APPEND VALUE #( %tky = cost_center-%tky ) TO failed-costcenter.
        APPEND VALUE #( %tky                  = cost_center-%tky
                        %element-CostCenterID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Cost Center ID must be entered' )
                      ) TO reported-costcenter.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_costctr
        FIELDS cost_center_id
        WHERE cost_center_id = @cost_center-CostCenterID
        INTO @DATA(existing_id).

      IF existing_id IS NOT INITIAL.
        APPEND VALUE #( %tky = cost_center-%tky ) TO failed-costcenter.
        APPEND VALUE #( %tky                  = cost_center-%tky
                        %element-CostCenterID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Cost Center ID already exists' )
                      ) TO reported-costcenter.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Cost Center Name must be entered
*--------------------------------------------------------------------*
  METHOD validateCCName.

    READ ENTITIES OF zi_its_costctr IN LOCAL MODE
      ENTITY CostCenter
        FIELDS ( CCName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(cost_centers).

    LOOP AT cost_centers INTO DATA(cost_center).

      IF cost_center-CCName IS INITIAL.
        APPEND VALUE #( %tky = cost_center-%tky ) TO failed-costcenter.
        APPEND VALUE #( %tky            = cost_center-%tky
                        %element-CCName = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Cost Center Name must be entered' )
                      ) TO reported-costcenter.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Branch must be entered and must exist
*--------------------------------------------------------------------*
  METHOD validateBranch.

    READ ENTITIES OF zi_its_costctr IN LOCAL MODE
      ENTITY CostCenter
        FIELDS ( BranchID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(cost_centers).

    LOOP AT cost_centers INTO DATA(cost_center).

      IF cost_center-BranchID IS INITIAL.
        APPEND VALUE #( %tky = cost_center-%tky ) TO failed-costcenter.
        APPEND VALUE #( %tky              = cost_center-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch must be entered' )
                      ) TO reported-costcenter.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_branch
        FIELDS branch_id
        WHERE branch_id = @cost_center-BranchID
        INTO @DATA(existing_branch).

      IF existing_branch IS INITIAL.
        APPEND VALUE #( %tky = cost_center-%tky ) TO failed-costcenter.
        APPEND VALUE #( %tky              = cost_center-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch does not exist' )
                      ) TO reported-costcenter.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Cost Center Type must be S (Sales), W (Warehouse) or A (Admin)
*--------------------------------------------------------------------*
  METHOD validateCCType.

    READ ENTITIES OF zi_its_costctr IN LOCAL MODE
      ENTITY CostCenter
        FIELDS ( CCType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(cost_centers).

    LOOP AT cost_centers INTO DATA(cost_center).

      IF cost_center-CCType <> 'S' AND cost_center-CCType <> 'W' AND cost_center-CCType <> 'A'.
        APPEND VALUE #( %tky = cost_center-%tky ) TO failed-costcenter.
        APPEND VALUE #( %tky            = cost_center-%tky
                        %element-CCType = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Cost Center Type must be S (Sales), W (Warehouse) or A (Admin)' )
                      ) TO reported-costcenter.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
