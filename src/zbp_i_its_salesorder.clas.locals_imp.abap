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

    METHODS validateBranch FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateBranch.

    METHODS validateSalesperson FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateSalesperson.

    METHODS validateCreatorRole FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateCreatorRole.

    METHODS validateCustomer FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrder~validateCustomer.

    METHODS fetchProductData FOR DETERMINE ON MODIFY
      IMPORTING keys FOR SalesOrderItem~fetchProductData.

    METHODS validateQuantity FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrderItem~validateQuantity.

    METHODS validateStock FOR VALIDATE ON SAVE
      IMPORTING keys FOR SalesOrderItem~validateStock.

    METHODS assignSONumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR SalesOrder~assignSONumber.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR SalesOrder RESULT result.

    METHODS getItemFeatures FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR SalesOrderItem RESULT result.

    METHODS Submit   FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Submit   RESULT result.
    METHODS Approve  FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Approve  RESULT result.
    METHODS Reject   FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Reject   RESULT result.
    METHODS Cancel   FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Cancel   RESULT result.
    METHODS Complete FOR MODIFY IMPORTING keys FOR ACTION SalesOrder~Complete RESULT result.

ENDCLASS.


CLASS lhc_SalesOrder IMPLEMENTATION.

*--------------------------------------------------------------------*
* GLOBAL AUTHORIZATION - regional managers cannot create sales orders
* (this is what disables the "Create" button on the list report
* itself, before any draft exists - see also validateCreatorRole,
* which is the same rule enforced again at save time as a safety net)
*--------------------------------------------------------------------*
  METHOD get_global_authorizations.

    IF requested_authorizations-%create = if_abap_behv=>mk-on.

      DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

      SELECT SINGLE FROM zits_employee
        FIELDS role_code
        WHERE upper( user_name ) = @current_user
          AND is_active = 'X'
        INTO @DATA(creator_role).

      result-%create = COND #( WHEN creator_role = 'R'
                               THEN if_abap_behv=>auth-unauthorized
                               ELSE if_abap_behv=>auth-allowed ).

    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* HEADER DEFAULTS - status, date, currency on create
*--------------------------------------------------------------------*
  METHOD setHeaderDefaults.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( OverallStatus SalesDate CurrencyCode BranchID SalespersonID PaymentMethod )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    "--- employee record of the current user, if any, for the auto-fill below ---
    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).
    SELECT SINGLE FROM zits_employee
      FIELDS employee_id, branch_id
      WHERE upper( user_name ) = @current_user AND is_active = 'X'
      INTO @DATA(current_employee).

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
      IF order-PaymentMethod IS INITIAL.
        order-PaymentMethod = 'C'.            "Cash - the walk-in default
        changed = abap_true.
      ENDIF.
      IF order-BranchID IS INITIAL AND current_employee-branch_id IS NOT INITIAL.
        order-BranchID = current_employee-branch_id.
        changed = abap_true.
      ENDIF.
      IF order-SalespersonID IS INITIAL AND current_employee-employee_id IS NOT INITIAL.
        order-SalespersonID = current_employee-employee_id.
        changed = abap_true.
      ENDIF.

      IF changed = abap_true.
        APPEND VALUE #( %tky          = order-%tky
                        OverallStatus = order-OverallStatus
                        SalesDate     = order-SalesDate
                        CurrencyCode  = order-CurrencyCode
                        BranchID      = order-BranchID
                        SalespersonID = order-SalespersonID
                        PaymentMethod = order-PaymentMethod ) TO updates.
      ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrder
          UPDATE FIELDS ( OverallStatus SalesDate CurrencyCode BranchID
                          SalespersonID PaymentMethod )
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
        FIELDS ( ProductID Quantity SalePrice CostPrice Unit )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorderitem.

    LOOP AT items INTO DATA(item).

      IF item-ProductID IS INITIAL.
        CONTINUE.
      ENDIF.

      "--- read master data of the chosen product ---
      SELECT SINGLE FROM zits_product
        FIELDS unit, sale_price, cost_price, currency_code
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

      "--- snapshot what the product costs us right now. This is the figure
      "    booked to cost of goods sold when the order is completed, so it
      "    must be the cost AT THE TIME OF SALE - once taken it is never
      "    refreshed, even if the product master price changes later. ---
      IF item-CostPrice IS INITIAL.
        item-CostPrice = product-cost_price.
      ENDIF.

      "--- calculate line amount ---
      DATA(line_amount) = item-Quantity * item-SalePrice.

      APPEND VALUE #( %tky         = item-%tky
                      Unit         = item-Unit
                      SalePrice    = item-SalePrice
                      CostPrice    = item-CostPrice
                      Amount       = line_amount
                      CurrencyCode = product-currency_code ) TO updates.

    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrderItem
          UPDATE FIELDS ( Unit SalePrice CostPrice Amount CurrencyCode )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* ITEM FEATURES - items are locked once the parent order is Completed
