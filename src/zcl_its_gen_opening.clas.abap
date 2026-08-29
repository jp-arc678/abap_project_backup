CLASS zcl_its_gen_opening DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.

    "--- cash opening balance per branch, THB ---
    CONSTANTS gc_cash_br01 TYPE zits_jeitem-amount VALUE '500000.00'.
    CONSTANTS gc_cash_br02 TYPE zits_jeitem-amount VALUE '400000.00'.
    CONSTANTS gc_cash_br03 TYPE zits_jeitem-amount VALUE '300000.00'.

    "--- accounts seeded by ZCL_ITS_GEN_MASTER ---
    CONSTANTS gc_acct_cash   TYPE zits_glacct-gl_account VALUE '100000'.
    CONSTANTS gc_acct_invty  TYPE zits_glacct-gl_account VALUE '130000'.
    CONSTANTS gc_acct_equity TYPE zits_glacct-gl_account VALUE '300000'.

    "--- opening balances are dated at the start of the 3-month history
    "    window, so every generated transaction falls AFTER them and the
    "    books read in chronological order. Must match gc_days_back in
    "    ZCL_ITS_GEN_TRANSACTIONS. ---
    CONSTANTS gc_days_back TYPE i VALUE 90.

    "--- opening balance carries no reference document, so the Journal
    "    Entry BO treats it as hand-made and demands the accounting role ---
    METHODS is_accounting
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS clear_test_data
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

    METHODS post_opening_balance
      IMPORTING iv_branch_id TYPE zits_branch-branch_id
                iv_cash      TYPE zits_jeitem-amount
                out          TYPE REF TO if_oo_adt_classrun_out.

ENDCLASS.


