CLASS lhc_SalesOrder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR SalesOrder RESULT result.

    METHODS setHeaderDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrder~setHeaderDefaults.

    METHODS calcTotalAmount FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrderitem~calcTotalAmount.

    METHODS validateItems FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateItems.

    METHODS fetchProductData FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrderItem~fetchProductData.

    METHODS validateQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrderItem~validateQuantity.

    METHODS assignSONumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR SalesOrder~assignSONumber.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR SalesOrder RESULT result.

    METHODS Submit   FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Submit   RESULT result.
    METHODS Approve  FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Approve  RESULT result.
    METHODS Reject   FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Reject   RESULT result.
    METHODS Cancel   FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Cancel   RESULT result.
    METHODS Complete FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Complete RESULT result.

ENDCLASS.


CLASS lhc_SalesOrder IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* HEADER DEFAULTS - status, date, currency on create
*--------------------------------------------------------------------*
  METHOD setHeaderDefaults.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( OverallStatus SalesDate CurrencyCode )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.

    LOOP AT orders INTO DATA(order).
      DATA(changed) = abap_false.

      IF order-OverallStatus IS INITIAL.
        order-OverallStatus = 'D'.            "Draft
        changed = abap_true.
      ENDIF.
      IF order-SalesDate IS INITIAL.
        order-SalesDate = cl_abap_context_info=>get_system_date( ).
        changed = abap_true.
      ENDIF.
      IF order-CurrencyCode IS INITIAL.
        order-CurrencyCode = 'THB'.
        changed = abap_true.
      ENDIF.

      IF changed = abap_true.
        APPEND VALUE #( %tky          = order-%tky
                        OverallStatus = order-OverallStatus
                        SalesDate     = order-SalesDate
                        CurrencyCode  = order-CurrencyCode ) TO updates.
      ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrder
          UPDATE FIELDS ( OverallStatus SalesDate CurrencyCode )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* ITEM - fetch Unit + SalePrice from Product, calc line Amount
*--------------------------------------------------------------------*
  METHOD fetchProductData.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( ProductID Quantity SalePrice Unit )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorderitem.

    LOOP AT items INTO DATA(item).

      IF item-ProductID IS INITIAL.
        CONTINUE.
      ENDIF.

      "--- read master data of the chosen product ---
      SELECT SINGLE FROM zits_product
        FIELDS unit, sale_price, currency_code
        WHERE product_id = @item-ProductID
        INTO @DATA(product).

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      "--- fill Unit if empty ---
      IF item-Unit IS INITIAL.
        item-Unit = product-unit.
      ENDIF.

      "--- fill SalePrice if empty (leave user-edited price alone) ---
      IF item-SalePrice IS INITIAL.
        item-SalePrice = product-sale_price.
      ENDIF.

      "--- calculate line amount ---
      DATA(line_amount) = item-Quantity * item-SalePrice.

      APPEND VALUE #( %tky         = item-%tky
                      Unit         = item-Unit
                      SalePrice    = item-SalePrice
                      Amount       = line_amount
                      CurrencyCode = product-currency_code ) TO updates.

    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrderItem
          UPDATE FIELDS ( Unit SalePrice Amount CurrencyCode )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* HEADER - sum item amounts, set order type by threshold
*--------------------------------------------------------------------*
  METHOD calcTotalAmount.

    DATA total_threshold TYPE p LENGTH 15 DECIMALS 2 VALUE '50000.00'.

    "--- from item keys, find their parent header keys ---
    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem BY \_SalesOrder
        FROM CORRESPONDING #( keys )
      RESULT DATA(headers).

    "--- remove duplicate headers (many items -> same header) ---
    SORT headers BY %tky.
    DELETE ADJACENT DUPLICATES FROM headers COMPARING %tky.

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.

    LOOP AT headers INTO DATA(header).

      READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrder BY \_Item
          FIELDS ( Amount )
          WITH VALUE #( ( %tky = header-%tky ) )
        RESULT DATA(items).

      DATA(sum_amount) = REDUCE zits_so-total_amount(
                           INIT s = CONV zits_so-total_amount( 0 )
                           FOR it IN items
                           NEXT s = s + it-Amount ).

      DATA(order_type) = COND #( WHEN sum_amount > total_threshold THEN 'S' ELSE 'N' ).

      APPEND VALUE #( %tky        = header-%tky
                      TotalAmount = sum_amount
                      OrderType   = order_type ) TO updates.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrder
          UPDATE FIELDS ( TotalAmount OrderType )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.

*--------------------------------------------------------------------*
* VALIDATION - quantity must be a positive whole number
*--------------------------------------------------------------------*
  METHOD validateQuantity.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( Quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).

      IF item-Quantity <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-salesorderitem.
        APPEND VALUE #( %tky              = item-%tky
                        %element-Quantity = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Quantity must be greater than zero' )
                      ) TO reported-salesorderitem.

      ELSEIF frac( item-Quantity ) <> 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-salesorderitem.
        APPEND VALUE #( %tky              = item-%tky
                        %element-Quantity = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Quantity must be a whole number' )
                      ) TO reported-salesorderitem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - order must have at least one item