* (same "no edits after the final state" rule as the header)
*--------------------------------------------------------------------*
  METHOD getItemFeatures.

    LOOP AT keys INTO DATA(item_key).

      READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrderItem BY \_SalesOrder
          FIELDS ( OverallStatus )
          WITH VALUE #( ( %tky = item_key-%tky ) )
        RESULT DATA(headers).

      READ TABLE headers INTO DATA(header) INDEX 1.

      DATA(is_locked) = COND abap_bool( WHEN sy-subrc = 0 AND header-OverallStatus = 'F'
                                        THEN abap_true ELSE abap_false ).

      APPEND VALUE #( %tky    = item_key-%tky
                      %update = COND #( WHEN is_locked = abap_true
                                        THEN if_abap_behv=>fc-o-disabled
                                        ELSE if_abap_behv=>fc-o-enabled )
                      %delete = COND #( WHEN is_locked = abap_true
                                        THEN if_abap_behv=>fc-o-disabled
                                        ELSE if_abap_behv=>fc-o-enabled )
                    ) TO result.

    ENDLOOP.

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


*--------------------------------------------------------------------*
* VALIDATION - Branch must be entered and must exist
*--------------------------------------------------------------------*
  METHOD validateBranch.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( BranchID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).

      IF order-BranchID IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky              = order-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch must be entered' )
                      ) TO reported-salesorder.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_branch
        FIELDS branch_id
        WHERE branch_id = @order-BranchID
        INTO @DATA(existing_branch).

      IF existing_branch IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky              = order-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch does not exist' )
                      ) TO reported-salesorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Salesperson is derived from the current user; if it's
* still blank, the current user has no active Employee record
*--------------------------------------------------------------------*
  METHOD validateSalesperson.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( SalespersonID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).

      IF order-SalespersonID IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Your user is not linked to an active employee record' )
                      ) TO reported-salesorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - the customer, when there is one
*
* Mirror of PurchaseOrder's validateSupplier, with one deliberate
* difference: a blank CustomerID is VALID and means a walk-in sale. Most
* counter sales have no named customer, so this only checks the partner
* when one was actually chosen.
*
* Existence and role are checked, but NOT is_active: a partner can be
* deactivated after an order was raised, and that must not make the old
* order impossible to save. The value help already hides inactive
* partners, so a new order cannot pick one in the first place.
*--------------------------------------------------------------------*
  METHOD validateCustomer.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( CustomerID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).

      "--- walk-in: nothing to check ---
      IF order-CustomerID IS INITIAL.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_partner
        FIELDS partner_id
        WHERE partner_id = @order-CustomerID
          AND ( partner_role = 'C' OR partner_role = 'B' )
        INTO @DATA(existing_customer).

      IF existing_customer IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky                = order-%tky
                        %element-CustomerID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Customer does not exist or is not a customer partner' )
                      ) TO reported-salesorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - regional managers cannot create sales orders
