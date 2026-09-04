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
             promo_id   TYPE zits_promo-promo_id,
             promo_pct  TYPE zits_promo-discount_percent,
           END OF ty_line,
           ty_lines TYPE STANDARD TABLE OF ty_line WITH EMPTY KEY.

    "--- named customers, for the orders big enough to have one ---
    TYPES: BEGIN OF ty_customer,
             partner_id TYPE zits_partner-partner_id,
           END OF ty_customer,
           ty_customers TYPE STANDARD TABLE OF ty_customer WITH EMPTY KEY.

    "--- promotions, split by the level they apply at ---
    TYPES: BEGIN OF ty_promo,
             promo_id         TYPE zits_promo-promo_id,
             promo_type       TYPE zits_promo-promo_type,
             product_id       TYPE zits_promo-product_id,
             discount_percent TYPE zits_promo-discount_percent,
             threshold_qty    TYPE zits_promo-threshold_qty,
             threshold_amount TYPE zits_promo-threshold_amount,
             valid_from       TYPE zits_promo-valid_from,
             valid_to         TYPE zits_promo-valid_to,
           END OF ty_promo,
           ty_promos TYPE STANDARD TABLE OF ty_promo WITH EMPTY KEY.

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
             item_promos  TYPE i,
             order_promos TYPE i,
             named_cust   TYPE i,
             revenue      TYPE zits_so-total_amount,
           END OF ty_stat,
           ty_stats TYPE STANDARD TABLE OF ty_stat WITH EMPTY KEY.

    DATA mt_products TYPE ty_products.
    DATA mt_weighted TYPE ty_weighted.
    DATA mt_promos    TYPE ty_promos.
    DATA mt_customers TYPE ty_customers.
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

    METHODS load_promos.

    METHODS load_customers.

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

    load_promos( ).
    IF mt_promos IS INITIAL.
      out->write( |No active promotions found - orders will be generated without discounts.| ).
    ELSE.
      out->write( |Found { lines( mt_promos ) } active promotions.| ).
    ENDIF.

    load_customers( ).
    IF mt_customers IS INITIAL.
      out->write( |No active customer partners found - every sale will be walk-in.| ).
    ELSE.
      out->write( |Found { lines( mt_customers ) } customer partners.| ).
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


  METHOD load_promos.

    "--- Only active promotions. Validity against the order's SalesDate is
    "    checked at the point of use, because the generated orders are
    "    backdated across three months. ---
    SELECT FROM zits_promo
      FIELDS promo_id, promo_type, product_id, discount_percent,
             threshold_qty, threshold_amount, valid_from, valid_to
      WHERE is_active = 'X'
      ORDER BY promo_id
      INTO TABLE @mt_promos.

  ENDMETHOD.


  METHOD load_customers.

    "--- 'B' counts too: a partner flagged as both buys as well as sells,
    "    the same rule validateCustomer applies ---
    SELECT FROM zits_partner
      FIELDS partner_id
      WHERE ( partner_role = 'C' OR partner_role = 'B' )
        AND is_active = 'X'
      ORDER BY partner_id
      INTO TABLE @mt_customers.

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
      WHEN 'item_promos'.  <ls_st>-item_promos  = <ls_st>-item_promos  + 1.
      WHEN 'order_promos'. <ls_st>-order_promos = <ls_st>-order_promos + 1.
      WHEN 'named_cust'.   <ls_st>-named_cust   = <ls_st>-named_cust   + 1.
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



  METHOD run_sales_batch.
