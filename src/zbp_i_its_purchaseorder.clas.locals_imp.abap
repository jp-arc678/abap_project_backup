CLASS lhc_PurchaseOrder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR PurchaseOrder RESULT result.
    METHODS setHeaderDefaults FOR DETERMINE ON MODIFY IMPORTING keys FOR PurchaseOrder~setHeaderDefaults.
    METHODS assignPONumber   FOR DETERMINE ON SAVE   IMPORTING keys FOR PurchaseOrder~assignPONumber.
    METHODS validateItems    FOR VALIDATE ON SAVE    IMPORTING keys FOR PurchaseOrder~validateItems.
    METHODS validateBranch   FOR VALIDATE ON SAVE    IMPORTING keys FOR PurchaseOrder~validateBranch.
    METHODS validateSupplier FOR VALIDATE ON SAVE    IMPORTING keys FOR PurchaseOrder~validateSupplier.
    METHODS processLine      FOR DETERMINE ON MODIFY IMPORTING keys FOR PurchaseOrderItem~processLine.
    METHODS validateQuantity FOR VALIDATE ON SAVE    IMPORTING keys FOR PurchaseOrderItem~validateQuantity.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurchaseOrder RESULT result.
    METHODS Submit  FOR MODIFY IMPORTING keys FOR ACTION PurchaseOrder~Submit  RESULT result.
    METHODS Approve FOR MODIFY IMPORTING keys FOR ACTION PurchaseOrder~Approve RESULT result.
    METHODS Reject  FOR MODIFY IMPORTING keys FOR ACTION PurchaseOrder~Reject  RESULT result.
    METHODS Cancel  FOR MODIFY IMPORTING keys FOR ACTION PurchaseOrder~Cancel  RESULT result.
    METHODS Receive FOR MODIFY IMPORTING keys FOR ACTION PurchaseOrder~Receive RESULT result.

ENDCLASS.

