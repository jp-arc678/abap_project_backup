CLASS zcl_its_gen_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_ITS_GEN_DATA IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    DATA lt_product  TYPE STANDARD TABLE OF zits_product.
    DATA lt_employee TYPE STANDARD TABLE OF zits_employee.
    DATA lt_ledger   TYPE STANDARD TABLE OF zits_ledger.

    "--- context values (ABAP Cloud compliant) ---
    GET TIME STAMP FIELD DATA(lv_now).
    DATA(lv_user)  = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    "--- clear existing demo data ---
    DELETE FROM zits_product.
    DELETE FROM zits_employee.
    DELETE FROM zits_ledger.

*--------------------------------------------------------------------*
* 1. PRODUCTS
*--------------------------------------------------------------------*
    lt_product = VALUE #(
      currency_code = 'THB'
      unit          = 'EA'
      is_active     = 'X'

      ( product_id = 'P0001' product_name = 'Notebook Business 14"'
        category = 'HARDWARE'  brand = 'Lenovo'
        description = 'Core i5 / 16GB RAM / 512GB SSD'
        sale_price = '24900.00' cost_price = '20500.00'
        stock_qty = '8'  reorder_level = '2' )

      ( product_id = 'P0002' product_name = 'Gaming Laptop 15"'
        category = 'HARDWARE'  brand = 'Asus'
        description = 'Core i7 / RTX 4060 / 16GB RAM'
        sale_price = '39900.00' cost_price = '33000.00'
        stock_qty = '5'  reorder_level = '2' )

      ( product_id = 'P0003' product_name = 'Desktop PC Office'
        category = 'HARDWARE'  brand = 'Dell'
        description = 'Core i5 / 8GB RAM / 256GB SSD'
        sale_price = '18900.00' cost_price = '15200.00'
        stock_qty = '6'  reorder_level = '2' )

      ( product_id = 'P0004' product_name = 'Monitor 27 inch IPS'
        category = 'HARDWARE'  brand = 'Samsung'
        description = 'QHD 2560x1440 / 75Hz'
        sale_price = '6900.00'  cost_price = '5400.00'
        stock_qty = '15' reorder_level = '4' )

      ( product_id = 'P0005' product_name = 'SSD NVMe 1TB'
        category = 'HARDWARE'  brand = 'Kingston'
        description = 'PCIe Gen4 read 7000MB/s'
        sale_price = '2790.00'  cost_price = '2100.00'
        stock_qty = '30' reorder_level = '8' )

      ( product_id = 'P0006' product_name = 'RAM DDR5 16GB'
        category = 'HARDWARE'  brand = 'Corsair'
        description = '5600MHz CL36'
        sale_price = '2290.00'  cost_price = '1750.00'
        stock_qty = '25' reorder_level = '8' )

      ( product_id = 'P0007' product_name = 'Wireless Mouse'
        category = 'ACCESSORY' brand = 'Logitech'
        description = 'Bluetooth + 2.4GHz dual mode'
        sale_price = '890.00'   cost_price = '620.00'
        stock_qty = '50' reorder_level = '15' )

      ( product_id = 'P0008' product_name = 'Mechanical Keyboard'
        category = 'ACCESSORY' brand = 'Keychron'
        description = 'TKL hot-swap RGB'
        sale_price = '3290.00'  cost_price = '2500.00'
        stock_qty = '20' reorder_level = '6' )

      ( product_id = 'P0009' product_name = 'USB-C Hub 7-in-1'
        category = 'ACCESSORY' brand = 'Anker'
        description = 'HDMI / USB3.0 x3 / SD / PD100W'
        sale_price = '1290.00'  cost_price = '900.00'
        stock_qty = '35' reorder_level = '10' )

      ( product_id = 'P0010' product_name = 'HDMI Cable 2m'
        category = 'ACCESSORY' brand = 'Ugreen'
        description = 'HDMI 2.1 8K support'
        sale_price = '390.00'   cost_price = '250.00'
        stock_qty = '80' reorder_level = '20' )
    ).

    LOOP AT lt_product ASSIGNING FIELD-SYMBOL(<ls_product>).
      <ls_product>-created_by            = lv_user.
      <ls_product>-created_at            = lv_now.
      <ls_product>-local_last_changed_by = lv_user.
      <ls_product>-local_last_changed_at = lv_now.
      <ls_product>-last_changed_at       = lv_now.
    ENDLOOP.

    INSERT zits_product FROM TABLE @lt_product.

*--------------------------------------------------------------------*
* 2. EMPLOYEES
*    role_code: M = Manager, S = Salesperson, W = Warehouse
*--------------------------------------------------------------------*
    lt_employee = VALUE #(
      is_active = 'X'
      ( employee_id = 'E0001' employee_name = 'Somchai Wattana'
        role_code = 'M' user_name = lv_user )
      ( employee_id = 'E0002' employee_name = 'Nattaya Sombat'
        role_code = 'S' user_name = 'SALES01' )
      ( employee_id = 'E0003' employee_name = 'Peerapat Chai'
        role_code = 'S' user_name = 'SALES02' )
      ( employee_id = 'E0004' employee_name = 'Kanya Rungrot'
        role_code = 'W' user_name = 'WHOUSE01' )
    ).

    LOOP AT lt_employee ASSIGNING FIELD-SYMBOL(<ls_employee>).
      <ls_employee>-created_by            = lv_user.
      <ls_employee>-created_at            = lv_now.
      <ls_employee>-local_last_changed_by = lv_user.
      <ls_employee>-local_last_changed_at = lv_now.
      <ls_employee>-last_changed_at       = lv_now.
    ENDLOOP.

    INSERT zits_employee FROM TABLE @lt_employee.

*--------------------------------------------------------------------*
* 3. LEDGER - opening shop budget
*    entry_type: I = Income, E = Expense
*--------------------------------------------------------------------*
    lt_ledger = VALUE #(
      currency_code = 'THB'
      posting_date  = lv_today
      created_by    = lv_user
      created_at    = lv_now

      ( ledger_uuid  = cl_system_uuid=>create_uuid_x16_static( )
        entry_type   = 'I'
        amount       = '500000.00'
        ref_doc_type = 'OB'
        description  = 'Opening shop budget' )
    ).

    INSERT zits_ledger FROM TABLE @lt_ledger.

    COMMIT WORK.

*--------------------------------------------------------------------*
    out->write( |[IT SHOP] Products created : { lines( lt_product ) }| ).
    out->write( |[IT SHOP] Employees created: { lines( lt_employee ) }| ).
    out->write( |[IT SHOP] Ledger entries   : { lines( lt_ledger ) }| ).
    out->write( |[IT SHOP] Demo data generation finished.| ).

  ENDMETHOD.
ENDCLASS.