* (segregation of duties: an approver must not create what they approve)
*--------------------------------------------------------------------*
  METHOD validateCreatorRole.

    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    SELECT SINGLE FROM zits_employee
      FIELDS role_code
      WHERE upper( user_name ) = @current_user
        AND is_active = 'X'
      INTO @DATA(creator_role).

    IF creator_role <> 'R'.
      RETURN.
    ENDIF.

    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky = key-%tky ) TO failed-salesorder.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Regional managers cannot create sales orders' )
                    ) TO reported-salesorder.
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
        FIELDS ( OverallStatus BranchID ApprovalLevel )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    result = VALUE #( FOR order IN orders
      LET may_approve = COND abap_bool( WHEN order-OverallStatus = 'P'
                                         THEN zcl_its_approval=>can_approve(
                                                iv_user           = current_user
                                                iv_branch_id      = order-BranchID
                                                iv_required_level = CONV i( order-ApprovalLevel ) )
                                         ELSE abap_false )
      IN
      ( %tky = order-%tky

        "--- Completed is the final state: no more edits or deletion (document principle) ---
        %update = COND #( WHEN order-OverallStatus = 'F'
                          THEN if_abap_behv=>fc-o-disabled
                          ELSE if_abap_behv=>fc-o-enabled )

        %delete = COND #( WHEN order-OverallStatus = 'F'
                          THEN if_abap_behv=>fc-o-disabled
                          ELSE if_abap_behv=>fc-o-enabled )

        %action-Submit   = COND #( WHEN order-OverallStatus = 'D'
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )

        %action-Approve  = COND #( WHEN may_approve = abap_true
                                   THEN if_abap_behv=>fc-o-enabled
                                   ELSE if_abap_behv=>fc-o-disabled )

        %action-Reject   = COND #( WHEN may_approve = abap_true
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

  METHOD validateStock.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrderItem
        FIELDS ( ProductID Quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).

      IF item-ProductID IS INITIAL.
        CONTINUE.
      ENDIF.

      "--- หา BranchID ของใบสั่งขายที่เป็นแม่ของ item นี้ ---
      READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrderItem BY \_SalesOrder
          FIELDS ( BranchID )
          WITH VALUE #( ( %tky = item-%tky ) )
        RESULT DATA(headers).

      READ TABLE headers INTO DATA(header) INDEX 1.
      IF sy-subrc <> 0 OR header-BranchID IS INITIAL.
        CONTINUE.
      ENDIF.

      "--- อ่านสต๊อกปัจจุบันของสินค้าที่สาขานี้ ---
      SELECT SINGLE FROM zits_stock
        FIELDS qty_on_hand
        WHERE branch_id  = @header-BranchID
          AND product_id = @item-ProductID
        INTO @DATA(available_stock).

      IF item-Quantity > available_stock.
        APPEND VALUE #( %tky = item-%tky ) TO failed-salesorderitem.
        APPEND VALUE #( %tky              = item-%tky
                        %element-Quantity = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Not enough stock at this branch: only { available_stock } available| )
                      ) TO reported-salesorderitem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD Submit.

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder FIELDS ( OverallStatus TotalAmount )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'D'.
        CONTINUE.
      ENDIF.

      DATA(required_level) = zcl_its_approval=>get_required_level_so( order-TotalAmount ).

      APPEND VALUE #( %tky          = order-%tky
                      ApprovalLevel = required_level
                      OverallStatus = COND #( WHEN required_level = 0 THEN 'C' ELSE 'P' )
                    ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder UPDATE FIELDS ( OverallStatus ApprovalLevel ) WITH updates
      REPORTED DATA(rep).

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).

  ENDMETHOD.