CLASS lhc_PurchaseOrder IMPLEMENTATION.

  METHOD processLine.
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrderItem FIELDS ( ProductID Quantity CostPrice Unit )
      WITH CORRESPONDING #( keys ) RESULT DATA(items).
    DATA item_updates TYPE TABLE FOR UPDATE zi_its_purchaseorderitem.
    LOOP AT items INTO DATA(item).
      IF item-ProductID IS INITIAL. CONTINUE. ENDIF.
      SELECT SINGLE FROM zits_product FIELDS unit, cost_price, currency_code
        WHERE product_id = @item-ProductID INTO @DATA(product).
      IF sy-subrc <> 0. CONTINUE. ENDIF.
      IF item-Unit IS INITIAL. item-Unit = product-unit. ENDIF.
      IF item-CostPrice IS INITIAL. item-CostPrice = product-cost_price. ENDIF.
      APPEND VALUE #( %tky = item-%tky Unit = item-Unit CostPrice = item-CostPrice
                      Amount = item-Quantity * item-CostPrice
                      CurrencyCode = product-currency_code ) TO item_updates.
    ENDLOOP.
    IF item_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrderItem UPDATE FIELDS ( Unit CostPrice Amount CurrencyCode )
        WITH item_updates REPORTED DATA(rep1).
    ENDIF.
    " รวม TotalCost ที่ header

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
     ENTITY PurchaseOrderItem BY \_PurchaseOrder FIELDS ( CurrencyCode )
      WITH CORRESPONDING #( keys ) RESULT DATA(orders).
   SORT orders BY %tky. DELETE ADJACENT DUPLICATES FROM orders COMPARING %tky.
   DATA header_updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.
    LOOP AT orders INTO DATA(order).
      READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder BY \_Item FIELDS ( Amount )
        WITH VALUE #( ( %tky = order-%tky ) ) RESULT DATA(all_items).
      DATA sum_cost TYPE zits_po-total_cost. CLEAR sum_cost.
      LOOP AT all_items INTO DATA(li). sum_cost = sum_cost + li-Amount. ENDLOOP.
      APPEND VALUE #( %tky = order-%tky TotalCost = sum_cost ) TO header_updates.
    ENDLOOP.
    IF header_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder UPDATE FIELDS ( TotalCost ) WITH header_updates REPORTED DATA(rep2).
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder FIELDS ( OverallStatus ) WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    result = VALUE #( FOR order IN orders
      ( %tky = order-%tky
        %action-Submit  = COND #( WHEN order-OverallStatus = 'D' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Approve = COND #( WHEN order-OverallStatus = 'P' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Reject  = COND #( WHEN order-OverallStatus = 'P' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Cancel  = COND #( WHEN order-OverallStatus = 'D' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Receive = COND #( WHEN order-OverallStatus = 'A' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      ) ).
  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

  METHOD Approve.
    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).
    SELECT SINGLE FROM zits_employee FIELDS employee_id
      WHERE user_name = @current_user AND role_code = 'M' AND is_active = 'X'
      INTO @DATA(manager_id).
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder FIELDS ( OverallStatus ) WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.
    GET TIME STAMP FIELD DATA(now).
    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'P'. CONTINUE. ENDIF.
      IF manager_id IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky = order-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = 'Only the manager can approve purchase orders' ) ) TO reported-purchaseorder.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky = order-%tky OverallStatus = 'A' ApprovedBy = manager_id ApprovedAt = now ) TO updates.
    ENDLOOP.
    MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder UPDATE FIELDS ( OverallStatus ApprovedBy ApprovedAt ) WITH updates REPORTED DATA(rep).
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).
  ENDMETHOD.

  METHOD Cancel.

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrder FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'D'.
        CONTINUE.
      ENDIF.
      APPEND VALUE #( %tky            = order-%tky
                      OverallStatus   = 'X'
                      RejectionReason = 'Cancelled by warehouse staff' ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrder UPDATE FIELDS ( OverallStatus RejectionReason ) WITH updates
      REPORTED DATA(rep).

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).

  ENDMETHOD.


  METHOD Receive.
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder FIELDS ( OverallStatus PONumber CurrencyCode TotalCost )
      WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    DATA header_updates  TYPE TABLE FOR UPDATE zi_its_purchaseorder.
    DATA product_updates TYPE TABLE FOR UPDATE zi_its_product.
    DATA ledger_creates  TYPE TABLE FOR CREATE zi_its_ledger.
    GET TIME STAMP FIELD DATA(now).
    DATA(today) = cl_abap_context_info=>get_system_date( ).
    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'A'. CONTINUE. ENDIF.
      READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder BY \_Item FIELDS ( ProductID Quantity )
        WITH VALUE #( ( %tky = order-%tky ) ) RESULT DATA(items).
      LOOP AT items INTO DATA(item).
        IF item-ProductID IS INITIAL. CONTINUE. ENDIF.
        SELECT SINGLE FROM zits_product FIELDS stock_qty
          WHERE product_id = @item-ProductID INTO @DATA(current_stock).
        APPEND VALUE #( %key-ProductID = item-ProductID
                        StockQty = current_stock + item-Quantity ) TO product_updates.  "เพิ่ม!
      ENDLOOP.
      APPEND VALUE #( %cid = |LED_{ order-PONumber }|
                      PostingDate = today  EntryType = 'E'  "Expense!
                      Amount = order-TotalCost  CurrencyCode = order-CurrencyCode
                      RefDocType = 'PO'  RefDocNumber = order-PONumber
                      Description = |Restock { order-PONumber }| ) TO ledger_creates.
      APPEND VALUE #( %tky = order-%tky OverallStatus = 'R' ReceivedDate = today ) TO header_updates.
    ENDLOOP.
    IF product_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_product ENTITY Product
        UPDATE FIELDS ( StockQty ) WITH product_updates REPORTED DATA(pr) FAILED DATA(pf).
    ENDIF.
    IF ledger_creates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_ledger ENTITY Ledger
        CREATE FIELDS ( PostingDate EntryType Amount CurrencyCode RefDocType RefDocNumber Description )
        WITH ledger_creates REPORTED DATA(lr) FAILED DATA(lf).
    ENDIF.
    IF header_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder UPDATE FIELDS ( OverallStatus ReceivedDate ) WITH header_updates REPORTED DATA(hr).
    ENDIF.
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).
  ENDMETHOD.

  METHOD Submit.
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.
    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'D'. CONTINUE. ENDIF.
      APPEND VALUE #( %tky = order-%tky OverallStatus = 'P' ) TO updates.
    ENDLOOP.
    MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder UPDATE FIELDS ( OverallStatus ) WITH updates REPORTED DATA(rep).
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).
  ENDMETHOD.

  METHOD setHeaderDefaults.
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder FIELDS ( OverallStatus OrderDate CurrencyCode BranchID )
      WITH CORRESPONDING #( keys ) RESULT DATA(orders).

    "--- home branch of the current user, if any, for the auto-fill below ---
    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).
    SELECT SINGLE FROM zits_employee
      FIELDS branch_id
      WHERE upper( user_name ) = @current_user AND is_active = 'X'
      INTO @DATA(user_branch_id).

    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.
    LOOP AT orders INTO DATA(order).
      DATA(changed) = abap_false.
      IF order-OverallStatus IS INITIAL. order-OverallStatus = 'D'. changed = abap_true. ENDIF.
      IF order-OrderDate IS INITIAL. order-OrderDate = cl_abap_context_info=>get_system_date( ). changed = abap_true. ENDIF.
      IF order-CurrencyCode IS INITIAL. order-CurrencyCode = 'THB'. changed = abap_true. ENDIF.
      IF order-BranchID IS INITIAL AND user_branch_id IS NOT INITIAL.
        order-BranchID = user_branch_id. changed = abap_true.
      ENDIF.
      IF changed = abap_true.
        APPEND VALUE #( %tky = order-%tky OverallStatus = order-OverallStatus
                        OrderDate = order-OrderDate CurrencyCode = order-CurrencyCode
                        BranchID = order-BranchID ) TO updates.
      ENDIF.
    ENDLOOP.
    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder UPDATE FIELDS ( OverallStatus OrderDate CurrencyCode BranchID ) WITH updates
        REPORTED DATA(rep).
    ENDIF.
  ENDMETHOD.

   METHOD validateItems.

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrder
        FIELDS ( PONumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).

      READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY purchaseOrder BY \_Item
          FIELDS ( POItemUUID )
          WITH VALUE #( ( %tky = order-%tky ) )
        RESULT DATA(items).

      IF items IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'purchaseorder must have at least one item' )
                      ) TO reported-purchaseorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Branch must be entered and must exist
