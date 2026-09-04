CLASS zcl_its_gen_master DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.


CLASS zcl_its_gen_master IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    DATA lt_company  TYPE STANDARD TABLE OF zits_company.
    DATA lt_region   TYPE STANDARD TABLE OF zits_region.
    DATA lt_branch   TYPE STANDARD TABLE OF zits_branch.
    DATA lt_costctr  TYPE STANDARD TABLE OF zits_costctr.
    DATA lt_glacct   TYPE STANDARD TABLE OF zits_glacct.
    DATA lt_partner  TYPE STANDARD TABLE OF zits_partner.
    DATA lt_promo    TYPE STANDARD TABLE OF zits_promo.
    DATA lt_stock    TYPE STANDARD TABLE OF zits_stock.

    "--- context values (ABAP Cloud compliant) ---
    GET TIME STAMP FIELD DATA(lv_now).
    DATA(lv_user)  = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    "--- clear existing demo data (safe to re-run) ---
    DELETE FROM zits_company.
    DELETE FROM zits_region.
    DELETE FROM zits_branch.
    DELETE FROM zits_costctr.
    DELETE FROM zits_glacct.
    DELETE FROM zits_partner.
    DELETE FROM zits_promo.
    DELETE FROM zits_stock.

*--------------------------------------------------------------------*
* 1. COMPANY
*--------------------------------------------------------------------*
    lt_company = VALUE #(
      ( company_id   = 'ITZ'
        company_name = 'ITZone'
        legal_name   = 'ITZone Company Limited'
        tax_id       = '0105566001234'
        currency     = 'THB'
        address      = '199 Rama I Road, Pathum Wan, Bangkok 10330'
        phone        = '02-610-9000'
        is_active    = 'X' )
    ).

*--------------------------------------------------------------------*
* 2. REGION
*   region_manager_id left blank on purpose - see notes at end of file
*--------------------------------------------------------------------*
    lt_region = VALUE #(
      company_id = 'ITZ'
      is_active  = 'X'
      ( region_id = 'CEN' region_name = 'Central Region' )
      ( region_id = 'NOR' region_name = 'Northern Region' )
    ).

*--------------------------------------------------------------------*
* 3. BRANCH (Plant)
*--------------------------------------------------------------------*
    lt_branch = VALUE #(
      is_active = 'X'
      ( branch_id    = 'BR01'
        branch_name  = 'Siam Paragon'
        region_id    = 'CEN'
        address      = '991 Rama I Road, Pathum Wan, Bangkok 10330'
        phone        = '02-610-8000'
        opening_date = '20220301' )

      ( branch_id    = 'BR02'
        branch_name  = 'Central Ladprao'
        region_id    = 'CEN'
        address      = '1697 Phahonyothin Road, Chatuchak, Bangkok 10900'
        phone        = '02-541-1000'
        opening_date = '20230115' )

      ( branch_id    = 'BR03'
        branch_name  = 'Central Chiang Mai'
        region_id    = 'NOR'
        address      = '99/3 Mahidol Road, Nong Hoi, Chiang Mai 50000'
        phone        = '053-998-000'
        opening_date = '20240901' )
    ).

*--------------------------------------------------------------------*
* 4. COST CENTER
*   cc_type: S = Sales (branch), A = Administration (head office)
*--------------------------------------------------------------------*
    lt_costctr = VALUE #(
      is_active = 'X'
      ( cost_center_id = 'CC-BR01' cc_name = 'Siam Paragon Branch'       branch_id = 'BR01' cc_type = 'S' )
      ( cost_center_id = 'CC-BR02' cc_name = 'Central Ladprao Branch'    branch_id = 'BR02' cc_type = 'S' )
      ( cost_center_id = 'CC-BR03' cc_name = 'Central Chiang Mai Branch' branch_id = 'BR03' cc_type = 'S' )
      ( cost_center_id = 'CC-HQ'   cc_name = 'Head Office'               branch_id = ''     cc_type = 'A' )
    ).

