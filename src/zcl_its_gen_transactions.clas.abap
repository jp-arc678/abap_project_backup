CLASS zcl_its_gen_transactions DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PROTECTED SECTION.
  PRIVATE SECTION.

*======================================================================*
*  TARGETS - dial these down for a smoke test before the full run
*======================================================================*
    CONSTANTS gc_days_back  TYPE i VALUE 90.   "must match ZCL_ITS_GEN_OPENING
    CONSTANTS gc_periods    TYPE i VALUE 3.    "3 months
    CONSTANTS gc_so_total   TYPE i VALUE 270.
    CONSTANTS gc_po_total   TYPE i VALUE 30.
    CONSTANTS gc_reject_pct TYPE i VALUE 5.    "% of submitted orders rejected

    "--- branch share of the sales orders, in percent ---
    CONSTANTS gc_share_br01 TYPE i VALUE 45.
    CONSTANTS gc_share_br02 TYPE i VALUE 35.
    CONSTANTS gc_share_br03 TYPE i VALUE 20.

    TYPES: BEGIN OF ty_branch_plan,
             branch_id TYPE zits_branch-branch_id,
             region_id TYPE zits_region-region_id,
             so_target TYPE i,
             po_target TYPE i,
             basket    TYPE i,          "typical items per order
           END OF ty_branch_plan,
           ty_branch_plans TYPE STANDARD TABLE OF ty_branch_plan WITH EMPTY KEY.

    TYPES: BEGIN OF ty_product,
             product_id TYPE zits_product-product_id,
             sale_price TYPE zits_product-sale_price,
             cost_price TYPE zits_product-cost_price,
           END OF ty_product,
           ty_products TYPE STANDARD TABLE OF ty_product WITH EMPTY KEY.

    "--- one entry per weighted slot; cheap products appear many times ---
    TYPES ty_weighted TYPE STANDARD TABLE OF zits_product-product_id WITH EMPTY KEY.

    TYPES: BEGIN OF ty_reserved,
             branch_id  TYPE zits_stock-branch_id,
             product_id TYPE zits_stock-product_id,
             qty        TYPE zits_stock-qty_on_hand,
           END OF ty_reserved,
           ty_reserveds TYPE STANDARD TABLE OF ty_reserved WITH EMPTY KEY.

    TYPES: BEGIN OF ty_line,
             product_id TYPE zits_product-product_id,
             quantity   TYPE zits_soitem-quantity,
             price      TYPE zits_product-sale_price,
           END OF ty_line,
           ty_lines TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

    TYPES: BEGIN OF ty_stat,
             branch_id    TYPE zits_branch-branch_id,
             so_created   TYPE i,
             so_completed TYPE i,
             so_rejected  TYPE i,
             so_failed    TYPE i,
             lvl0         TYPE i,
             lvl1         TYPE i,
             lvl2         TYPE i,
             po_created   TYPE i,
             po_received  TYPE i,
             po_rejected  TYPE i,
             po_failed    TYPE i,
             revenue      TYPE zits_so-total_amount,
           END OF ty_stat,
           ty_stats TYPE STANDARD TABLE OF ty_stat WITH EMPTY KEY.

    DATA mt_products TYPE ty_products.
    DATA mt_weighted TYPE ty_weighted.
    DATA mt_reserved TYPE ty_reserveds.
    DATA mt_stats    TYPE ty_stats.
    DATA mt_failures TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA mv_seq      TYPE i VALUE 1.
    DATA mv_so_seq   TYPE i VALUE 0.
    DATA mv_lvl_diff TYPE i VALUE 0.   "predicted vs actual ApprovalLevel

    "--- deterministic pseudo-random in 0 .. iv_max-1, so the whole
    "    generated history is reproducible across runs ---
    METHODS next_int
      IMPORTING iv_max        TYPE i
      RETURNING VALUE(rv_val) TYPE i.

    METHODS load_products
      RETURNING VALUE(rv_ok) TYPE abap_bool.

    METHODS available_qty
      IMPORTING iv_branch_id  TYPE zits_stock-branch_id
                iv_product_id TYPE zits_product-product_id
      RETURNING VALUE(rv_qty) TYPE zits_stock-qty_on_hand.

    METHODS reserve
      IMPORTING iv_branch_id  TYPE zits_stock-branch_id
                iv_product_id TYPE zits_product-product_id
                iv_qty        TYPE zits_stock-qty_on_hand.

    METHODS bump
      IMPORTING iv_branch_id TYPE zits_branch-branch_id
                iv_field     TYPE string
                iv_amount    TYPE zits_so-total_amount OPTIONAL.

    METHODS latest_so_uuid RETURNING VALUE(rv_uuid) TYPE zits_so-so_uuid.
    METHODS latest_po_uuid RETURNING VALUE(rv_uuid) TYPE zits_po-po_uuid.

    METHODS msg_of
      IMPORTING it_reported   TYPE any
      RETURNING VALUE(rv_txt) TYPE string.

    METHODS run_sales_batch
      IMPORTING is_plan TYPE ty_branch_plan
                iv_from TYPE d
                iv_to   TYPE d
                iv_count TYPE i
                out     TYPE REF TO if_oo_adt_classrun_out.

    METHODS run_purchase_batch
      IMPORTING is_plan TYPE ty_branch_plan
                iv_from TYPE d
                iv_to   TYPE d
                iv_count TYPE i
                out     TYPE REF TO if_oo_adt_classrun_out.

    METHODS print_summary
      IMPORTING out TYPE REF TO if_oo_adt_classrun_out.

ENDCLASS.