CLASS zcl_its_gen_opening IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    out->write( |=== ITZone Opening Balance Generator ===| ).
    out->write( || ).

    " Opening balances are an accounting act. The Journal Entry BO rejects
    " a hand-made entry from anybody else, so fail loudly here rather than
    " letting three cryptic validation errors come back later.
    IF is_accounting( ) = abap_false.
      out->write( |ABORTED - your user is not an active employee with role 'A' (accounting).| ).
      out->write( |Switch persona with ZCL_ITS_SWITCH_PERSONA and run this again.| ).
      RETURN.
    ENDIF.

    clear_test_data( out ).

    out->write( || ).
    out->write( |--- Posting opening balances ---| ).

    post_opening_balance( iv_branch_id = 'BR01' iv_cash = gc_cash_br01 out = out ).
    post_opening_balance( iv_branch_id = 'BR02' iv_cash = gc_cash_br02 out = out ).
    post_opening_balance( iv_branch_id = 'BR03' iv_cash = gc_cash_br03 out = out ).

    out->write( || ).
    out->write( |=== Done. Check the Journal Entry app and the trial balance. ===| ).

  ENDMETHOD.


  METHOD is_accounting.

    DATA(lv_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    SELECT SINGLE FROM zits_employee
      FIELDS role_code
      WHERE upper( user_name ) = @lv_user
        AND is_active = 'X'
      INTO @DATA(lv_role).

    rv_ok = COND abap_bool( WHEN lv_role = 'A' THEN abap_true ELSE abap_false ).

  ENDMETHOD.


  METHOD clear_test_data.

    " Wipe every transactional document so the books start from zero.
    " Deleted items before headers, and the draft tables too - a leftover
    " draft would otherwise reappear in Fiori as a ghost order pointing at
    " a header that no longer exists.
    "
    " Master data and stock are not deleted here. ZCL_ITS_GEN_MASTER is
    " called at the end instead, which clears and re-seeds company, region,
    " branch, cost center, GL account, partner AND stock in one go, so the
    " starting quantities always match whatever that generator defines.

    out->write( |--- Clearing test transactional data ---| ).

    DELETE FROM zits_jeitem.
    DELETE FROM zits_je.
    out->write( |Deleted journal entries| ).

    DELETE FROM zits_matdoc.
    out->write( |Deleted material documents| ).

    DELETE FROM zits_soitem.
    DELETE FROM zits_so.
    out->write( |Deleted sales orders| ).

    DELETE FROM zits_poitem.
    DELETE FROM zits_po.
    out->write( |Deleted purchase orders| ).

    " the old single-shop ledger - still written by Complete/Receive until
    " it is retired, so it counts as transactional data and goes as well
    DELETE FROM zits_ledger.
    out->write( |Deleted ledger entries| ).

    " draft tables, so no half-finished document survives the reset
    DELETE FROM zits_jeitem_d.
    DELETE FROM zits_je_d.
    DELETE FROM zits_soitem_d.
    DELETE FROM zits_so_d.
    DELETE FROM zits_poitem_d.
    DELETE FROM zits_po_d.
    out->write( |Deleted leftover drafts| ).

    COMMIT WORK.

    out->write( || ).
    out->write( |Re-seeding master data and stock...| ).
    NEW zcl_its_gen_master( )->if_oo_adt_classrun~main( out = out ).

  ENDMETHOD.


  METHOD post_opening_balance.

    " Post one opening-balance journal entry for a branch:
    "   Dr Cash      = the branch's starting cash
    "   Dr Inventory = value of everything in ZITS_STOCK at that branch,
    "                  at standard cost
    "   Cr Equity    = Cash + Inventory   (the balancing line)
    "
    " Created through the Journal Entry BO with EML, not by inserting rows,
    " so validateLine, validateBalance, assignItemPos, calcTotals and
    " assignJENumber all run exactly as they do for any other entry - the
    " entry is provably valid rather than merely present.
    "
    " It is posted by the BO itself: autoPostSystemEntry recognises
    " DocType 'OB' and sets PostingStatus = 'P' on save.

    " --- inventory value = SUM( qty_on_hand * cost_price ) for this branch.
    "     Multiplied in ABAP rather than in the SELECT: qty_on_hand is QUAN
    "     and cost_price is CURR, and those do not multiply cleanly inside
    "     Open SQL without casting every operand (hard-won rule 7).
    SELECT FROM zits_stock AS stock
      INNER JOIN zits_product AS product
        ON product~product_id = stock~product_id
      FIELDS stock~qty_on_hand, product~cost_price
      WHERE stock~branch_id = @iv_branch_id
      INTO TABLE @DATA(lt_stock).

    IF lt_stock IS INITIAL.
      out->write( |[{ iv_branch_id }] No stock found - skipping (check the master generator ran).| ).
      RETURN.
    ENDIF.

    DATA lv_inventory_value TYPE zits_jeitem-amount.
    CLEAR lv_inventory_value.

    LOOP AT lt_stock INTO DATA(ls_stock).
      lv_inventory_value = lv_inventory_value + ( ls_stock-qty_on_hand * ls_stock-cost_price ).
    ENDLOOP.

    IF lv_inventory_value <= 0.
      out->write( |[{ iv_branch_id }] Stock has no value - skipping (product cost prices missing?).| ).
      RETURN.
    ENDIF.

    " --- cost center for this branch (type S = sales/branch cost center) ---
    SELECT SINGLE FROM zits_costctr
      FIELDS cost_center_id
      WHERE branch_id = @iv_branch_id
        AND cc_type   = 'S'
        AND is_active = 'X'
      INTO @DATA(lv_cost_center).

    IF sy-subrc <> 0.
      out->write( |[{ iv_branch_id }] No active sales cost center found - skipping.| ).
      RETURN.
    ENDIF.

    DATA lv_equity TYPE zits_jeitem-amount.
    lv_equity = iv_cash + lv_inventory_value.

    DATA lv_opening_date TYPE d.
    lv_opening_date = cl_abap_context_info=>get_system_date( ) - gc_days_back.

    DATA(lv_je_cid) = |OB_{ iv_branch_id }|.

    " --- the three lines hang under ONE %cid_ref row, inside %target.
    "     A row of "TABLE FOR CREATE ..\_Item" is a parent reference plus a
    "     nested table of children - the child fields and %cid live in
    "     %target, not at the top level.
    DATA je_items TYPE TABLE FOR CREATE zi_its_je\_Item.

    je_items = VALUE #(
      ( %cid_ref = lv_je_cid
        %target  = VALUE #(

          ( %cid         = |{ lv_je_cid }_1|
            GLAccount    = gc_acct_cash
            DCIndicator  = 'D'
            Amount       = iv_cash
            CurrencyCode = 'THB'
            CostCenterID = lv_cost_center
            LineText     = |Opening cash balance { iv_branch_id }| )

          ( %cid         = |{ lv_je_cid }_2|
            GLAccount    = gc_acct_invty
            DCIndicator  = 'D'
            Amount       = lv_inventory_value
            CurrencyCode = 'THB'
            CostCenterID = lv_cost_center
            LineText     = |Opening inventory value { iv_branch_id }| )

          ( %cid         = |{ lv_je_cid }_3|
            GLAccount    = gc_acct_equity
            DCIndicator  = 'C'
            Amount       = lv_equity
            CurrencyCode = 'THB'
            CostCenterID = lv_cost_center
            LineText     = |Opening equity { iv_branch_id }| ) ) ) ).

    MODIFY ENTITIES OF zi_its_je
      ENTITY JournalEntry
        CREATE FIELDS ( PostingDate DocType BranchID HeaderText CurrencyCode )
          WITH VALUE #( ( %cid         = lv_je_cid
                          PostingDate  = lv_opening_date
                          DocType      = 'OB'
                          BranchID     = iv_branch_id
                          HeaderText   = |Opening balance { iv_branch_id }|
                          CurrencyCode = 'THB' ) )
        CREATE BY \_Item
          FIELDS ( GLAccount DCIndicator Amount CurrencyCode CostCenterID LineText )
          WITH je_items
      FAILED   DATA(je_failed)
      REPORTED DATA(je_reported).

    IF je_failed-journalentry IS NOT INITIAL OR je_failed-journalentryitem IS NOT INITIAL.
      ROLLBACK ENTITIES.
      out->write( |[{ iv_branch_id }] FAILED to create opening entry:| ).

      LOOP AT je_reported-journalentry INTO DATA(hdr_msg).
        IF hdr_msg-%msg IS BOUND.
          out->write( |  { hdr_msg-%msg->if_message~get_text( ) }| ).
        ENDIF.
      ENDLOOP.

      LOOP AT je_reported-journalentryitem INTO DATA(item_msg).
        IF item_msg-%msg IS BOUND.
          out->write( |  { item_msg-%msg->if_message~get_text( ) }| ).
        ENDIF.
      ENDLOOP.

      RETURN.
    ENDIF.

    " Validations run at save, not at MODIFY, so a wrong account or an
    " unbalanced document only shows up here.
    COMMIT ENTITIES RESPONSE OF zi_its_je
      FAILED   DATA(commit_failed)
      REPORTED DATA(commit_reported).

    IF commit_failed IS NOT INITIAL.
      out->write( |[{ iv_branch_id }] Entry rejected on save:| ).

      LOOP AT commit_reported-journalentry INTO DATA(chdr_msg).
        IF chdr_msg-%msg IS BOUND.
          out->write( |  { chdr_msg-%msg->if_message~get_text( ) }| ).
        ENDIF.
      ENDLOOP.

      LOOP AT commit_reported-journalentryitem INTO DATA(citem_msg).
        IF citem_msg-%msg IS BOUND.
          out->write( |  { citem_msg-%msg->if_message~get_text( ) }| ).
        ENDIF.
      ENDLOOP.

      RETURN.
    ENDIF.

    " --- read back what actually landed, so the log reports the database
    "     rather than what we hoped it would contain ---
    SELECT SINGLE FROM zits_je
      FIELDS je_number, posting_status, total_debit, total_credit
      WHERE branch_id = @iv_branch_id
        AND doc_type  = 'OB'
      INTO @DATA(ls_posted).

    IF sy-subrc <> 0.
      out->write( |[{ iv_branch_id }] Commit reported success but no entry was found.| ).
      RETURN.
    ENDIF.

    out->write( |[{ iv_branch_id }] JE { ls_posted-je_number } status { ls_posted-posting_status }| &&
                | - Dr Cash { iv_cash } + Dr Inventory { lv_inventory_value }| &&
                | = Cr Equity { lv_equity }| &&
                | (debit { ls_posted-total_debit } / credit { ls_posted-total_credit })| ).

  ENDMETHOD.

ENDCLASS.