*--------------------------------------------------------------------*
* 5. GL ACCOUNT (Chart of Accounts)
*   account_type  : A=Asset L=Liability E=Equity R=Revenue X=Expense
*   normal_balance: D=Debit  C=Credit
*--------------------------------------------------------------------*
    lt_glacct = VALUE #(
      is_active = 'X'
      ( gl_account = '100000' account_name = 'Cash'                 account_type = 'A' normal_balance = 'D' account_group = 'CURRENT ASSET' )
      ( gl_account = '102000' account_name = 'Bank'                 account_type = 'A' normal_balance = 'D' account_group = 'CURRENT ASSET' )
      ( gl_account = '120000' account_name = 'Accounts Receivable'  account_type = 'A' normal_balance = 'D' account_group = 'CURRENT ASSET' )
      ( gl_account = '130000' account_name = 'Inventory'            account_type = 'A' normal_balance = 'D' account_group = 'CURRENT ASSET' )
      ( gl_account = '201000' account_name = 'Accounts Payable'     account_type = 'L' normal_balance = 'C' account_group = 'LIABILITY' )
      ( gl_account = '300000' account_name = 'Owner Equity'         account_type = 'E' normal_balance = 'C' account_group = 'EQUITY' )
      ( gl_account = '400000' account_name = 'Sales Revenue'        account_type = 'R' normal_balance = 'C' account_group = 'REVENUE' )
      ( gl_account = '500000' account_name = 'Cost of Goods Sold'   account_type = 'X' normal_balance = 'D' account_group = 'COST' )
      ( gl_account = '600000' account_name = 'Operating Expense'    account_type = 'X' normal_balance = 'D' account_group = 'EXPENSE' )
      ( gl_account = '900000' account_name = 'Stock in Transit'     account_type = 'A' normal_balance = 'D' account_group = 'CURRENT ASSET' )
    ).