*--------------------------------------------------------------------*
* APPROVE - manager only; Pending -> Confirmed
*--------------------------------------------------------------------*
  METHOD Approve.

    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder FIELDS ( OverallStatus BranchID ApprovalLevel )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.
    GET TIME STAMP FIELD DATA(now).

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'P'.
        CONTINUE.
      ENDIF.

      IF zcl_its_approval=>can_approve(
           iv_user           = current_user
           iv_branch_id      = order-BranchID
           iv_required_level = CONV i( order-ApprovalLevel ) ) = abap_false.

        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = COND #(
                                   WHEN order-ApprovalLevel = 2
                                   THEN 'This order requires regional manager approval'
                                   ELSE 'You may only approve orders for your own branch' ) )
                      ) TO reported-salesorder.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_employee
        FIELDS employee_id
        WHERE upper( user_name ) = @current_user
          AND is_active = 'X'
        INTO @DATA(approver_id).

      APPEND VALUE #( %tky          = order-%tky
                      OverallStatus = 'C'
                      ApprovedBy    = approver_id
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

    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder FIELDS ( OverallStatus BranchID ApprovalLevel )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_salesorder.

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'P'.
        CONTINUE.
      ENDIF.

      IF zcl_its_approval=>can_approve(
           iv_user           = current_user
           iv_branch_id      = order-BranchID
           iv_required_level = CONV i( order-ApprovalLevel ) ) = abap_false.

        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = COND #(
                                   WHEN order-ApprovalLevel = 2
                                   THEN 'This order requires regional manager approval'
                                   ELSE 'You may only approve orders for your own branch' ) )
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

    TYPES: BEGIN OF ty_pending_issue,
             cid        TYPE string,
             so_uuid    TYPE zits_so-so_uuid,
             branch_id  TYPE zits_stock-branch_id,
             product_id TYPE zits_stock-product_id,
             quantity   TYPE zits_soitem-quantity,
           END OF ty_pending_issue.

    TYPES: BEGIN OF ty_cid_line,
             cid TYPE string,
           END OF ty_cid_line.

    TYPES: BEGIN OF ty_order_line,
             so_uuid TYPE zits_so-so_uuid,
           END OF ty_order_line.

    "--- links a journal entry %cid (header or line) back to its order,
    "    so a create failure can be blamed on the right sales order ---
    TYPES: BEGIN OF ty_je_link,
             cid     TYPE string,
             so_uuid TYPE zits_so-so_uuid,
           END OF ty_je_link.

    "--- what the goods sold actually cost us, summed per order ---
    TYPES: BEGIN OF ty_order_cost,
             so_uuid    TYPE zits_so-so_uuid,
             total_cost TYPE zits_so-total_amount,
           END OF ty_order_cost.

    "==== 1) อ่าน header ที่จะ complete (เฉพาะสถานะ Confirmed) ====
    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder
        FIELDS ( OverallStatus SOUUID SONumber CurrencyCode TotalAmount
                 BranchID PaymentMethod SalesDate )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA header_updates TYPE TABLE FOR UPDATE zi_its_salesorder.
    DATA stock_updates  TYPE TABLE FOR UPDATE zi_its_stock.
    DATA ledger_creates TYPE TABLE FOR CREATE zi_its_ledger.
    DATA matdoc_creates TYPE TABLE FOR CREATE zi_its_matdoc.
    DATA pending_issues TYPE STANDARD TABLE OF ty_pending_issue WITH EMPTY KEY.
    DATA failed_cids    TYPE STANDARD TABLE OF ty_cid_line WITH EMPTY KEY.
    DATA failed_orders  TYPE STANDARD TABLE OF ty_order_line WITH EMPTY KEY.
    DATA je_creates     TYPE TABLE FOR CREATE zi_its_je.
    DATA je_items       TYPE TABLE FOR CREATE zi_its_je\_Item.
    DATA je_links       TYPE STANDARD TABLE OF ty_je_link WITH EMPTY KEY.
    DATA order_costs    TYPE STANDARD TABLE OF ty_order_cost WITH EMPTY KEY.
    DATA no_cost_center TYPE STANDARD TABLE OF ty_order_line WITH EMPTY KEY.

    GET TIME STAMP FIELD DATA(now).
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    "--- Every document this action posts is dated when the sale actually
    "    happened, not when the button was pressed. Completing a backdated
    "    order today must not stamp today onto its accounting - the posting
    "    date has to reflect the business event (standard practice, and the
    "    reason the generated 3-month history lands in the right periods).
    "    'today' survives only as the fallback for an order with no date. ---
    DATA posting_date TYPE d.

    "==== 2) เตรียม material document ของทุกรายการก่อน - ยังไม่แตะสต๊อกหรือเปลี่ยนสถานะ ====
    LOOP AT orders INTO DATA(order).

      IF order-OverallStatus <> 'C'.
        CONTINUE.
      ENDIF.

      posting_date = COND #( WHEN order-SalesDate IS NOT INITIAL
                             THEN order-SalesDate ELSE today ).

      READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrder BY \_Item
          FIELDS ( ProductID Quantity Unit CostPrice )
          WITH VALUE #( ( %tky = order-%tky ) )
        RESULT DATA(items).

      "--- what these goods cost us, at the price snapshotted when the
      "    line was entered - this becomes the cost of goods sold ---
      DATA order_cost TYPE zits_so-total_amount.
      CLEAR order_cost.

      "--- ใช้ sy-tabix (ลำดับใน loop) เป็นตัวการันตี %cid ไม่ซ้ำ
      "    (ItemPos ของ item ไม่เคยถูกเซ็ตค่าจริง ยังเป็นค่าว่างเสมอ ถ้าใช้ ItemPos ตอน item
      "    มากกว่า 1 รายการจะได้ %cid ซ้ำกัน แล้ว EML create จะ dump) ---
      LOOP AT items INTO DATA(item).
        IF item-ProductID IS INITIAL.
          CONTINUE.
        ENDIF.

        DATA(item_seq) = sy-tabix.
        DATA(cid) = |MD_{ order-SONumber }_{ item_seq }|.

        APPEND VALUE #( %cid         = cid
                        MovementType = zcl_its_movement=>gc_goods_issue
                        PostingDate  = posting_date
                        BranchID     = order-BranchID
                        ProductID    = item-ProductID
                        Quantity     = item-Quantity * -1   "goods leaving - negative
                        Unit         = item-Unit
                        RefDocType   = 'SO'
                        RefDocNumber = order-SONumber
                        RefDocUUID   = order-SOUUID
                        RefItemPos   = item_seq )
               TO matdoc_creates.

        APPEND VALUE #( cid        = cid
                        so_uuid    = order-SOUUID
                        branch_id  = order-BranchID
                        product_id = item-ProductID
                        quantity   = item-Quantity )
               TO pending_issues.

        order_cost = order_cost + ( item-Quantity * item-CostPrice ).
      ENDLOOP.

      APPEND VALUE #( so_uuid    = order-SOUUID
                      total_cost = order_cost ) TO order_costs.

    ENDLOOP.

    "==== 3) สร้าง material document ก่อน (ไม่ใช้ LOCAL MODE - ข้าม BO) ====
    IF matdoc_creates IS NOT INITIAL.

      MODIFY ENTITIES OF zi_its_matdoc
        ENTITY MaterialDocument
          CREATE FIELDS ( MovementType PostingDate BranchID ProductID Quantity Unit
                          RefDocType RefDocNumber RefDocUUID RefItemPos )
          WITH matdoc_creates
        REPORTED DATA(matdoc_rep)
        FAILED   DATA(matdoc_failed).

      LOOP AT matdoc_failed-materialdocument INTO DATA(mf).
        APPEND VALUE #( cid = mf-%cid ) TO failed_cids.
      ENDLOOP.

      "==== 4) ถ้ารายการไหนของใบไหนสร้าง material document ไม่สำเร็จ ====
      "        ให้ข้ามทั้งใบนั้น - ไม่ตัดสต๊อกและไม่เปลี่ยนสถานะแม้แต่รายการเดียวของใบนั้น
      LOOP AT pending_issues INTO DATA(chk).
        READ TABLE failed_cids WITH KEY cid = chk-cid TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          APPEND VALUE #( so_uuid = chk-so_uuid ) TO failed_orders.
        ENDIF.
      ENDLOOP.
      SORT failed_orders BY so_uuid.
      DELETE ADJACENT DUPLICATES FROM failed_orders COMPARING so_uuid.

    ENDIF.

    "==================================================================
    " JOURNAL ENTRY - the money side of the same business event.
    " Built only for orders that already got their material document,
    " and created BEFORE the stock is touched, so a failure here still
    " stops the whole order (same all-or-nothing unit).
    "
    " Four lines:
    "   cash or bank   D  total amount   the customer paid us
    "   revenue        C  total amount   we earned it
    "   cost of sales  D  total cost     the goods left us
    "   inventory      C  total cost     stock is worth that much less
    "==================================================================
    LOOP AT orders INTO order.

      IF order-OverallStatus <> 'C'.
        CONTINUE.
      ENDIF.

      READ TABLE failed_orders WITH KEY so_uuid = order-SOUUID TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      "--- every posting of a branch is booked against its cost center;
      "    a branch without one is a master data problem, not something
      "    to post around silently ---
      DATA(cost_center) = zcl_its_gl_mapping=>get_cost_center_for_branch( order-BranchID ).
      IF cost_center IS INITIAL.
        APPEND VALUE #( so_uuid = order-SOUUID ) TO failed_orders.
        APPEND VALUE #( so_uuid = order-SOUUID ) TO no_cost_center.
        CONTINUE.
      ENDIF.

      READ TABLE order_costs WITH KEY so_uuid = order-SOUUID INTO DATA(oc).
      DATA(total_cost) = COND zits_so-total_amount( WHEN sy-subrc = 0 THEN oc-total_cost ELSE 0 ).

      DATA(debit_account) = zcl_its_gl_mapping=>get_sales_debit_account( order-PaymentMethod ).
      DATA(je_cid)        = |JE_{ order-SONumber }|.

      posting_date = COND #( WHEN order-SalesDate IS NOT INITIAL
                             THEN order-SalesDate ELSE today ).

      APPEND VALUE #( %cid         = je_cid
                      PostingDate  = posting_date
                      DocType      = 'RV'
                      BranchID     = order-BranchID
                      HeaderText   = |Sale { order-SONumber }|
                      RefDocType   = 'SO'
                      RefDocNumber = order-SONumber
                      RefDocUUID   = order-SOUUID
                      CurrencyCode = order-CurrencyCode ) TO je_creates.

      DATA je_lines LIKE LINE OF je_items.
      CLEAR je_lines.
      je_lines-%cid_ref = je_cid.

      "--- the revenue pair, always posted ---
      APPEND VALUE #( %cid         = |{ je_cid }_1|
                      GLAccount    = debit_account
                      DCIndicator  = 'D'
                      Amount       = order-TotalAmount
                      CurrencyCode = order-CurrencyCode
                      CostCenterID = cost_center
                      LineText     = |Sale { order-SONumber }| ) TO je_lines-%target.

      APPEND VALUE #( %cid         = |{ je_cid }_2|
                      GLAccount    = zcl_its_gl_mapping=>gc_revenue
                      DCIndicator  = 'C'
                      Amount       = order-TotalAmount
                      CurrencyCode = order-CurrencyCode
                      CostCenterID = cost_center
                      LineText     = |Revenue { order-SONumber }| ) TO je_lines-%target.

      APPEND VALUE #( cid = je_cid         so_uuid = order-SOUUID ) TO je_links.
      APPEND VALUE #( cid = |{ je_cid }_1| so_uuid = order-SOUUID ) TO je_links.
      APPEND VALUE #( cid = |{ je_cid }_2| so_uuid = order-SOUUID ) TO je_links.

      "--- the cost pair, only when we actually know what the goods cost.
      "    Orders entered before CostPrice existed carry zero, and a zero
      "    line would be rejected by the Journal Entry line validation and
      "    take the whole sale down with it. Posting the revenue pair alone
      "    still balances; the missing cost shows up as an inflated margin,
      "    which is visible and fixable, unlike a blocked sale. ---
      IF total_cost > 0.

        APPEND VALUE #( %cid         = |{ je_cid }_3|
                        GLAccount    = zcl_its_gl_mapping=>gc_cogs
                        DCIndicator  = 'D'
                        Amount       = total_cost
                        CurrencyCode = order-CurrencyCode
                        CostCenterID = cost_center
                        LineText     = |Cost of goods sold { order-SONumber }| ) TO je_lines-%target.

        APPEND VALUE #( %cid         = |{ je_cid }_4|
                        GLAccount    = zcl_its_gl_mapping=>gc_inventory
                        DCIndicator  = 'C'
                        Amount       = total_cost
                        CurrencyCode = order-CurrencyCode
                        CostCenterID = cost_center
                        LineText     = |Inventory reduction { order-SONumber }| ) TO je_lines-%target.

        APPEND VALUE #( cid = |{ je_cid }_3| so_uuid = order-SOUUID ) TO je_links.
        APPEND VALUE #( cid = |{ je_cid }_4| so_uuid = order-SOUUID ) TO je_links.

      ENDIF.

      APPEND je_lines TO je_items.

    ENDLOOP.

    "--- cross-BO create (no LOCAL MODE). Journal Entry's own
    "    determinations number the lines, compute the totals, assign the
    "    document number and post it - none of that is duplicated here ---
    IF je_creates IS NOT INITIAL.

      MODIFY ENTITIES OF zi_its_je
        ENTITY JournalEntry
          CREATE FIELDS ( PostingDate DocType BranchID HeaderText
                          RefDocType RefDocNumber RefDocUUID CurrencyCode )
            WITH je_creates
          CREATE BY \_Item FIELDS ( GLAccount DCIndicator Amount CurrencyCode
                                    CostCenterID LineText )
            WITH je_items
        REPORTED DATA(je_rep)
        FAILED   DATA(je_failed).

      LOOP AT je_failed-journalentry INTO DATA(jf_hdr).
        READ TABLE je_links WITH KEY cid = jf_hdr-%cid INTO DATA(link_hdr).
        IF sy-subrc = 0.
          APPEND VALUE #( so_uuid = link_hdr-so_uuid ) TO failed_orders.
        ENDIF.
      ENDLOOP.

      LOOP AT je_failed-journalentryitem INTO DATA(jf_item).
        READ TABLE je_links WITH KEY cid = jf_item-%cid INTO DATA(link_item).
        IF sy-subrc = 0.
          APPEND VALUE #( so_uuid = link_item-so_uuid ) TO failed_orders.
        ENDIF.
      ENDLOOP.

      SORT failed_orders BY so_uuid.
      DELETE ADJACENT DUPLICATES FROM failed_orders COMPARING so_uuid.

    ENDIF.

    "==== 5) ตัดสต๊อกเฉพาะรายการของใบที่ไม่ได้อยู่ใน failed_orders ====
    LOOP AT pending_issues INTO DATA(pending).

      READ TABLE failed_orders WITH KEY so_uuid = pending-so_uuid TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_stock
        FIELDS qty_on_hand
        WHERE branch_id  = @pending-branch_id
          AND product_id = @pending-product_id
        INTO @DATA(current_stock).

      APPEND VALUE #( %key-BranchID  = pending-branch_id
                      %key-ProductID = pending-product_id
                      QtyOnHand      = current_stock - pending-quantity )
             TO stock_updates.
    ENDLOOP.

    "==== 6) เตรียม ledger + เปลี่ยนสถานะ เฉพาะใบที่ไม่ได้อยู่ใน failed_orders ====
    "        ใบที่อยู่ใน failed_orders จะรายงาน error กลับไปแทน ให้ผู้ใช้ลองใหม่
    LOOP AT orders INTO order.

      IF order-OverallStatus <> 'C'.
        CONTINUE.
      ENDIF.

      READ TABLE failed_orders WITH KEY so_uuid = order-SOUUID TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.

        READ TABLE no_cost_center WITH KEY so_uuid = order-SOUUID TRANSPORTING NO FIELDS.
        DATA(msg_text) = COND string(
          WHEN sy-subrc = 0
          THEN |No active cost center for branch { order-BranchID } - { order-SONumber } not completed|
          ELSE |Document posting failed for { order-SONumber } - order not completed, please retry| ).

        APPEND VALUE #( %tky = order-%tky ) TO failed-salesorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = msg_text )
                      ) TO reported-salesorder.
        CONTINUE.
      ENDIF.

      posting_date = COND #( WHEN order-SalesDate IS NOT INITIAL
                             THEN order-SalesDate ELSE today ).

      APPEND VALUE #( %cid         = |LED_{ order-SONumber }|
                      PostingDate  = posting_date
                      EntryType    = 'I'
                      Amount       = order-TotalAmount
                      CurrencyCode = order-CurrencyCode
                      RefDocType   = 'SO'
                      RefDocNumber = order-SONumber
                      Description  = |Sale { order-SONumber }| )
             TO ledger_creates.

      APPEND VALUE #( %tky          = order-%tky
                      OverallStatus = 'F' ) TO header_updates.

    ENDLOOP.

    "==== 7) ยิง EML ที่เหลือ ====

    " 7a) ตัดสต๊อกที่ Stock BO (ต่อสาขา)
    IF stock_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_stock
        ENTITY Stock
          UPDATE FIELDS ( QtyOnHand ) WITH stock_updates
        REPORTED DATA(stock_rep)
        FAILED   DATA(stock_failed).
    ENDIF.

    " 7b) สร้าง entry ที่ Ledger BO
    IF ledger_creates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_ledger
        ENTITY Ledger
          CREATE FIELDS ( PostingDate EntryType Amount CurrencyCode
                          RefDocType RefDocNumber Description )
          WITH ledger_creates
        REPORTED DATA(led_rep)
        FAILED   DATA(led_failed).
    ENDIF.

    " 7c) อัปเดตสถานะ header ของตัวเอง (local mode)
    IF header_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_salesorder IN LOCAL MODE
        ENTITY SalesOrder
          UPDATE FIELDS ( OverallStatus ) WITH header_updates
        REPORTED DATA(hdr_rep).
    ENDIF.

    "==== 8) คืนค่า instance ให้ UI ====
    READ ENTITIES OF zi_its_salesorder IN LOCAL MODE
      ENTITY SalesOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).

  ENDMETHOD.

ENDCLASS.
