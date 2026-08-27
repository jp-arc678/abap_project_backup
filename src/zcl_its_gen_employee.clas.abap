CLASS zcl_its_gen_employee DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_its_gen_employee IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    DATA lt_employee TYPE STANDARD TABLE OF zits_employee.

    GET TIME STAMP FIELD DATA(lv_now).
    DATA(lv_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    "--- keep whichever employee currently holds the logged-in user's persona ---
    "    (so the persona-switcher script keeps working after this regenerates the table)
    SELECT SINGLE FROM zits_employee
      FIELDS employee_id, branch_id, role_code, is_active
      WHERE upper( user_name ) = @lv_user
      INTO @DATA(ls_current_holder).

    DELETE FROM zits_employee.

*--------------------------------------------------------------------*
* role_code: M = Branch Manager     S = Salesperson
*            R = Regional Manager   W = Warehouse Staff
*            A = Accounting
*
* Regional managers are seated at a branch; the region they cover is
* derived from that branch (BR01 -> CEN, BR03 -> NOR). This keeps the
* employee table unchanged - no region_id column needed.
*
* Accounting sits at head office and has no branch.
*--------------------------------------------------------------------*
    lt_employee = VALUE #(
      is_active = 'X'
      user_name = ''

      "--- Siam Paragon (BR01) ---
      ( employee_id = 'E0001' employee_name = 'Somchai Wattana'    branch_id = 'BR01' role_code = 'M' )
      ( employee_id = 'E0002' employee_name = 'Nattaya Sombat'     branch_id = 'BR01' role_code = 'S' )
      ( employee_id = 'E0003' employee_name = 'Kanya Rungrot'      branch_id = 'BR01' role_code = 'W' )

      "--- Central Ladprao (BR02) ---
      ( employee_id = 'E0004' employee_name = 'Preecha Boonmee'    branch_id = 'BR02' role_code = 'M' )
      ( employee_id = 'E0005' employee_name = 'Peerapat Chai'      branch_id = 'BR02' role_code = 'S' )
      ( employee_id = 'E0006' employee_name = 'Suda Meechan'       branch_id = 'BR02' role_code = 'W' )

      "--- Central Chiang Mai (BR03) ---
      ( employee_id = 'E0007' employee_name = 'Anurak Sirisak'     branch_id = 'BR03' role_code = 'M' )
      ( employee_id = 'E0008' employee_name = 'Waraporn Intachai'  branch_id = 'BR03' role_code = 'S' )
      ( employee_id = 'E0009' employee_name = 'Chatchai Panyawong' branch_id = 'BR03' role_code = 'W' )

      "--- Regional management ---
      ( employee_id = 'E0010' employee_name = 'Wirat Charoensuk'
        branch_id = '' region_id = 'CEN' role_code = 'R' )
      ( employee_id = 'E0011' employee_name = 'Pimchanok Saelim'
        branch_id = '' region_id = 'NOR' role_code = 'R' )

      "--- Head office ---
      ( employee_id = 'E0012' employee_name = 'Thanaporn Kittisak'
        branch_id = '' region_id = ''    role_code = 'A' )
    ).

    "--- rebind the logged-in user's persona to the same employee slot it had before,
    "    falling back to E0001 if this is the first run ---
    DATA(lv_holder_id) = COND #( WHEN ls_current_holder-employee_id IS NOT INITIAL
                                  THEN ls_current_holder-employee_id
                                  ELSE 'E0001' ).

    LOOP AT lt_employee ASSIGNING FIELD-SYMBOL(<ls_emp>).
      <ls_emp>-created_by            = lv_user.
      <ls_emp>-created_at            = lv_now.
      <ls_emp>-local_last_changed_by = lv_user.
      <ls_emp>-local_last_changed_at = lv_now.
      <ls_emp>-last_changed_at       = lv_now.

      IF <ls_emp>-employee_id = lv_holder_id.
        <ls_emp>-user_name = lv_user.
        "--- if we had a previous persona for this user, keep its branch/role too ---
        IF ls_current_holder-employee_id IS NOT INITIAL.
          <ls_emp>-branch_id = ls_current_holder-branch_id.
          <ls_emp>-role_code = ls_current_holder-role_code.
          <ls_emp>-is_active = ls_current_holder-is_active.
        ENDIF.
      ENDIF.
    ENDLOOP.

    INSERT zits_employee FROM TABLE @lt_employee.

*--------------------------------------------------------------------*
* Wire the managers into the organisational master data
*--------------------------------------------------------------------*
    UPDATE zits_branch SET branch_manager_id = 'E0001' WHERE branch_id = 'BR01'.
    UPDATE zits_branch SET branch_manager_id = 'E0004' WHERE branch_id = 'BR02'.
    UPDATE zits_branch SET branch_manager_id = 'E0007' WHERE branch_id = 'BR03'.

    UPDATE zits_region SET region_manager_id = 'E0010' WHERE region_id = 'CEN'.
    UPDATE zits_region SET region_manager_id = 'E0011' WHERE region_id = 'NOR'.

    COMMIT WORK.

*--------------------------------------------------------------------*
    out->write( |[ITZone] Employees created: { lines( lt_employee ) }| ).
    out->write( |[ITZone] Branch managers  : E0001 / E0004 / E0007| ).
    out->write( |[ITZone] Region managers  : E0010 (CEN) / E0011 (NOR)| ).
    out->write( |[ITZone] Accounting       : E0012 (head office)| ).
    out->write( |[ITZone] Your login ({ lv_user }) is bound to { lv_holder_id }| ).
    out->write( |[ITZone] Use zcl_its_switch_persona to change branch/role.| ).

  ENDMETHOD.
ENDCLASS.