*--------------------------------------------------------------------*
* 6. BUSINESS PARTNER
*   partner_role: C=Customer S=Supplier B=Both
*   partner_type: P=Person   O=Organization
*--------------------------------------------------------------------*
    lt_partner = VALUE #(
      is_active = 'X'

      "--- suppliers ---
      ( partner_id = 'SUP001' partner_name = 'ThaiTech Distribution Co., Ltd.'
        partner_role = 'S' partner_type = 'O' tax_id = '0105540011111'
        address = 'Bang Rak, Bangkok'    phone = '02-233-4455' email = 'sales@thaitech.example'    payment_terms = 'N30' )
      ( partner_id = 'SUP002' partner_name = 'Asia Component Supply Co., Ltd.'
        partner_role = 'S' partner_type = 'O' tax_id = '0105540022222'
        address = 'Huai Khwang, Bangkok' phone = '02-276-8899' email = 'order@asiacomp.example'    payment_terms = 'N30' )
      ( partner_id = 'SUP003' partner_name = 'Siam IT Wholesale Co., Ltd.'
        partner_role = 'S' partner_type = 'O' tax_id = '0105540033333'
        address = 'Pathum Wan, Bangkok'  phone = '02-251-7700' email = 'contact@siamit.example'    payment_terms = 'N60' )
      ( partner_id = 'SUP004' partner_name = 'Northern PC Parts Co., Ltd.'
        partner_role = 'S' partner_type = 'O' tax_id = '0505540044444'
        address = 'Mueang, Chiang Mai'   phone = '053-221-330' email = 'sales@northpc.example'     payment_terms = 'N30' )
      ( partner_id = 'SUP005' partner_name = 'Mega Accessory Trading Co., Ltd.'
        partner_role = 'S' partner_type = 'O' tax_id = '0105540055555'
        address = 'Chatuchak, Bangkok'   phone = '02-513-6600' email = 'info@megaacc.example'      payment_terms = 'CASH' )

      "--- customers ---
      ( partner_id = 'CUS001' partner_name = 'OfficeMate Solution Co., Ltd.'
        partner_role = 'C' partner_type = 'O' tax_id = '0105550011111'
        address = 'Sathon, Bangkok'      phone = '02-679-1200' email = 'purchase@officemate.example' payment_terms = 'N30' )
      ( partner_id = 'CUS002' partner_name = 'Bangkok Digital Group Co., Ltd.'
        partner_role = 'C' partner_type = 'O' tax_id = '0105550022222'
        address = 'Watthana, Bangkok'    phone = '02-260-4400' email = 'it@bkkdigital.example'      payment_terms = 'N30' )
      ( partner_id = 'CUS003' partner_name = 'Sathit Science School'
        partner_role = 'C' partner_type = 'O' tax_id = '0994000111222'
        address = 'Phaya Thai, Bangkok'  phone = '02-215-8800' email = 'admin@sathitsci.example'    payment_terms = 'N60' )
      ( partner_id = 'CUS004' partner_name = 'Chiang Mai Software House Co., Ltd.'
        partner_role = 'C' partner_type = 'O' tax_id = '0505550044444'
        address = 'Mueang, Chiang Mai'   phone = '053-404-100' email = 'admin@cmsoft.example'       payment_terms = 'N30' )
      ( partner_id = 'CUS005' partner_name = 'Somchai Wattanakul'
        partner_role = 'C' partner_type = 'P' tax_id = '1100400556677'
        address = 'Din Daeng, Bangkok'   phone = '081-234-5678' email = 'somchai.w@mail.example'    payment_terms = 'CASH' )
      ( partner_id = 'CUS006' partner_name = 'Ladprao Logistics Co., Ltd.'
        partner_role = 'C' partner_type = 'O' tax_id = '0105550066666'
        address = 'Chatuchak, Bangkok'   phone = '02-938-2200' email = 'office@lplogistics.example' payment_terms = 'N30' )
      ( partner_id = 'CUS007' partner_name = 'Siam Smile Dental Clinic'
        partner_role = 'C' partner_type = 'O' tax_id = '0105550077777'
        address = 'Pathum Wan, Bangkok'  phone = '02-251-9900' email = 'contact@siamsmile.example'  payment_terms = 'CASH' )
      ( partner_id = 'CUS008' partner_name = 'Idea Creative Studio Co., Ltd.'
        partner_role = 'C' partner_type = 'O' tax_id = '0105550088888'
        address = 'Bang Kapi, Bangkok'   phone = '02-731-4500' email = 'hello@ideastudio.example'   payment_terms = 'N30' )
      ( partner_id = 'CUS009' partner_name = 'Napatsorn Thongdee'
        partner_role = 'C' partner_type = 'P' tax_id = '1509900112233'
        address = 'Mueang, Chiang Mai'   phone = '089-876-5432' email = 'napatsorn.t@mail.example'  payment_terms = 'CASH' )
    ).

*--------------------------------------------------------------------*
* 7. STOCK  (branch x product)
*   Quantities are shaped on purpose:
*     BR01 highest, BR02 medium, BR03 lowest
*     some rows fall below reorder level so the low-stock report and
*     the stock-transfer scenario both have real data to show
*--------------------------------------------------------------------*
    SELECT product_id, unit
      FROM zits_product
      ORDER BY product_id
      INTO TABLE @DATA(lt_product).

    DATA lv_idx     TYPE i VALUE 0.
    DATA lv_base    TYPE i.
    DATA lv_qty01   TYPE i.
    DATA lv_qty02   TYPE i.
    DATA lv_qty03   TYPE i.
    DATA lv_reorder TYPE i.

    LOOP AT lt_product INTO DATA(ls_product).

      lv_idx = lv_idx + 1.

      "--- spread base quantity 10..46 so branches look different ---
      lv_base    = 10 + ( lv_idx MOD 7 ) * 6.
      lv_reorder = 5.

      lv_qty01 = lv_base.
      lv_qty02 = lv_base * 60 / 100.
      lv_qty03 = lv_base * 35 / 100.

      "--- force some shortages: Chiang Mai runs out, Ladprao runs low ---
      IF lv_idx MOD 4 = 0.
        lv_qty03 = 0.
      ENDIF.
      IF lv_idx MOD 5 = 0.
        lv_qty02 = 2.
      ENDIF.

      APPEND VALUE #( branch_id          = 'BR01'
                      product_id         = ls_product-product_id
                      qty_on_hand        = lv_qty01
                      qty_reserved       = 0
                      reorder_level      = lv_reorder
                      unit               = ls_product-unit
                      last_movement_date = lv_today ) TO lt_stock.

      APPEND VALUE #( branch_id          = 'BR02'
                      product_id         = ls_product-product_id
                      qty_on_hand        = lv_qty02
                      qty_reserved       = 0
                      reorder_level      = lv_reorder
                      unit               = ls_product-unit
                      last_movement_date = lv_today ) TO lt_stock.

      APPEND VALUE #( branch_id          = 'BR03'
                      product_id         = ls_product-product_id
                      qty_on_hand        = lv_qty03
                      qty_reserved       = 0
                      reorder_level      = lv_reorder
                      unit               = ls_product-unit
                      last_movement_date = lv_today ) TO lt_stock.

    ENDLOOP.