CLASS zcl_its_gen_transactions IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    out->write( |=== ITZone Historical Transaction Generator ===| ).
    out->write( |Target: { gc_so_total } sales orders, { gc_po_total } purchase orders| &&
                | over the last { gc_days_back } days| ).
    out->write( || ).

    IF load_products( ) = abap_false.
      out->write( |ABORTED - no active products found. Run ZCL_ITS_GEN_MASTER first.| ).
      RETURN.
    ENDIF.

    "--- opening balances must already be posted, and dated before the
    "    window, or the generated history will read out of order ---
    SELECT COUNT( * ) FROM zits_je WHERE doc_type = 'OB' INTO @DATA(lv_ob_count).
    IF lv_ob_count = 0.
      out->write( |ABORTED - no opening balances found. Run ZCL_ITS_GEN_OPENING first.| ).
      RETURN.
    ENDIF.
    out->write( |Found { lv_ob_count } opening balance entries.| ).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA lv_start TYPE d.
    lv_start = lv_today - gc_days_back.

    "--- branch plan ---
    DATA(lt_plans) = VALUE ty_branch_plans(
      ( branch_id = 'BR01' region_id = 'CEN'
        so_target = gc_so_total * gc_share_br01 / 100
        po_target = gc_po_total * gc_share_br01 / 100
        basket    = 4 )
      ( branch_id = 'BR02' region_id = 'CEN'
        so_target = gc_so_total * gc_share_br02 / 100
        po_target = gc_po_total * gc_share_br02 / 100
        basket    = 3 )
      ( branch_id = 'BR03' region_id = 'NOR'
        so_target = gc_so_total * gc_share_br03 / 100
        po_target = gc_po_total * gc_share_br03 / 100
        basket    = 2 ) ).

    LOOP AT lt_plans INTO DATA(ls_plan).
      APPEND VALUE #( branch_id = ls_plan-branch_id ) TO mt_stats.
      out->write( |{ ls_plan-branch_id }: target { ls_plan-so_target } sales, | &&
                  |{ ls_plan-po_target } purchases| ).
    ENDLOOP.
    out->write( || ).

    "--- period length in days ---
    DATA(lv_period_len) = gc_days_back / gc_periods.

    DO gc_periods TIMES.

      DATA(lv_period) = sy-index.
      DATA lv_from TYPE d.
      DATA lv_to   TYPE d.
      lv_from = lv_start + ( lv_period - 1 ) * lv_period_len.
      lv_to   = lv_from + lv_period_len - 1.
      IF lv_to > lv_today.
        lv_to = lv_today.
      ENDIF.

      out->write( |--- Period { lv_period }: { lv_from } to { lv_to } ---| ).

      LOOP AT lt_plans INTO ls_plan.

        "--- purchases FIRST so the branch has stock to sell afterwards ---
        DATA(lv_po_slice) = ls_plan-po_target / gc_periods.
        IF lv_period = gc_periods.
          lv_po_slice = ls_plan-po_target - ( ls_plan-po_target / gc_periods ) * ( gc_periods - 1 ).
        ENDIF.
        run_purchase_batch( is_plan = ls_plan iv_from = lv_from iv_to = lv_to
                            iv_count = lv_po_slice out = out ).

        DATA(lv_so_slice) = ls_plan-so_target / gc_periods.
        IF lv_period = gc_periods.
          lv_so_slice = ls_plan-so_target - ( ls_plan-so_target / gc_periods ) * ( gc_periods - 1 ).
        ENDIF.
        run_sales_batch( is_plan = ls_plan iv_from = lv_from iv_to = lv_to
                         iv_count = lv_so_slice out = out ).

      ENDLOOP.

    ENDDO.

    print_summary( out ).

  ENDMETHOD.


  METHOD next_int.
    IF iv_max <= 0.
      rv_val = 0.
      RETURN.
    ENDIF.
    mv_seq = ( mv_seq * 31 + 17 ) MOD 100003.
    rv_val = mv_seq MOD iv_max.
  ENDMETHOD.


  METHOD load_products.

    SELECT FROM zits_product
      FIELDS product_id, sale_price, cost_price
      WHERE is_active = 'X'
      ORDER BY product_id
      INTO TABLE @mt_products.

    IF mt_products IS INITIAL.
      rv_ok = abap_false.
      RETURN.
    ENDIF.

    "--- weight so cheap accessories sell far more often than laptops.
    "    Repeating the id in a flat table makes the pick a plain index
    "    lookup instead of a cumulative-weight walk. ---
    LOOP AT mt_products INTO DATA(ls_prod).

      DATA(lv_weight) = COND i( WHEN ls_prod-sale_price <  1000 THEN 8
                                WHEN ls_prod-sale_price <  5000 THEN 5
                                WHEN ls_prod-sale_price < 20000 THEN 2
                                ELSE 1 ).

      DO lv_weight TIMES.
        APPEND ls_prod-product_id TO mt_weighted.
      ENDDO.

    ENDLOOP.

    rv_ok = abap_true.

  ENDMETHOD.


  METHOD available_qty.

    "--- read the table fresh every time rather than trusting a snapshot,
    "    then subtract what this run has already promised away but not yet
    "    posted: several orders in the same batch draw on the same pool
    "    before any of them completes ---
    SELECT SINGLE FROM zits_stock
      FIELDS qty_on_hand
      WHERE branch_id  = @iv_branch_id
        AND product_id = @iv_product_id
      INTO @rv_qty.

    IF sy-subrc <> 0.
      rv_qty = 0.
      RETURN.
    ENDIF.

    READ TABLE mt_reserved INTO DATA(ls_res)
      WITH KEY branch_id = iv_branch_id product_id = iv_product_id.
    IF sy-subrc = 0.
      rv_qty = rv_qty - ls_res-qty.
    ENDIF.

    IF rv_qty < 0.
      rv_qty = 0.
    ENDIF.

  ENDMETHOD.


  METHOD reserve.

    READ TABLE mt_reserved ASSIGNING FIELD-SYMBOL(<ls_res>)
      WITH KEY branch_id = iv_branch_id product_id = iv_product_id.

    IF sy-subrc = 0.
      <ls_res>-qty = <ls_res>-qty + iv_qty.
    ELSE.
      APPEND VALUE #( branch_id  = iv_branch_id
                      product_id = iv_product_id
                      qty        = iv_qty ) TO mt_reserved.
    ENDIF.

  ENDMETHOD.


  METHOD bump.

    READ TABLE mt_stats ASSIGNING FIELD-SYMBOL(<ls_st>) WITH KEY branch_id = iv_branch_id.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    CASE iv_field.
      WHEN 'so_created'.   <ls_st>-so_created   = <ls_st>-so_created   + 1.
      WHEN 'so_completed'. <ls_st>-so_completed = <ls_st>-so_completed + 1.
                           <ls_st>-revenue      = <ls_st>-revenue      + iv_amount.
      WHEN 'so_rejected'.  <ls_st>-so_rejected  = <ls_st>-so_rejected  + 1.
      WHEN 'so_failed'.    <ls_st>-so_failed    = <ls_st>-so_failed    + 1.
      WHEN 'lvl0'.         <ls_st>-lvl0         = <ls_st>-lvl0         + 1.
      WHEN 'lvl1'.         <ls_st>-lvl1         = <ls_st>-lvl1         + 1.
      WHEN 'lvl2'.         <ls_st>-lvl2         = <ls_st>-lvl2         + 1.
      WHEN 'po_created'.   <ls_st>-po_created   = <ls_st>-po_created   + 1.
      WHEN 'po_received'.  <ls_st>-po_received  = <ls_st>-po_received  + 1.
      WHEN 'po_rejected'.  <ls_st>-po_rejected  = <ls_st>-po_rejected  + 1.
      WHEN 'po_failed'.    <ls_st>-po_failed    = <ls_st>-po_failed    + 1.
    ENDCASE.

  ENDMETHOD.


  METHOD latest_so_uuid.
    "--- the order just created carries the highest number, because
    "    assignSONumber hands them out as MAX + 1 and this generator
    "    creates and commits exactly one order at a time ---
    SELECT SINGLE FROM zits_so FIELDS MAX( so_number ) INTO @DATA(lv_max).
    IF lv_max IS INITIAL.
      RETURN.
    ENDIF.
    SELECT SINGLE FROM zits_so FIELDS so_uuid WHERE so_number = @lv_max INTO @rv_uuid.
  ENDMETHOD.


  METHOD latest_po_uuid.
    SELECT SINGLE FROM zits_po FIELDS MAX( po_number ) INTO @DATA(lv_max).
    IF lv_max IS INITIAL.
      RETURN.
    ENDIF.
    SELECT SINGLE FROM zits_po FIELDS po_uuid WHERE po_number = @lv_max INTO @rv_uuid.
  ENDMETHOD.


  METHOD msg_of.

    FIELD-SYMBOLS <lt_rep> TYPE ANY TABLE.
    ASSIGN it_reported TO <lt_rep>.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    LOOP AT <lt_rep> ASSIGNING FIELD-SYMBOL(<ls_rep>).
      ASSIGN COMPONENT '%MSG' OF STRUCTURE <ls_rep> TO FIELD-SYMBOL(<lo_msg>).
      IF sy-subrc = 0 AND <lo_msg> IS NOT INITIAL.
        "--- diagnostics only: if the cast ever fails, the run must carry
        "    on with a blank message rather than dying on a log line ---
        TRY.
            DATA lo_ref TYPE REF TO if_abap_behv_message.
            lo_ref ?= <lo_msg>.
            IF lo_ref IS BOUND.
              rv_txt = lo_ref->if_message~get_text( ).
              RETURN.
            ENDIF.
          CATCH cx_sy_move_cast_error.
        ENDTRY.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


