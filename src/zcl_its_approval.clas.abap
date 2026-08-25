CLASS zcl_its_approval DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    CONSTANTS gc_branch_limit   TYPE p LENGTH 15 DECIMALS 2 VALUE '20000.00'.
    CONSTANTS gc_regional_limit TYPE p LENGTH 15 DECIMALS 2 VALUE '100000.00'.
    CONSTANTS gc_po_regional    TYPE p LENGTH 15 DECIMALS 2 VALUE '50000.00'.

    "--- SalesOrder: total < gc_branch_limit -> 0, up to gc_regional_limit -> 1, above -> 2 ---
    CLASS-METHODS get_required_level_so
      IMPORTING iv_amount       TYPE zits_so-total_amount
      RETURNING VALUE(rv_level) TYPE i.

    "--- PurchaseOrder: always needs approval - up to gc_po_regional -> 1, above -> 2 ---
    CLASS-METHODS get_required_level_po
      IMPORTING iv_amount       TYPE zits_po-total_cost
      RETURNING VALUE(rv_level) TYPE i.

    "--- can the given user approve a document of iv_required_level for iv_branch_id? ---
    CLASS-METHODS can_approve
      IMPORTING iv_user           TYPE string
                iv_branch_id      TYPE zits_branch-branch_id
                iv_required_level TYPE i
      RETURNING VALUE(rv_ok)      TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_its_approval IMPLEMENTATION.

  METHOD get_required_level_so.

    IF iv_amount > gc_regional_limit.
      rv_level = 2.
    ELSEIF iv_amount >= gc_branch_limit.
      rv_level = 1.
    ELSE.
      rv_level = 0.
    ENDIF.

  ENDMETHOD.


  METHOD get_required_level_po.

    IF iv_amount > gc_po_regional.
      rv_level = 2.
    ELSE.
      rv_level = 1.
    ENDIF.

  ENDMETHOD.


  METHOD can_approve.

    rv_ok = abap_false.

    DATA(lv_user) = to_upper( iv_user ).

    SELECT SINGLE FROM zits_employee
      FIELDS employee_id, role_code, branch_id, region_id
      WHERE upper( user_name ) = @lv_user
        AND is_active = 'X'
      INTO @DATA(ls_emp).

    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE iv_required_level.

      WHEN 1.
        "--- the branch manager of this exact branch ---
        IF ls_emp-role_code = 'M' AND ls_emp-branch_id = iv_branch_id.
          rv_ok = abap_true.
          RETURN.
        ENDIF.

        "--- a regional manager may also approve level 1 documents in their own region ---
        IF ls_emp-role_code = 'R'.
          SELECT SINGLE FROM zits_branch
            FIELDS branch_id
            WHERE branch_id = @iv_branch_id
              AND region_id = @ls_emp-region_id
            INTO @DATA(branch_in_region_l1).

          IF branch_in_region_l1 IS NOT INITIAL.
            rv_ok = abap_true.
          ENDIF.
        ENDIF.

      WHEN 2.
        "--- only the regional manager of the region that owns this branch - a branch manager may NOT approve level 2 ---
        IF ls_emp-role_code = 'R'.
          SELECT SINGLE FROM zits_branch
            FIELDS branch_id
            WHERE branch_id = @iv_branch_id
              AND region_id = @ls_emp-region_id
            INTO @DATA(branch_in_region_l2).

          IF branch_in_region_l2 IS NOT INITIAL.
            rv_ok = abap_true.
          ENDIF.
        ENDIF.

    ENDCASE.

  ENDMETHOD.

ENDCLASS.