*======================================================================*
*  SALES ORDERS
*======================================================================*
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

      "--- the date is settled first: promotion validity is judged against
      "    it while the lines are being built ---
      DATA lv_date TYPE d.
      lv_date = iv_from + next_int( lv_span ).

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

        "--- roughly one line in three carries its product's promotion, when
        "    one exists and covers the order's date. Not every line, so the
        "    reports still show a mix of discounted and full-price sales. ---
        DATA lv_line_promo TYPE zits_promo-promo_id.
        DATA lv_line_pct   TYPE zits_promo-discount_percent.
        CLEAR lv_line_promo.
        CLEAR lv_line_pct.

        IF next_int( 3 ) = 0.
          LOOP AT mt_promos INTO DATA(ls_ipromo)
            WHERE promo_type = 'I' AND product_id = lv_pid.

            IF ( ls_ipromo-valid_from IS INITIAL OR ls_ipromo-valid_from <= lv_date )
           AND ( ls_ipromo-valid_to   IS INITIAL OR ls_ipromo-valid_to   >= lv_date ).
              lv_line_promo = ls_ipromo-promo_id.
              lv_line_pct   = ls_ipromo-discount_percent.
              EXIT.
            ENDIF.

          ENDLOOP.
        ENDIF.

        APPEND VALUE #( product_id = lv_pid
                        quantity   = lv_qty
                        price      = ls_prod-sale_price
                        promo_id   = lv_line_promo
                        promo_pct  = lv_line_pct ) TO lt_lines.

        reserve( iv_branch_id  = is_plan-branch_id
                 iv_product_id = lv_pid
                 iv_qty        = lv_qty ).
      ENDDO.

      IF lt_lines IS INITIAL.
        APPEND |{ is_plan-branch_id } SO #{ lv_idx }: no sellable stock left| TO mt_failures.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'so_failed' ).
        CONTINUE.
      ENDIF.

      "--- Subtotal AFTER item discounts, which is the figure the BO's
      "    recalc_header will arrive at: SubtotalAmount is the sum of the
      "    item Amounts, and each of those is already net of its own
      "    promotion. An order-level threshold is measured against this. ---
      DATA lv_subtotal TYPE zits_so-subtotal_amount.
      DATA lv_totalqty TYPE zits_soitem-quantity.
      CLEAR lv_subtotal.
      CLEAR lv_totalqty.

      LOOP AT lt_lines INTO DATA(ls_line).
        DATA lv_gross TYPE zits_soitem-amount.
        lv_gross = ls_line-quantity * ls_line-price.
        IF ls_line-promo_pct > 0.
          lv_gross = lv_gross - ( lv_gross * ls_line-promo_pct / 100 ).
        ENDIF.
        lv_subtotal = lv_subtotal + lv_gross.
        lv_totalqty = lv_totalqty + ls_line-quantity.
      ENDLOOP.

      "--- roughly one order in three also carries an order-level promotion,
      "    but ONLY one whose threshold this order actually meets:
      "    validateOrderPromo rejects an unmet threshold and would fail the
      "    whole save rather than quietly skipping the discount. ---
      DATA lv_ord_promo TYPE zits_promo-promo_id.
      DATA lv_ord_pct   TYPE zits_promo-discount_percent.
      CLEAR lv_ord_promo.
      CLEAR lv_ord_pct.

      IF next_int( 3 ) = 0.
        LOOP AT mt_promos INTO DATA(ls_opromo)
          WHERE promo_type = 'Q' OR promo_type = 'A'.

          IF ( ls_opromo-valid_from IS NOT INITIAL AND ls_opromo-valid_from > lv_date )
          OR ( ls_opromo-valid_to   IS NOT INITIAL AND ls_opromo-valid_to   < lv_date ).
            CONTINUE.
          ENDIF.

          IF ( ls_opromo-promo_type = 'Q' AND lv_totalqty  >= ls_opromo-threshold_qty )
          OR ( ls_opromo-promo_type = 'A' AND lv_subtotal  >= ls_opromo-threshold_amount ).
            lv_ord_promo = ls_opromo-promo_id.
            lv_ord_pct   = ls_opromo-discount_percent.
            EXIT.
          ENDIF.

        ENDLOOP.
      ENDIF.

      "--- expected total, so the approval level is known up front and the
      "    orders can be grouped by approver instead of switching persona
      "    once per document. Discounts are subtracted here too, or the
      "    prediction would routinely disagree with the level the BO
      "    computes from the post-discount TotalAmount. ---
      DATA lv_total TYPE zits_so-total_amount.
      lv_total = lv_subtotal.
      IF lv_ord_pct > 0.
        lv_total = lv_total - ( lv_subtotal * lv_ord_pct / 100 ).
      ENDIF.

      DATA(lv_level) = zcl_its_approval=>get_required_level_so( lv_total ).

      "--- A named customer on the bigger orders only. The threshold is
      "    ZCL_ITS_APPROVAL's own branch limit rather than a new number of
      "    its own: an order large enough to need a manager's signature is
      "    the same order a business, not a passer-by, is placing. Below it
      "    the sale stays walk-in, which is what a retail counter mostly is.
      "
      "    Three in four rather than all of them - a company can still send
      "    somebody to buy over the counter without an account. ---
      DATA lv_customer TYPE zits_so-customer_id.
      CLEAR lv_customer.

      IF mt_customers IS NOT INITIAL
     AND lv_total >= zcl_its_approval=>gc_branch_limit
     AND next_int( 4 ) < 3.
        lv_customer = mt_customers[ 1 + next_int( lines( mt_customers ) ) ]-partner_id.
      ENDIF.

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
                             PaymentMethod = lv_pay
                             PromoID       = lv_ord_promo
                             CustomerID    = lv_customer ) ).

      DATA ls_items LIKE LINE OF so_items.
      CLEAR ls_items.
      ls_items-%cid_ref = lv_cid.

      LOOP AT lt_lines INTO ls_line.
        APPEND VALUE #( %cid      = |{ lv_cid }_{ sy-tabix }|
                        ProductID = ls_line-product_id
                        Quantity  = ls_line-quantity
                        PromoID   = ls_line-promo_id ) TO ls_items-%target.
      ENDLOOP.
      APPEND ls_items TO so_items.

      "--- only PromoID is sent; DiscountPercent, DiscountAmount, Amount,
      "    SubtotalAmount and TotalAmount are all computed by the BO's own
      "    determinations, exactly as they are for a hand-typed order ---
      MODIFY ENTITIES OF zi_its_salesorder
        ENTITY SalesOrder
          CREATE FIELDS ( SalesDate CurrencyCode PaymentMethod PromoID CustomerID ) WITH so_create
          CREATE BY \_Item FIELDS ( ProductID Quantity PromoID ) WITH so_items
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

      IF lv_ord_promo IS NOT INITIAL.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'order_promos' ).
      ENDIF.
      IF lv_customer IS NOT INITIAL.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'named_cust' ).
      ENDIF.
      LOOP AT lt_lines INTO ls_line WHERE promo_id IS NOT INITIAL.
        bump( iv_branch_id = is_plan-branch_id iv_field = 'item_promos' ).
      ENDLOOP.

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



  METHOD run_purchase_batch.
*======================================================================*
*  PURCHASE ORDERS
*======================================================================*
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



  METHOD print_summary.
*======================================================================*
*  SUMMARY
*======================================================================*
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

    "--- how much of the history carries a discount ---
    DATA lv_t_ipromo TYPE i.
    DATA lv_t_opromo TYPE i.
    DATA lv_t_cust   TYPE i.
    LOOP AT mt_stats INTO DATA(ls_pr).
      lv_t_ipromo = lv_t_ipromo + ls_pr-item_promos.
      lv_t_opromo = lv_t_opromo + ls_pr-order_promos.
      lv_t_cust   = lv_t_cust   + ls_pr-named_cust.
    ENDLOOP.

    IF mt_promos IS INITIAL.
      out->write( |Promotions: none active - all orders generated at full price.| ).
    ELSE.
      out->write( |Promotions applied: { lv_t_ipromo } item lines, { lv_t_opromo } orders| &&
                  | (roughly one in three of each, where one qualified).| ).
    ENDIF.

    out->write( |Named customers  : { lv_t_cust } of { lv_t_created } orders| &&
                | (only those at or above { zcl_its_approval=>gc_branch_limit } THB; the rest are walk-in).| ).
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