*======================================================================*
*  SALES ORDERS
*======================================================================*
  METHOD run_sales_batch.

    IF iv_count <= 0.
      RETURN.
    ENDIF.

    "--- everything this branch promised away in an earlier period has
    "    already been posted, so start the period with a clean slate ---
    CLEAR mt_reserved.

    DATA(lv_span) = iv_to - iv_from + 1.
    IF lv_span < 1.
      lv_span = 1.
    ENDIF.

    TYPES: BEGIN OF ty_pending,
             uuid  TYPE zits_so-so_uuid,
             level TYPE i,
             total TYPE zits_so-total_amount,
             kill  TYPE abap_bool,
           END OF ty_pending.
    DATA lt_pending TYPE STANDARD TABLE OF ty_pending WITH EMPTY KEY.

*----------------------------------------------------------------------*
* Phase 1 - as the branch salesperson: create and submit
*----------------------------------------------------------------------*
    IF zcl_its_switch_persona=>switch_to( iv_role      = 'S'
                                          iv_branch_id = is_plan-branch_id ) IS INITIAL.
      APPEND |{ is_plan-branch_id } SO: no active salesperson - batch skipped| TO mt_failures.
      RETURN.
    ENDIF.

    DO iv_count TIMES.

      DATA(lv_idx) = sy-index.

      "--- build the basket from what the branch can actually spare ---
      DATA lt_lines TYPE ty_lines.
      CLEAR lt_lines.

      DATA(lv_items) = 1 + next_int( is_plan-basket ).

      DO lv_items TIMES.

        DATA(lv_pid) = mt_weighted[ 1 + next_int( lines( mt_weighted ) ) ].

        "--- never plan the same product twice in one order ---
        READ TABLE lt_lines TRANSPORTING NO FIELDS WITH KEY product_id = lv_pid.
        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.

        DATA(lv_avail) = available_qty( iv_branch_id  = is_plan-branch_id
                                        iv_product_id = lv_pid ).
        IF lv_avail <= 0.
          CONTINUE.
        ENDIF.

        "--- cap the line so the pool cannot go negative, and keep most
        "    baskets small so the level distribution stays realistic ---
        DATA lv_cap TYPE i.
        IF lv_avail > 4.
          lv_cap = 4.
        ELSE.
          lv_cap = lv_avail.
        ENDIF.

        "--- the quantity has to carry the stock quantity type, not plain
        "    integer. Assigning an I into a packed field is fine, but
        "    PASSING one to a QUAN(13,3) parameter is not - ABAP checks
        "    parameter types strictly and will not convert on the way in. ---
        DATA lv_qty TYPE zits_stock-qty_on_hand.
        lv_qty = 1 + next_int( lv_cap ).
        IF lv_qty > lv_avail.
          lv_qty = lv_avail.
        ENDIF.

        READ TABLE mt_products INTO DATA(ls_prod) WITH KEY product_id = lv_pid.

        APPEND VALUE #( product_id = lv_pid
                        quantity   = lv_qty
                        price      = ls_prod-sale_price ) TO lt_lines.

        reserve( iv_branch_id  = is_plan-branch_id
                 iv_product_id = lv_pid
                 iv_qty        = lv_qty ).
      ENDDO.

      IF lt_lines IS INITIAL.
        APPEND |{ is_plan-branch_id } SO #{ lv_idx }: no sellable stock left| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
        CONTINUE.
      ENDIF.

      "--- expected total, so the approval level is known up front and the
      "    orders can be grouped by approver instead of switching persona
      "    once per document ---
      DATA lv_total TYPE zits_so-total_amount.
      CLEAR lv_total.
      LOOP AT lt_lines INTO DATA(ls_line).
        lv_total = lv_total + ( ls_line-quantity * ls_line-price ).
      ENDLOOP.

      DATA(lv_level) = zcl_its_approval=>get_required_level_so( lv_total ).

      "--- spread the dates over the period instead of clustering ---
      DATA lv_date TYPE d.
      lv_date = iv_from + next_int( lv_span ).

      DATA(lv_pay) = SWITCH zits_so-payment_method( next_int( 3 )
                       WHEN 0 THEN 'C' WHEN 1 THEN 'R' ELSE 'T' ).

      mv_so_seq = mv_so_seq + 1.
      DATA(lv_cid) = |SO_{ mv_so_seq }|.

      DATA so_create TYPE TABLE FOR CREATE zi_its_salesorder.
      DATA so_items  TYPE TABLE FOR CREATE zi_its_salesorder\_Item.
      CLEAR so_create.
      CLEAR so_items.

      so_create = VALUE #( ( %cid          = lv_cid
                             SalesDate     = lv_date
                             CurrencyCode  = 'THB'
                             PaymentMethod = lv_pay ) ).

      DATA ls_items LIKE LINE OF so_items.
      CLEAR ls_items.
      ls_items-%cid_ref = lv_cid.

      LOOP AT lt_lines INTO ls_line.
        APPEND VALUE #( %cid      = |{ lv_cid }_{ sy-tabix }|
                        ProductID = ls_line-product_id
                        Quantity  = ls_line-quantity ) TO ls_items-%target.
      ENDLOOP.
      APPEND ls_items TO so_items.

      MODIFY ENTITIES OF zi_its_salesorder
        ENTITY SalesOrder
          CREATE FIELDS ( SalesDate CurrencyCode PaymentMethod ) WITH so_create
          CREATE BY \_Item FIELDS ( ProductID Quantity ) WITH so_items
        FAILED   DATA(so_failed)
        REPORTED DATA(so_rep).

      IF so_failed-salesorder IS NOT INITIAL OR so_failed-salesorderitem IS NOT INITIAL.
        ROLLBACK ENTITIES.
        APPEND |{ is_plan-branch_id } SO #{ lv_idx } CREATE: { msg_of( so_rep-salesorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
        CONTINUE.
      ENDIF.

      COMMIT ENTITIES RESPONSE OF zi_its_salesorder FAILED DATA(so_cfail) REPORTED DATA(so_crep).
      IF so_cfail IS NOT INITIAL.
        APPEND |{ is_plan-branch_id } SO #{ lv_idx } SAVE: { msg_of( so_crep-salesorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
        CONTINUE.
      ENDIF.

      bump( iv_branch_id = is_plan-branch_id iv_field = 'so_created' ).

      DATA(lv_uuid) = latest_so_uuid( ).
      IF lv_uuid IS INITIAL.
        APPEND |{ is_plan-branch_id } SO #{ lv_idx }: created but key not found| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
        CONTINUE.
      ENDIF.

      "--- Submit: level 0 lands straight on Confirmed, 1 and 2 on Pending ---
      MODIFY ENTITIES OF zi_its_salesorder
        ENTITY SalesOrder
          EXECUTE Submit FROM VALUE #( ( %key-SOUUID = lv_uuid ) )
        FAILED   DATA(sub_failed)
        REPORTED DATA(sub_rep).

      IF sub_failed-salesorder IS NOT INITIAL.
        ROLLBACK ENTITIES.
        APPEND |{ is_plan-branch_id } SO #{ lv_idx } SUBMIT: { msg_of( sub_rep-salesorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
        CONTINUE.
      ENDIF.
      COMMIT ENTITIES.

      "--- The level was predicted from quantity x sale_price so the orders
      "    could be grouped by approver. Submit has now had the BO compute
      "    it for real from TotalAmount - trust that, and record any
      "    disagreement so the smoke test surfaces it.
      "
      "    Reading the truth here costs nothing extra: approvals are batched
      "    into later phases anyway, so routing on the actual level needs no
      "    additional persona switch. ---
      SELECT SINGLE FROM zits_so
        FIELDS approval_level
        WHERE so_uuid = @lv_uuid
        INTO @DATA(lv_lvl_raw).

      DATA(lv_actual) = CONV i( lv_lvl_raw ).

      IF lv_actual <> lv_level.
        mv_lvl_diff = mv_lvl_diff + 1.
        APPEND |{ is_plan-branch_id } SO #{ lv_idx } LEVEL: predicted { lv_level }, | &&
               |BO set { lv_actual } (routing follows the BO)| TO mt_failures.
        lv_level = lv_actual.
      ENDIF.

      bump( iv_branch_id = is_plan-branch_id
            iv_field     = SWITCH string( lv_level WHEN 0 THEN 'lvl0' WHEN 1 THEN 'lvl1' ELSE 'lvl2' ) ).

      "--- every 20th submitted order gets rejected, so the Reject path
      "    is exercised too; level 0 never sees an approver so it cannot
      "    be rejected ---
      DATA(lv_kill) = COND abap_bool(
        WHEN lv_level > 0 AND lv_idx MOD ( 100 / gc_reject_pct ) = 0
        THEN abap_true ELSE abap_false ).

      APPEND VALUE #( uuid = lv_uuid level = lv_level total = lv_total kill = lv_kill ) TO lt_pending.

    ENDDO.