*--------------------------------------------------------------------*
* 7b. PROMOTIONS
*     Validity spans the whole generated history window and beyond, so a
*     backdated order never falls outside it. ZCL_ITS_GEN_TRANSACTIONS
*     applies these to a minority of orders.
*
*     promo_type: I = one product, Q = quantity threshold, A = order amount
*     Each type fills exactly ONE qualifying field and leaves the other two
*     empty - that is what validateTypeFields on the Promotion BO enforces.
*--------------------------------------------------------------------*
    DATA lv_promo_from TYPE d.
    DATA lv_promo_to   TYPE d.
    lv_promo_from = lv_today - 180.
    lv_promo_to   = lv_today + 180.

    lt_promo = VALUE #(
      currency_code = 'THB'
      unit          = 'EA'
      is_active     = 'X'
      valid_from    = lv_promo_from
      valid_to      = lv_promo_to

      "--- type I: a specific product is discounted ---
      ( promo_id = 'PR-ACC10'  promo_name = 'Accessory Deal 10%'
        promo_type = 'I'  product_id = 'P0007'  discount_percent = '10.00' )

      ( promo_id = 'PR-KBD15'  promo_name = 'Keyboard Clearance 15%'
        promo_type = 'I'  product_id = 'P0009'  discount_percent = '15.00' )

      ( promo_id = 'PR-NBK05'  promo_name = 'Notebook Promotion 5%'
        promo_type = 'I'  product_id = 'P0001'  discount_percent = '5.00' )

      "--- type Q: buy this many units in one order ---
      ( promo_id = 'PR-BULK5'  promo_name = 'Bulk Buy 5 Units 5%'
        promo_type = 'Q'  threshold_qty = '5'  discount_percent = '5.00' )

      ( promo_id = 'PR-BULK10' promo_name = 'Bulk Buy 10 Units 8%'
        promo_type = 'Q'  threshold_qty = '10' discount_percent = '8.00' )

      "--- type A: spend this much in one order ---
      ( promo_id = 'PR-SPEND30' promo_name = 'Spend 30,000 Get 3%'
        promo_type = 'A'  threshold_amount = '30000.00' discount_percent = '3.00' )

      ( promo_id = 'PR-SPEND80' promo_name = 'Spend 80,000 Get 7%'
        promo_type = 'A'  threshold_amount = '80000.00' discount_percent = '7.00' )
    ).

