CLASS zcl_its_gl_mapping DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "--- balance sheet ---
    CONSTANTS gc_cash      TYPE zits_glacct-gl_account VALUE '100000'.  "Cash
    CONSTANTS gc_bank      TYPE zits_glacct-gl_account VALUE '102000'.  "Bank
    CONSTANTS gc_inventory TYPE zits_glacct-gl_account VALUE '130000'.  "Inventory
    CONSTANTS gc_payables  TYPE zits_glacct-gl_account VALUE '201000'.  "Accounts Payable

    "--- profit and loss ---
    CONSTANTS gc_revenue   TYPE zits_glacct-gl_account VALUE '400000'.  "Sales Revenue
    CONSTANTS gc_cogs      TYPE zits_glacct-gl_account VALUE '500000'.  "Cost of Goods Sold

    "--- cost center type that carries a branch's own postings ---
    CONSTANTS gc_cc_type_sales TYPE zits_costctr-cc_type VALUE 'S'.

    "--- which account the money lands in when a sale is completed ---
    "    C = cash, R = credit card, T = transfer
    CLASS-METHODS get_sales_debit_account
      IMPORTING iv_payment_method TYPE zits_so-payment_method
      RETURNING VALUE(rv_account) TYPE zits_glacct-gl_account.

    "--- the cost center every posting of this branch is booked against.
    "    Returns empty when the branch has none - the caller decides what
    "    that means (both order flows treat it as a hard failure). ---
    CLASS-METHODS get_cost_center_for_branch
      IMPORTING iv_branch_id          TYPE zits_branch-branch_id
      RETURNING VALUE(rv_cost_center) TYPE zits_costctr-cost_center_id.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_its_gl_mapping IMPLEMENTATION.

  METHOD get_sales_debit_account.

    CASE iv_payment_method.
      WHEN 'R' OR 'T'.
        rv_account = gc_bank.
      WHEN OTHERS.
        "--- cash is the safe default; an unknown code must not fail a sale ---
        rv_account = gc_cash.
    ENDCASE.

  ENDMETHOD.


  METHOD get_cost_center_for_branch.

    SELECT SINGLE FROM zits_costctr
      FIELDS cost_center_id
      WHERE branch_id = @iv_branch_id
        AND cc_type   = @gc_cc_type_sales
        AND is_active = 'X'
      INTO @rv_cost_center.

    IF sy-subrc <> 0.
      CLEAR rv_cost_center.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