*----------------------------------------------------------------------*
* Phase 2 - as the branch manager: level 1
* Phase 3 - as the regional manager: level 2
*----------------------------------------------------------------------*
    DATA(lv_pass) = 1.
    DO 2 TIMES.

      DATA(lv_want_level) = lv_pass.

      READ TABLE lt_pending TRANSPORTING NO FIELDS WITH KEY level = lv_want_level.
      IF sy-subrc = 0.

        "--- plain IF, not COND #( ): an inline DATA( ) target gives the
        "    compiler nothing to infer the # from ---
        DATA lv_switched TYPE zits_employee-employee_id.
        IF lv_want_level = 1.
          lv_switched = zcl_its_switch_persona=>switch_to( iv_role      = 'M'
                                                           iv_branch_id = is_plan-branch_id ).
        ELSE.
          lv_switched = zcl_its_switch_persona=>switch_to( iv_role      = 'R'
                                                           iv_region_id = is_plan-region_id ).
        ENDIF.

        IF lv_switched IS INITIAL.
          APPEND |{ is_plan-branch_id } SO: no approver for level { lv_want_level }| TO mt_failures.
        ELSE.

          LOOP AT lt_pending ASSIGNING FIELD-SYMBOL(<ls_pend>) WHERE level = lv_want_level.

            IF <ls_pend>-kill = abap_true.
              MODIFY ENTITIES OF zi_its_salesorder
                ENTITY SalesOrder
                  EXECUTE Reject FROM VALUE #( ( %key-SOUUID = <ls_pend>-uuid ) )
                FAILED DATA(rej_failed) REPORTED DATA(rej_rep).
              IF rej_failed-salesorder IS NOT INITIAL.
                ROLLBACK ENTITIES.
                APPEND |{ is_plan-branch_id } SO REJECT: { msg_of( rej_rep-salesorder ) }| TO mt_failures.
                bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
              ELSE.
                COMMIT ENTITIES.
                bump( iv_branch_id = is_plan-branch_id iv_field = 'so_rejected' ).
              ENDIF.
              CONTINUE.
            ENDIF.

            MODIFY ENTITIES OF zi_its_salesorder
              ENTITY SalesOrder
                EXECUTE Approve FROM VALUE #( ( %key-SOUUID = <ls_pend>-uuid ) )
              FAILED DATA(app_failed) REPORTED DATA(app_rep).

            IF app_failed-salesorder IS NOT INITIAL.
              ROLLBACK ENTITIES.
              APPEND |{ is_plan-branch_id } SO APPROVE L{ lv_want_level }: { msg_of( app_rep-salesorder ) }| TO mt_failures.
              bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
              <ls_pend>-kill = abap_true.   "do not try to complete it
            ELSE.
              COMMIT ENTITIES.
            ENDIF.

          ENDLOOP.
        ENDIF.
      ENDIF.

      lv_pass = lv_pass + 1.
    ENDDO.

