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

    "--- and which account the money leaves from when a supplier is paid.
    "    Deliberately the mirror image of get_sales_debit_account rather
    "    than a fixed bank account: the arrangement is agreed with the
    "    supplier when the order is raised and stored on the header, so a
    "    cash purchase really does draw on the till. ---
    CLASS-METHODS get_payment_credit_account
      IMPORTING iv_payment_method TYPE zits_po-payment_method
      RETURNING VALUE(rv_account) TYPE zits_glacct-gl_account.

    "--- how long the supplier gives us to pay. 'CASH' means settle at
    "    goods receipt; anything else is treated as credit, so an unknown
    "    or missing term never blocks a receipt - it just creates a
    "    payable due immediately. ---
    CLASS-METHODS get_credit_days
      IMPORTING iv_payment_terms TYPE zits_partner-payment_terms
      RETURNING VALUE(rv_days)   TYPE i.

    CONSTANTS gc_terms_cash TYPE zits_partner-payment_terms VALUE 'CASH'.

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


  METHOD get_payment_credit_account.

    CASE iv_payment_method.
      WHEN 'R' OR 'T'.
        rv_account = gc_bank.
      WHEN OTHERS.
        "--- cash is the safe default; an unknown code must not block a
        "    payment on an order that was already approved and received ---
        rv_account = gc_cash.
    ENDCASE.

  ENDMETHOD.


  METHOD get_credit_days.

    CASE iv_payment_terms.
      WHEN 'N30'.
        rv_days = 30.
      WHEN 'N60'.
        rv_days = 60.
      WHEN OTHERS.
        "--- 'CASH' and anything unrecognised: nothing owed beyond today ---
        rv_days = 0.
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