*--------------------------------------------------------------------*
* 8. stamp admin fields and insert
*--------------------------------------------------------------------*
    LOOP AT lt_company ASSIGNING FIELD-SYMBOL(<ls_co>).
      <ls_co>-created_by            = lv_user.
      <ls_co>-created_at            = lv_now.
      <ls_co>-local_last_changed_by = lv_user.
      <ls_co>-local_last_changed_at = lv_now.
      <ls_co>-last_changed_at       = lv_now.
    ENDLOOP.

    LOOP AT lt_region ASSIGNING FIELD-SYMBOL(<ls_rg>).
      <ls_rg>-created_by            = lv_user.
      <ls_rg>-created_at            = lv_now.
      <ls_rg>-local_last_changed_by = lv_user.
      <ls_rg>-local_last_changed_at = lv_now.
      <ls_rg>-last_changed_at       = lv_now.
    ENDLOOP.

    LOOP AT lt_branch ASSIGNING FIELD-SYMBOL(<ls_br>).
      <ls_br>-created_by            = lv_user.
      <ls_br>-created_at            = lv_now.
      <ls_br>-local_last_changed_by = lv_user.
      <ls_br>-local_last_changed_at = lv_now.
      <ls_br>-last_changed_at       = lv_now.
    ENDLOOP.

    LOOP AT lt_costctr ASSIGNING FIELD-SYMBOL(<ls_cc>).
      <ls_cc>-created_by            = lv_user.
      <ls_cc>-created_at            = lv_now.
      <ls_cc>-local_last_changed_by = lv_user.
      <ls_cc>-local_last_changed_at = lv_now.
      <ls_cc>-last_changed_at       = lv_now.
    ENDLOOP.

    LOOP AT lt_glacct ASSIGNING FIELD-SYMBOL(<ls_gl>).
      <ls_gl>-created_by            = lv_user.
      <ls_gl>-created_at            = lv_now.
      <ls_gl>-local_last_changed_by = lv_user.
      <ls_gl>-local_last_changed_at = lv_now.
      <ls_gl>-last_changed_at       = lv_now.
    ENDLOOP.

    LOOP AT lt_partner ASSIGNING FIELD-SYMBOL(<ls_pa>).
      <ls_pa>-created_by            = lv_user.
      <ls_pa>-created_at            = lv_now.
      <ls_pa>-local_last_changed_by = lv_user.
      <ls_pa>-local_last_changed_at = lv_now.
      <ls_pa>-last_changed_at       = lv_now.
    ENDLOOP.

    LOOP AT lt_promo ASSIGNING FIELD-SYMBOL(<ls_pr>).
      <ls_pr>-created_by            = lv_user.
      <ls_pr>-created_at            = lv_now.
      <ls_pr>-local_last_changed_by = lv_user.
      <ls_pr>-local_last_changed_at = lv_now.
      <ls_pr>-last_changed_at       = lv_now.
    ENDLOOP.

    LOOP AT lt_stock ASSIGNING FIELD-SYMBOL(<ls_st>).
      <ls_st>-created_by            = lv_user.
      <ls_st>-created_at            = lv_now.
      <ls_st>-local_last_changed_by = lv_user.
      <ls_st>-local_last_changed_at = lv_now.
      <ls_st>-last_changed_at       = lv_now.
    ENDLOOP.

    INSERT zits_company FROM TABLE @lt_company.
    INSERT zits_region  FROM TABLE @lt_region.
    INSERT zits_branch  FROM TABLE @lt_branch.
    INSERT zits_costctr FROM TABLE @lt_costctr.
    INSERT zits_glacct  FROM TABLE @lt_glacct.
    INSERT zits_partner FROM TABLE @lt_partner.
    INSERT zits_promo   FROM TABLE @lt_promo.
    INSERT zits_stock   FROM TABLE @lt_stock.

    COMMIT WORK.

*--------------------------------------------------------------------*
    out->write( |[ITZone] Companies      : { lines( lt_company ) }| ).
    out->write( |[ITZone] Regions        : { lines( lt_region ) }| ).
    out->write( |[ITZone] Branches       : { lines( lt_branch ) }| ).
    out->write( |[ITZone] Cost centers   : { lines( lt_costctr ) }| ).
    out->write( |[ITZone] GL accounts    : { lines( lt_glacct ) }| ).
    out->write( |[ITZone] Partners       : { lines( lt_partner ) }| ).
    out->write( |[ITZone] Products found : { lines( lt_product ) }| ).
    out->write( |[ITZone] Stock rows     : { lines( lt_stock ) }| ).
    out->write( |[ITZone] Master data generation finished.| ).

  ENDMETHOD.
ENDCLASS.