*----------------------------------------------------------------------*
* Phase 4 - back to the salesperson: complete everything confirmed
*----------------------------------------------------------------------*
    IF zcl_its_switch_persona=>switch_to( iv_role      = 'S'
                                          iv_branch_id = is_plan-branch_id ) IS INITIAL.
      APPEND |{ is_plan-branch_id } SO: salesperson gone before Complete| TO mt_failures.
      RETURN.
    ENDIF.

    LOOP AT lt_pending INTO DATA(ls_pend).

      IF ls_pend-kill = abap_true.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zi_its_salesorder
        ENTITY SalesOrder
          EXECUTE Complete FROM VALUE #( ( %key-SOUUID = ls_pend-uuid ) )
        FAILED DATA(cmp_failed) REPORTED DATA(cmp_rep).

      IF cmp_failed-salesorder IS NOT INITIAL.
        ROLLBACK ENTITIES.
        APPEND |{ is_plan-branch_id } SO COMPLETE: { msg_of( cmp_rep-salesorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
        CONTINUE.
      ENDIF.

      COMMIT ENTITIES RESPONSE OF zi_its_salesorder FAILED DATA(cmp_cfail) REPORTED DATA(cmp_crep).
      IF cmp_cfail IS NOT INITIAL.
        APPEND |{ is_plan-branch_id } SO COMPLETE SAVE: { msg_of( cmp_crep-salesorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
        CONTINUE.
      ENDIF.

      bump( iv_branch_id = is_plan-branch_id iv_field = 'so_completed' iv_amount = ls_pend-total ).

    ENDLOOP.

    CLEAR mt_reserved.

  ENDMETHOD.


*======================================================================*
*  PURCHASE ORDERS
*======================================================================*
  METHOD run_purchase_batch.

    IF iv_count <= 0.
      RETURN.
    ENDIF.

    "--- suppliers seeded by ZCL_ITS_GEN_MASTER ---
    SELECT FROM zits_partner
      FIELDS partner_id
      WHERE partner_role = 'S' OR partner_role = 'B'
      ORDER BY partner_id
      INTO TABLE @DATA(lt_suppliers).

    IF lt_suppliers IS INITIAL.
      APPEND |{ is_plan-branch_id } PO: no suppliers found| TO mt_failures.
      RETURN.
    ENDIF.

    DATA(lv_span) = iv_to - iv_from + 1.
    IF lv_span < 1.
      lv_span = 1.
    ENDIF.

    TYPES: BEGIN OF ty_pending_po,
             uuid  TYPE zits_po-po_uuid,
             level TYPE i,
             kill  TYPE abap_bool,
           END OF ty_pending_po.
    DATA lt_pending TYPE STANDARD TABLE OF ty_pending_po WITH EMPTY KEY.

*----------------------------------------------------------------------*
* Phase 1 - as the branch warehouse staff: create and submit
*----------------------------------------------------------------------*
    IF zcl_its_switch_persona=>switch_to( iv_role      = 'W'
                                          iv_branch_id = is_plan-branch_id ) IS INITIAL.
      APPEND |{ is_plan-branch_id } PO: no active warehouse staff - batch skipped| TO mt_failures.
      RETURN.
    ENDIF.

    DO iv_count TIMES.

      DATA(lv_idx) = sy-index.

      DATA lt_lines TYPE ty_lines.
      CLEAR lt_lines.

      DATA(lv_items) = 1 + next_int( 3 ).

      DO lv_items TIMES.
        DATA(lv_pid) = mt_weighted[ 1 + next_int( lines( mt_weighted ) ) ].

        READ TABLE lt_lines TRANSPORTING NO FIELDS WITH KEY product_id = lv_pid.
        IF sy-subrc = 0.
          CONTINUE.
        ENDIF.

        READ TABLE mt_products INTO DATA(ls_prod) WITH KEY product_id = lv_pid.

        "--- restock in useful sizes; purchases are not stock-constrained ---
        APPEND VALUE #( product_id = lv_pid
                        quantity   = 5 + next_int( 16 )
                        price      = ls_prod-cost_price ) TO lt_lines.
      ENDDO.

      IF lt_lines IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA lv_date TYPE d.
      lv_date = iv_from + next_int( lv_span / 2 ).   "order early in the period

      "--- SELECT ... INTO TABLE @DATA( ) builds a STRUCTURED table even for
      "    a single field, so the component has to be named explicitly ---
      DATA(lv_sup) = lt_suppliers[ 1 + next_int( lines( lt_suppliers ) ) ]-partner_id.
      DATA(lv_cid) = |PO_{ is_plan-branch_id }_{ lv_idx }_{ iv_from }|.

      DATA po_create TYPE TABLE FOR CREATE zi_its_purchaseorder.
      DATA po_items  TYPE TABLE FOR CREATE zi_its_purchaseorder\_Item.
      CLEAR po_create.
      CLEAR po_items.

      po_create = VALUE #( ( %cid         = lv_cid
                             SupplierID   = lv_sup
                             OrderDate    = lv_date
                             CurrencyCode = 'THB' ) ).

      DATA ls_items LIKE LINE OF po_items.
      CLEAR ls_items.
      ls_items-%cid_ref = lv_cid.

      LOOP AT lt_lines INTO DATA(ls_line).
        APPEND VALUE #( %cid      = |{ lv_cid }_{ sy-tabix }|
                        ProductID = ls_line-product_id
                        Quantity  = ls_line-quantity
                        CostPrice = ls_line-price ) TO ls_items-%target.
      ENDLOOP.
      APPEND ls_items TO po_items.

      MODIFY ENTITIES OF zi_its_purchaseorder
        ENTITY PurchaseOrder
          CREATE FIELDS ( SupplierID OrderDate CurrencyCode ) WITH po_create
          CREATE BY \_Item FIELDS ( ProductID Quantity CostPrice ) WITH po_items
        FAILED   DATA(po_failed)
        REPORTED DATA(po_rep).

      IF po_failed-purchaseorder IS NOT INITIAL OR po_failed-purchaseorderitem IS NOT INITIAL.
        ROLLBACK ENTITIES.
        APPEND |{ is_plan-branch_id } PO #{ lv_idx } CREATE: { msg_of( po_rep-purchaseorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'po_failed' ).
        CONTINUE.
      ENDIF.

      COMMIT ENTITIES RESPONSE OF zi_its_purchaseorder FAILED DATA(po_cfail) REPORTED DATA(po_crep).
      IF po_cfail IS NOT INITIAL.
        APPEND |{ is_plan-branch_id } PO #{ lv_idx } SAVE: { msg_of( po_crep-purchaseorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'po_failed' ).
        CONTINUE.
      ENDIF.

      bump( iv_branch_id = is_plan-branch_id iv_field = 'po_created' ).

      DATA(lv_uuid) = latest_po_uuid( ).
      IF lv_uuid IS INITIAL.
        APPEND |{ is_plan-branch_id } PO #{ lv_idx }: created but key not found| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'po_failed' ).
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_po FIELDS total_cost WHERE po_uuid = @lv_uuid INTO @DATA(lv_cost).
      DATA(lv_level) = zcl_its_approval=>get_required_level_po( lv_cost ).

      MODIFY ENTITIES OF zi_its_purchaseorder
        ENTITY PurchaseOrder
          EXECUTE Submit FROM VALUE #( ( %key-POUUID = lv_uuid ) )
        FAILED DATA(psub_failed) REPORTED DATA(psub_rep).

      IF psub_failed-purchaseorder IS NOT INITIAL.
        ROLLBACK ENTITIES.
        APPEND |{ is_plan-branch_id } PO #{ lv_idx } SUBMIT: { msg_of( psub_rep-purchaseorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'po_failed' ).
        CONTINUE.
      ENDIF.
      COMMIT ENTITIES.

      "--- same cross-check as on the sales side: route on the level the
      "    BO actually stamped, not the one predicted from TotalCost ---
      SELECT SINGLE FROM zits_po
        FIELDS approval_level
        WHERE po_uuid = @lv_uuid
        INTO @DATA(lv_lvl_raw).

      DATA(lv_actual) = CONV i( lv_lvl_raw ).

      IF lv_actual <> lv_level.
        mv_lvl_diff = mv_lvl_diff + 1.
        APPEND |{ is_plan-branch_id } PO #{ lv_idx } LEVEL: predicted { lv_level }, | &&
               |BO set { lv_actual } (routing follows the BO)| TO mt_failures.
        lv_level = lv_actual.
      ENDIF.

      DATA(lv_kill) = COND abap_bool( WHEN lv_idx MOD ( 100 / gc_reject_pct ) = 0
                                      THEN abap_true ELSE abap_false ).

      APPEND VALUE #( uuid = lv_uuid level = lv_level kill = lv_kill ) TO lt_pending.

    ENDDO.