*--------------------------------------------------------------------*
  METHOD validateBranch.

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( BranchID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).

      IF order-BranchID IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky              = order-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch must be entered' )
                      ) TO reported-purchaseorder.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_branch
        FIELDS branch_id
        WHERE branch_id = @order-BranchID
        INTO @DATA(existing_branch).

      IF existing_branch IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky              = order-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch does not exist' )
                      ) TO reported-purchaseorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Supplier must be entered and must exist
*--------------------------------------------------------------------*
  METHOD validateSupplier.

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( SupplierID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).

      IF order-SupplierID IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky                = order-%tky
                        %element-SupplierID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Supplier must be entered' )
                      ) TO reported-purchaseorder.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_partner
        FIELDS partner_id
        WHERE partner_id = @order-SupplierID
          AND ( partner_role = 'S' OR partner_role = 'B' )
        INTO @DATA(existing_supplier).

      IF existing_supplier IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky                = order-%tky
                        %element-SupplierID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Supplier does not exist or is not a supplier partner' )
                      ) TO reported-purchaseorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD validateQuantity.

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrderItem
        FIELDS ( Quantity )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).

      IF item-Quantity <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-purchaseorderitem.
        APPEND VALUE #( %tky              = item-%tky
                        %element-Quantity = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Quantity must be greater than zero' )
                      ) TO reported-purchaseorderitem.

      ELSEIF frac( item-Quantity ) <> 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-purchaseorderitem.
        APPEND VALUE #( %tky              = item-%tky
                        %element-Quantity = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Quantity must be a whole number' )
                      ) TO reported-purchaseorderitem.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

  METHOD Reject.

    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).
    SELECT SINGLE FROM zits_employee FIELDS employee_id
      WHERE user_name = @current_user AND role_code = 'M' AND is_active = 'X'
      INTO @DATA(manager_id).

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrder FIELDS ( OverallStatus )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'P'.
        CONTINUE.
      ENDIF.

      IF manager_id IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Only the manager can reject orders' )
                      ) TO reported-purchaseorder.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky            = order-%tky
                      OverallStatus   = 'X'
                      RejectionReason = 'Rejected by manager' ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrder UPDATE FIELDS ( OverallStatus RejectionReason ) WITH updates
      REPORTED DATA(rep).

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).

  ENDMETHOD.

  METHOD assignPONumber.
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrder
        FIELDS ( PONumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).


    SELECT SINGLE FROM zits_po
      FIELDS MAX( po_number )
      INTO @DATA(max_number).

    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.

    LOOP AT orders INTO DATA(order).


      IF order-PONumber IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      max_number += 1.

      APPEND VALUE #( %tky     = order-%tky
                      PONumber = max_number ) TO updates.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY purchaseOrder
          UPDATE FIELDS ( PONumber )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


ENDCLASS.