*--------------------------------------------------------------------*
  METHOD validateItems.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( SONumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).

      READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrder BY \_Item
          FIELDS ( SOItemUUID )
          WITH VALUE #( ( %tky = order-%tky ) )
        RESULT DATA(items).

      IF items IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Sales order must have at least one item' )
                      ) TO reported-salesorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.
  METHOD assignSONumber.

    "--- อ่าน order ที่กำลัง save และยังไม่มีเลข ---
    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( SONumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    "--- หาเลขล่าสุดจากตารางจริง ---
    SELECT SINGLE FROM zits_so
      FIELDS MAX( so_number )
      INTO @DATA(max_number).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.

    LOOP AT orders INTO DATA(order).

      "--- ข้ามใบที่มีเลขอยู่แล้ว (กันเลขเปลี่ยนตอน update) ---
      IF order-SONumber IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      max_number += 1.

      APPEND VALUE #( %tky     = order-%tky
                      SONumber = max_number ) TO updates.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrder
          UPDATE FIELDS ( SONumber )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( OverallStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    result = VALUE #( FOR order IN orders
      ( %tky = order-%tky

        %action-Submit   = COND #( WHEN order-OverallStatus = 'D'
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )

        %action-Approve  = COND #( WHEN order-OverallStatus = 'P'
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )

        %action-Reject   = COND #( WHEN order-OverallStatus = 'P'
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )

        %action-Cancel   = COND #( WHEN order-OverallStatus = 'D' OR order-OverallStatus = 'S'
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )

        %action-Complete = COND #( WHEN order-OverallStatus = 'C'
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )
      ) ).

  ENDMETHOD.

  METHOD Submit.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder FIELDS ( OverallStatus OrderType )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'D'.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky          = order-%tky
                      OverallStatus = COND #( WHEN order-OrderType = 'S' THEN 'P' ELSE 'C' )
                    ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder UPDATE FIELDS ( OverallStatus ) WITH updates
      REPORTED DATA(rep).

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).

  ENDMETHOD.


*--------------------------------------------------------------------*
* APPROVE - manager only; Pending -> Confirmed
*--------------------------------------------------------------------*
  METHOD Approve.

    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).
    SELECT SINGLE FROM zits_employee FIELDS employee_id
      WHERE user_name = @current_user AND role_code = 'M' AND is_active = 'X'
      INTO @DATA(manager_id).

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.
    GET TIME STAMP FIELD DATA(now).

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'P'.
        CONTINUE.
      ENDIF.

      IF manager_id IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Only the manager can approve orders' )
                      ) TO reported-salesorder.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky          = order-%tky
                      OverallStatus = 'C'
                      ApprovedBy    = manager_id
                      ApprovedAt    = now ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder UPDATE FIELDS ( OverallStatus ApprovedBy ApprovedAt ) WITH updates
      REPORTED DATA(rep).

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).

  ENDMETHOD.


*--------------------------------------------------------------------*
* REJECT - manager only; Pending -> Rejected
*--------------------------------------------------------------------*
  METHOD Reject.

    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).
    SELECT SINGLE FROM zits_employee FIELDS employee_id
      WHERE user_name = @current_user AND role_code = 'M' AND is_active = 'X'
      INTO @DATA(manager_id).

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'P'.
        CONTINUE.
      ENDIF.

      IF manager_id IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Only the manager can reject orders' )
                      ) TO reported-salesorder.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky            = order-%tky
                      OverallStatus   = 'X'
                      RejectionReason = 'Rejected by manager' ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder UPDATE FIELDS ( OverallStatus RejectionReason ) WITH updates
      REPORTED DATA(rep).

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).

  ENDMETHOD.


*--------------------------------------------------------------------*
* CANCEL - salesperson; Draft/Submitted -> Rejected
*--------------------------------------------------------------------*
  METHOD Cancel.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'D' AND order-OverallStatus <> 'S'.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky            = order-%tky
                      OverallStatus   = 'X'
                      RejectionReason = 'Cancelled by salesperson' ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder UPDATE FIELDS ( OverallStatus RejectionReason ) WITH updates
      REPORTED DATA(rep).

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).

  ENDMETHOD.


*--------------------------------------------------------------------*
* COMPLETE - salesperson; Confirmed -> Completed
* (Round 4: จะเพิ่มการตัดสต๊อก + ลง ledger ตรงนี้)
*--------------------------------------------------------------------*
  METHOD Complete.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'C'.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky          = order-%tky
                      OverallStatus = 'F' ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder UPDATE FIELDS ( OverallStatus ) WITH updates
      REPORTED DATA(rep).

    "==== Round 4 จะเพิ่มตรงนี้: EML ตัดสต๊อกที่ Product + สร้าง Ledger entry ====

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).

  ENDMETHOD.

ENDCLASS.