*----------------------------------------------------------------------*
* Phase 2/3 - approve as branch manager (level 1) / regional (level 2)
*----------------------------------------------------------------------*
    DATA(lv_pass) = 1.
    DO 2 TIMES.

      DATA(lv_want_level) = lv_pass.

      READ TABLE lt_pending TRANSPORTING NO FIELDS WITH KEY level = lv_want_level.
      IF sy-subrc = 0.

        DATA lv_switched TYPE zits_employee-employee_id.
        IF lv_want_level = 1.
          lv_switched = zcl_its_switch_persona=>switch_to( iv_role      = 'M'
                                                           iv_branch_id = is_plan-branch_id ).
        ELSE.
          lv_switched = zcl_its_switch_persona=>switch_to( iv_role      = 'R'
                                                           iv_region_id = is_plan-region_id ).
        ENDIF.

        IF lv_switched IS INITIAL.
          APPEND |{ is_plan-branch_id } PO: no approver for level { lv_want_level }| TO mt_failures.
        ELSE.

          LOOP AT lt_pending ASSIGNING FIELD-SYMBOL(<ls_pend>) WHERE level = lv_want_level.

            IF <ls_pend>-kill = abap_true.
              MODIFY ENTITIES OF zi_its_purchaseorder
                ENTITY PurchaseOrder
                  EXECUTE Reject FROM VALUE #( ( %key-POUUID = <ls_pend>-uuid ) )
                FAILED DATA(prej_failed) REPORTED DATA(prej_rep).
              IF prej_failed-purchaseorder IS NOT INITIAL.
                ROLLBACK ENTITIES.
                APPEND |{ is_plan-branch_id } PO REJECT: { msg_of( prej_rep-purchaseorder ) }| TO mt_failures.
                bump( iv_branch_id = is_plan-branch_id iv_field = 'po_failed' ).
              ELSE.
                COMMIT ENTITIES.
                bump( iv_branch_id = is_plan-branch_id iv_field = 'po_rejected' ).
              ENDIF.
              CONTINUE.
            ENDIF.

            MODIFY ENTITIES OF zi_its_purchaseorder
              ENTITY PurchaseOrder
                EXECUTE Approve FROM VALUE #( ( %key-POUUID = <ls_pend>-uuid ) )
              FAILED DATA(papp_failed) REPORTED DATA(papp_rep).

            IF papp_failed-purchaseorder IS NOT INITIAL.
              ROLLBACK ENTITIES.
              APPEND |{ is_plan-branch_id } PO APPROVE L{ lv_want_level }: { msg_of( papp_rep-purchaseorder ) }| TO mt_failures.
              bump( iv_branch_id = is_plan-branch_id iv_field = 'po_failed' ).
              <ls_pend>-kill = abap_true.
            ELSE.
              COMMIT ENTITIES.
            ENDIF.

          ENDLOOP.
        ENDIF.
      ENDIF.

      lv_pass = lv_pass + 1.
    ENDDO.

