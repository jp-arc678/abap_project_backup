CLASS zcl_its_switch_persona DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

    "--- Hand the one technical user to a different employee record.
    "    S / W / M match on branch, R matches on region, A on role alone.
    "    Returns the employee that now holds the user, or blank when no
    "    active employee matched. COMMITs, so never call it while a RAP
    "    transaction is open - commit or roll back the EML work first. ---
    CLASS-METHODS switch_to
      IMPORTING iv_role            TYPE zits_employee-role_code
                iv_branch_id       TYPE zits_employee-branch_id OPTIONAL
                iv_region_id       TYPE zits_employee-region_id OPTIONAL
      RETURNING VALUE(rv_employee) TYPE zits_employee-employee_id.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_its_switch_persona IMPLEMENTATION.

  METHOD switch_to.

    DATA(lv_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    "--- release the technical user from every employee record first, so
    "    only one employee ever owns it (avoids an ambiguous SELECT SINGLE) ---
    UPDATE zits_employee
      SET user_name = ''
      WHERE upper( user_name ) = @lv_user.

    SELECT SINGLE FROM zits_employee
      FIELDS employee_id
      WHERE role_code = @iv_role
        AND is_active = 'X'
        AND ( ( @iv_role = 'R' AND region_id = @iv_region_id )
           OR ( @iv_role = 'A' )
           OR ( @iv_role <> 'R' AND @iv_role <> 'A' AND branch_id = @iv_branch_id ) )
      INTO @DATA(lv_target).

    IF sy-subrc <> 0.
      "--- nobody matched: leave the user detached rather than guessing,
      "    and let the caller decide what that means ---
      COMMIT WORK.
      CLEAR rv_employee.
      RETURN.
    ENDIF.

    UPDATE zits_employee
      SET user_name = @lv_user
      WHERE employee_id = @lv_target.

    COMMIT WORK.

    rv_employee = lv_target.

  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.

************************************************************************
*  PERSONA SWITCHER — for testing role, branch and region behaviour
*
*  The trial system has only one real user, so this class re-points that
*  user at a different employee record. Uncomment ONE line in the block
*  below, run with F9, then reload the Fiori app.
*
*  role_code : M = Branch Manager      branch_id : BR01 = Siam Paragon
*              R = Regional Manager                BR02 = Central Ladprao
*              S = Salesperson                     BR03 = Central Chiang Mai
*              W = Warehouse Staff     region_id : CEN  = Central Region
*              A = Accounting                      NOR  = Northern Region
*
*  S / W / M match on branch_id. R matches on region_id. A matches on
*  role only (there is exactly one accounting employee, at head office).
************************************************************************

    "--- the technical user actually logged on ---
    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    DATA lv_role   TYPE zits_employee-role_code.
    DATA lv_branch TYPE zits_employee-branch_id.
    DATA lv_region TYPE zits_employee-region_id.
    DATA lv_label  TYPE string.

*======================================================================*
*  CHOOSE ONE — uncomment exactly one block
*======================================================================*

*--- Salesperson --------------------------------------------------------
*    lv_role = 'S'.  lv_branch = 'BR01'.  lv_label = 'Salesperson @ Siam Paragon'.
*   lv_role = 'S'.  lv_branch = 'BR02'.  lv_label = 'Salesperson @ Central Ladprao'.
*   lv_role = 'S'.  lv_branch = 'BR03'.  lv_label = 'Salesperson @ Chiang Mai'.

*--- Warehouse staff ----------------------------------------------------
*   lv_role = 'W'.  lv_branch = 'BR01'.  lv_label = 'Warehouse @ Siam Paragon'.
*   lv_role = 'W'.  lv_branch = 'BR02'.  lv_label = 'Warehouse @ Central Ladprao'.
*   lv_role = 'W'.  lv_branch = 'BR03'.  lv_label = 'Warehouse @ Chiang Mai'.

*--- Branch manager (approves branch-level orders) ----------------------
*   lv_role = 'M'.  lv_branch = 'BR01'.  lv_label = 'Branch Manager @ Siam Paragon'.
*   lv_role = 'M'.  lv_branch = 'BR02'.  lv_label = 'Branch Manager @ Central Ladprao'.
*  lv_role = 'M'.  lv_branch = 'BR03'.  lv_label = 'Branch Manager @ Chiang Mai'.

*--- Regional manager (approves high-value orders, whole region) --------
*   lv_role = 'R'.  lv_region = 'CEN'.  lv_label = 'Regional Manager (Central)'.
*   lv_role = 'R'.  lv_region = 'NOR'.  lv_label = 'Regional Manager (North)'.

*--- Accounting (head office, no branch, no region) ---------------------
   lv_role = 'A'.  lv_label = 'Accounting @ Head Office'.

*======================================================================*

    "--- the actual switching lives in switch_to( ) so the data generators
    "    can reuse it instead of duplicating the UPDATE logic ---
    DATA(lv_employee) = switch_to( iv_role      = lv_role
                                   iv_branch_id = lv_branch
                                   iv_region_id = lv_region ).

    IF lv_employee IS INITIAL.
      out->write( |[SWITCH] FAILED - no active employee matches role { lv_role }| &&
                  |{ COND #( WHEN lv_role = 'R' THEN | region { lv_region }|
                            WHEN lv_role = 'A' THEN ''
                            ELSE | branch { lv_branch }| ) }| ).
      out->write( |[SWITCH] Create one first, or pick another line.| ).
      RETURN.
    ENDIF.

    SELECT SINGLE FROM zits_employee
      FIELDS employee_id, employee_name
      WHERE employee_id = @lv_employee
      INTO @DATA(ls_target).

*----------------------------------------------------------------------*
*  Report what happened
*----------------------------------------------------------------------*
    out->write( |[SWITCH] You are now: { lv_label }| ).
    out->write( |[SWITCH] Employee   : { ls_target-employee_id } - { ls_target-employee_name }| ).
    out->write( |[SWITCH] Role       : { lv_role }| ).
    out->write( |[SWITCH] Scope      : { COND #( WHEN lv_role = 'R' THEN |region { lv_region }|
                                                 WHEN lv_role = 'A' THEN 'whole company'
                                                 ELSE |branch { lv_branch }| ) }| ).
    out->write( |[SWITCH] Technical  : { current_user }| ).
    out->write( || ).
    out->write( |[SWITCH] Reload the Fiori app to see the change.| ).

    "--- show the whole roster so it is obvious who holds the user now ---
    SELECT FROM zits_employee
      FIELDS employee_id, employee_name, role_code, branch_id, region_id, user_name
      WHERE is_active = 'X'
      ORDER BY branch_id, region_id, role_code, employee_id
      INTO TABLE @DATA(lt_roster).

    out->write( || ).
    out->write( |--- Active employees -----------------------------------| ).
    LOOP AT lt_roster INTO DATA(ls_row).
      DATA(lv_mark) = COND string( WHEN to_upper( ls_row-user_name ) = current_user
                                   THEN ' <== YOU' ELSE '' ).
      DATA(lv_scope) = COND string( WHEN ls_row-branch_id IS NOT INITIAL THEN ls_row-branch_id
                                    WHEN ls_row-region_id IS NOT INITIAL THEN |R:{ ls_row-region_id }|
                                    ELSE 'HQ  ' ).
      out->write( |{ ls_row-employee_id }{ ls_row-role_code } | && |{ lv_scope } | &&
                  |{ ls_row-employee_name }{ lv_mark }| ).
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