*----------------------------------------------------------------------*
* Phase 4 - back to warehouse staff: receive, which is what puts the
* stock on the shelf for the sales batch that follows
*----------------------------------------------------------------------*
    IF zcl_its_switch_persona=>switch_to( iv_role      = 'W'
                                          iv_branch_id = is_plan-branch_id ) IS INITIAL.
      APPEND |{ is_plan-branch_id } PO: warehouse staff gone before Receive| TO mt_failures.
      RETURN.
    ENDIF.

    LOOP AT lt_pending INTO DATA(ls_pend).

      IF ls_pend-kill = abap_true.
        CONTINUE.
      ENDIF.

      MODIFY ENTITIES OF zi_its_purchaseorder
        ENTITY PurchaseOrder
          EXECUTE Receive FROM VALUE #( ( %key-POUUID = ls_pend-uuid ) )
        FAILED DATA(rcv_failed) REPORTED DATA(rcv_rep).

      IF rcv_failed-purchaseorder IS NOT INITIAL.
        ROLLBACK ENTITIES.
        APPEND |{ is_plan-branch_id } PO RECEIVE: { msg_of( rcv_rep-purchaseorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'po_failed' ).
        CONTINUE.
      ENDIF.

      COMMIT ENTITIES RESPONSE OF zi_its_purchaseorder FAILED DATA(rcv_cfail) REPORTED DATA(rcv_crep).
      IF rcv_cfail IS NOT INITIAL.
        APPEND |{ is_plan-branch_id } PO RECEIVE SAVE: { msg_of( rcv_crep-purchaseorder ) }| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'po_failed' ).
        CONTINUE.
      ENDIF.

      bump( iv_branch_id = is_plan-branch_id iv_field = 'po_received' ).

    ENDLOOP.

  ENDMETHOD.


*======================================================================*
*  SUMMARY
*======================================================================*
  METHOD print_summary.

    out->write( || ).
    out->write( |=== SUMMARY ===| ).
    out->write( || ).

    out->write( |Branch  SOcre SOcmp SOrej SOfail  L0  L1  L2   POcre POrcv POrej POfail  Revenue| ).

    DATA lv_t_created  TYPE i.
    DATA lv_t_complete TYPE i.
    DATA lv_t_rejected TYPE i.
    DATA lv_t_failed   TYPE i.
    DATA lv_t_l0       TYPE i.
    DATA lv_t_l1       TYPE i.
    DATA lv_t_l2       TYPE i.
    DATA lv_t_pocre    TYPE i.
    DATA lv_t_porcv    TYPE i.

    LOOP AT mt_stats INTO DATA(ls_st).
      out->write( |{ ls_st-branch_id }    { ls_st-so_created }   { ls_st-so_completed }   | &&
                  |{ ls_st-so_rejected }   { ls_st-so_failed }    | &&
                  |{ ls_st-lvl0 } { ls_st-lvl1 } { ls_st-lvl2 }    | &&
                  |{ ls_st-po_created }   { ls_st-po_received }   { ls_st-po_rejected }   | &&
                  |{ ls_st-po_failed }   { ls_st-revenue }| ).

      lv_t_created  = lv_t_created  + ls_st-so_created.
      lv_t_complete = lv_t_complete + ls_st-so_completed.
      lv_t_rejected = lv_t_rejected + ls_st-so_rejected.
      lv_t_failed   = lv_t_failed   + ls_st-so_failed.
      lv_t_l0       = lv_t_l0       + ls_st-lvl0.
      lv_t_l1       = lv_t_l1       + ls_st-lvl1.
      lv_t_l2       = lv_t_l2       + ls_st-lvl2.
      lv_t_pocre    = lv_t_pocre    + ls_st-po_created.
      lv_t_porcv    = lv_t_porcv    + ls_st-po_received.
    ENDLOOP.

    out->write( || ).
    out->write( |Sales orders created  : { lv_t_created } (target { gc_so_total })| ).
    out->write( |          completed   : { lv_t_complete }| ).
    out->write( |          rejected    : { lv_t_rejected } (on purpose)| ).
    out->write( |          failed      : { lv_t_failed }| ).
    out->write( |Purchase orders created / received : { lv_t_pocre } / { lv_t_porcv } (target { gc_po_total })| ).
    out->write( || ).

    "--- did the up-front level prediction match what the BO computed? ---
    IF mv_lvl_diff = 0.
      out->write( |Approval level prediction: matched the BO on every order.| ).
    ELSE.
      out->write( |Approval level prediction: { mv_lvl_diff } MISMATCH(ES) - listed under Failures.| ).
      out->write( |  Routing already followed the BO's own level, so the orders are correct;| ).
      out->write( |  the prediction is only used to group orders by approver.| ).
    ENDIF.
    out->write( || ).

    "--- how close the approval spread landed to 70 / 25 / 5 ---
    DATA(lv_submitted) = lv_t_l0 + lv_t_l1 + lv_t_l2.
    IF lv_submitted > 0.
      out->write( |Approval level spread (target 70 / 25 / 5 %):| ).
      out->write( |  Level 0 no approval      : { lv_t_l0 } ({ lv_t_l0 * 100 / lv_submitted }%)| ).
      out->write( |  Level 1 branch manager   : { lv_t_l1 } ({ lv_t_l1 * 100 / lv_submitted }%)| ).
      out->write( |  Level 2 regional manager : { lv_t_l2 } ({ lv_t_l2 * 100 / lv_submitted }%)| ).
    ENDIF.

    IF mt_failures IS NOT INITIAL.
      out->write( || ).
      out->write( |--- Failures ({ lines( mt_failures ) }) ---| ).
      LOOP AT mt_failures INTO DATA(lv_fail).
        out->write( |  { lv_fail }| ).
        IF sy-tabix >= 40.
          out->write( |  ... and { lines( mt_failures ) - 40 } more| ).
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    out->write( || ).
    out->write( |=== Done. Persona is currently the last one used - switch back with| ).
    out->write( |    ZCL_ITS_SWITCH_PERSONA before using Fiori. ===| ).

  ENDMETHOD.

ENDCLASS.
