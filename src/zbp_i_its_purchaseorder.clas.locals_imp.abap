CLASS lhc_PurchaseOrder DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR PurchaseOrder RESULT result.
    METHODS setHeaderDefaults FOR DETERMINE ON MODIFY IMPORTING keys FOR PurchaseOrder~setHeaderDefaults.
    METHODS assignPONumber   FOR DETERMINE ON SAVE   IMPORTING keys FOR PurchaseOrder~assignPONumber.
    METHODS validateItems    FOR VALIDATE ON SAVE    IMPORTING keys FOR PurchaseOrder~validateItems.
    METHODS validateBranch   FOR VALIDATE ON SAVE    IMPORTING keys FOR PurchaseOrder~validateBranch.
    METHODS validateSupplier FOR VALIDATE ON SAVE    IMPORTING keys FOR PurchaseOrder~validateSupplier.
    METHODS validateWarehouseStaff FOR VALIDATE ON SAVE IMPORTING keys FOR PurchaseOrder~validateWarehouseStaff.
    METHODS validateCreatorRole    FOR VALIDATE ON SAVE IMPORTING keys FOR PurchaseOrder~validateCreatorRole.
    METHODS processLine      FOR DETERMINE ON MODIFY IMPORTING keys FOR PurchaseOrderItem~processLine.
    METHODS validateQuantity FOR VALIDATE ON SAVE    IMPORTING keys FOR PurchaseOrderItem~validateQuantity.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurchaseOrder RESULT result.
    METHODS getItemFeatures FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR PurchaseOrderItem RESULT result.
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
      ENTITY PurchaseOrder FIELDS ( OverallStatus BranchID ApprovalLevel ) WITH CORRESPONDING #( keys ) RESULT DATA(orders).

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
        "--- Received is the final state: no more edits or deletion (document principle) ---
        %update = COND #( WHEN order-OverallStatus = 'R' THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
        %delete = COND #( WHEN order-OverallStatus = 'R' THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
        %action-Submit  = COND #( WHEN order-OverallStatus = 'D' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Approve = COND #( WHEN may_approve = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Reject  = COND #( WHEN may_approve = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Cancel  = COND #( WHEN order-OverallStatus = 'D' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-Receive = COND #( WHEN order-OverallStatus = 'A' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      ) ).
  ENDMETHOD.

*--------------------------------------------------------------------*
* GLOBAL AUTHORIZATION - regional managers cannot create purchase
* orders (disables the "Create" button on the list report itself,
* before any draft exists - see also validateCreatorRole, which is
* the same rule enforced again at save time as a safety net)
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
* ITEM FEATURES - items are locked once the parent order is Received
* (same "no edits after the final state" rule as the header)
*--------------------------------------------------------------------*
  METHOD getItemFeatures.

    LOOP AT keys INTO DATA(item_key).

      READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrderItem BY \_PurchaseOrder
          FIELDS ( OverallStatus )
          WITH VALUE #( ( %tky = item_key-%tky ) )
        RESULT DATA(headers).

      READ TABLE headers INTO DATA(header) INDEX 1.

      DATA(is_locked) = COND abap_bool( WHEN sy-subrc = 0 AND header-OverallStatus = 'R'
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

  METHOD Approve.
    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder FIELDS ( OverallStatus BranchID ApprovalLevel ) WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.
    GET TIME STAMP FIELD DATA(now).
    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'P'. CONTINUE. ENDIF.

      IF zcl_its_approval=>can_approve(
           iv_user           = current_user
           iv_branch_id      = order-BranchID
           iv_required_level = CONV i( order-ApprovalLevel ) ) = abap_false.

        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky = order-%tky %msg = new_message_with_text(
          severity = if_abap_behv_message=>severity-error
          text = COND #( WHEN order-ApprovalLevel = 2
                         THEN 'This purchase order requires regional manager approval'
                         ELSE 'You may only approve purchase orders for your own branch' ) )
                      ) TO reported-purchaseorder.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_employee
        FIELDS employee_id
        WHERE upper( user_name ) = @current_user
          AND is_active = 'X'
        INTO @DATA(approver_id).

      APPEND VALUE #( %tky = order-%tky OverallStatus = 'A' ApprovedBy = approver_id ApprovedAt = now ) TO updates.
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

    TYPES: BEGIN OF ty_pending_receipt,
             cid        TYPE string,
             po_uuid    TYPE zits_po-po_uuid,
             branch_id  TYPE zits_stock-branch_id,
             product_id TYPE zits_stock-product_id,
             quantity   TYPE zits_poitem-quantity,
           END OF ty_pending_receipt.

    TYPES: BEGIN OF ty_cid_line,
             cid TYPE string,
           END OF ty_cid_line.

    TYPES: BEGIN OF ty_order_line,
             po_uuid TYPE zits_po-po_uuid,
           END OF ty_order_line.

    "--- links a journal entry %cid (header or line) back to its order,
    "    so a create failure can be blamed on the right purchase order ---
    TYPES: BEGIN OF ty_je_link,
             cid     TYPE string,
             po_uuid TYPE zits_po-po_uuid,
           END OF ty_je_link.

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder FIELDS ( OverallStatus POUUID PONumber CurrencyCode TotalCost BranchID )
      WITH CORRESPONDING #( keys ) RESULT DATA(orders).

    DATA header_updates   TYPE TABLE FOR UPDATE zi_its_purchaseorder.
    DATA stock_updates    TYPE TABLE FOR UPDATE zi_its_stock.
    DATA stock_creates    TYPE TABLE FOR CREATE zi_its_stock.
    DATA ledger_creates   TYPE TABLE FOR CREATE zi_its_ledger.
    DATA matdoc_creates   TYPE TABLE FOR CREATE zi_its_matdoc.
    DATA pending_receipts TYPE STANDARD TABLE OF ty_pending_receipt WITH EMPTY KEY.
    DATA failed_cids      TYPE STANDARD TABLE OF ty_cid_line WITH EMPTY KEY.
    DATA failed_orders    TYPE STANDARD TABLE OF ty_order_line WITH EMPTY KEY.
    DATA je_creates       TYPE TABLE FOR CREATE zi_its_je.
    DATA je_items         TYPE TABLE FOR CREATE zi_its_je\_Item.
    DATA je_links         TYPE STANDARD TABLE OF ty_je_link WITH EMPTY KEY.
    DATA no_cost_center   TYPE STANDARD TABLE OF ty_order_line WITH EMPTY KEY.

    GET TIME STAMP FIELD DATA(now).
    DATA(today) = cl_abap_context_info=>get_system_date( ).

    "--- เตรียม material document (goods receipt) ของทุกรายการก่อน - ยังไม่แตะสต๊อกหรือเปลี่ยนสถานะ ---
    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'A'. CONTINUE. ENDIF.

      READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder BY \_Item FIELDS ( ProductID Quantity Unit )
        WITH VALUE #( ( %tky = order-%tky ) ) RESULT DATA(items).

      "--- ใช้ sy-tabix (ลำดับใน loop) เป็นตัวการันตี %cid ไม่ซ้ำ
      "    (ItemPos ของ item ไม่เคยถูกเซ็ตค่าจริง ยังเป็นค่าว่างเสมอ ถ้าใช้ ItemPos ตอน item
      "    มากกว่า 1 รายการจะได้ %cid ซ้ำกัน แล้ว EML create จะ dump) ---
      LOOP AT items INTO DATA(item).
        IF item-ProductID IS INITIAL. CONTINUE. ENDIF.

        DATA(item_seq) = sy-tabix.
        DATA(cid) = |MD_{ order-PONumber }_{ item_seq }|.

        APPEND VALUE #( %cid         = cid
                        MovementType = zcl_its_movement=>gc_goods_receipt
                        PostingDate  = today
                        BranchID     = order-BranchID
                        ProductID    = item-ProductID
                        Quantity     = item-Quantity   "goods arriving - positive
                        Unit         = item-Unit
                        RefDocType   = 'PO'
                        RefDocNumber = order-PONumber
                        RefDocUUID   = order-POUUID
                        RefItemPos   = item_seq ) TO matdoc_creates.

        APPEND VALUE #( cid        = cid
                        po_uuid    = order-POUUID
                        branch_id  = order-BranchID
                        product_id = item-ProductID
                        quantity   = item-Quantity ) TO pending_receipts.
      ENDLOOP.
    ENDLOOP.

    "--- สร้าง material document ก่อน (ไม่ใช้ LOCAL MODE - ข้าม BO) ---
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

      "--- ถ้ารายการไหนของใบไหนสร้าง material document ไม่สำเร็จ ---
      "    ให้ข้ามทั้งใบนั้น - ไม่ตัดสต๊อกและไม่เปลี่ยนสถานะแม้แต่รายการเดียวของใบนั้น
      LOOP AT pending_receipts INTO DATA(chk).
        READ TABLE failed_cids WITH KEY cid = chk-cid TRANSPORTING NO FIELDS.
        IF sy-subrc = 0.
          APPEND VALUE #( po_uuid = chk-po_uuid ) TO failed_orders.
        ENDIF.
      ENDLOOP.
      SORT failed_orders BY po_uuid.
      DELETE ADJACENT DUPLICATES FROM failed_orders COMPARING po_uuid.

    ENDIF.

    "==================================================================
    " JOURNAL ENTRY - money side of the same business event.
    " Built only for orders that already got their material document,
    " and created BEFORE the stock is touched, so that a failure here
    " still stops the whole order (same all-or-nothing unit).
    "==================================================================
    LOOP AT orders INTO order.
      IF order-OverallStatus <> 'A'. CONTINUE. ENDIF.

      READ TABLE failed_orders WITH KEY po_uuid = order-POUUID TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      "--- every posting of a branch is booked against its cost center;
      "    a branch without one is a master data problem, not something
      "    to post around silently ---
      DATA(cost_center) = zcl_its_gl_mapping=>get_cost_center_for_branch( order-BranchID ).
      IF cost_center IS INITIAL.
        APPEND VALUE #( po_uuid = order-POUUID ) TO failed_orders.
        APPEND VALUE #( po_uuid = order-POUUID ) TO no_cost_center.
        CONTINUE.
      ENDIF.

      DATA(je_cid) = |JE_{ order-PONumber }|.

      "--- header ---
      APPEND VALUE #( %cid         = je_cid
                      PostingDate  = today
                      DocType      = 'RE'
                      BranchID     = order-BranchID
                      HeaderText   = |Purchase { order-PONumber }|
                      RefDocType   = 'PO'
                      RefDocNumber = order-PONumber
                      RefDocUUID   = order-POUUID
                      CurrencyCode = order-CurrencyCode ) TO je_creates.

      "--- two lines: inventory goes up, the supplier is owed the money ---
      APPEND VALUE #( %cid_ref = je_cid
                      %target  = VALUE #(
                        ( %cid         = |{ je_cid }_1|
                          GLAccount    = zcl_its_gl_mapping=>gc_inventory
                          DCIndicator  = 'D'
                          Amount       = order-TotalCost
                          CurrencyCode = order-CurrencyCode
                          CostCenterID = cost_center
                          LineText     = |Goods receipt { order-PONumber }| )
                        ( %cid         = |{ je_cid }_2|
                          GLAccount    = zcl_its_gl_mapping=>gc_payables
                          DCIndicator  = 'C'
                          Amount       = order-TotalCost
                          CurrencyCode = order-CurrencyCode
                          CostCenterID = cost_center
                          LineText     = |Supplier liability { order-PONumber }| ) ) ) TO je_items.

      "--- header and both line cids point back at this order ---
      APPEND VALUE #( cid = je_cid            po_uuid = order-POUUID ) TO je_links.
      APPEND VALUE #( cid = |{ je_cid }_1|    po_uuid = order-POUUID ) TO je_links.
      APPEND VALUE #( cid = |{ je_cid }_2|    po_uuid = order-POUUID ) TO je_links.
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
          APPEND VALUE #( po_uuid = link_hdr-po_uuid ) TO failed_orders.
        ENDIF.
      ENDLOOP.

      LOOP AT je_failed-journalentryitem INTO DATA(jf_item).
        READ TABLE je_links WITH KEY cid = jf_item-%cid INTO DATA(link_item).
        IF sy-subrc = 0.
          APPEND VALUE #( po_uuid = link_item-po_uuid ) TO failed_orders.
        ENDIF.
      ENDLOOP.

      SORT failed_orders BY po_uuid.
      DELETE ADJACENT DUPLICATES FROM failed_orders COMPARING po_uuid.

    ENDIF.

    "--- ตัดสต๊อกเฉพาะรายการของใบที่ไม่ได้อยู่ใน failed_orders ---
    "    goods receipt: update stock if a row exists for this branch+product, else create it
    LOOP AT pending_receipts INTO DATA(pending).

      READ TABLE failed_orders WITH KEY po_uuid = pending-po_uuid TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_stock FIELDS qty_on_hand
        WHERE branch_id  = @pending-branch_id
          AND product_id = @pending-product_id
        INTO @DATA(current_stock).

      IF sy-subrc = 0.
        APPEND VALUE #( %key-BranchID  = pending-branch_id
                        %key-ProductID = pending-product_id
                        QtyOnHand      = current_stock + pending-quantity ) TO stock_updates.
      ELSE.
        APPEND VALUE #( %cid      = |STK_{ pending-cid }|
                        BranchID  = pending-branch_id
                        ProductID = pending-product_id
                        QtyOnHand = pending-quantity ) TO stock_creates.
      ENDIF.
    ENDLOOP.

    "--- เตรียม ledger + เปลี่ยนสถานะ เฉพาะใบที่ไม่ได้อยู่ใน failed_orders ---
    "    ใบที่อยู่ใน failed_orders จะรายงาน error กลับไปแทน ให้ผู้ใช้ลองใหม่
    LOOP AT orders INTO order.
      IF order-OverallStatus <> 'A'. CONTINUE. ENDIF.

      READ TABLE failed_orders WITH KEY po_uuid = order-POUUID TRANSPORTING NO FIELDS.
      IF sy-subrc = 0.

        READ TABLE no_cost_center WITH KEY po_uuid = order-POUUID TRANSPORTING NO FIELDS.
        DATA(msg_text) = COND string(
          WHEN sy-subrc = 0
          THEN |No active cost center for branch { order-BranchID } - { order-PONumber } not received|
          ELSE |Document posting failed for { order-PONumber } - order not received, please retry| ).

        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = msg_text )
                      ) TO reported-purchaseorder.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %cid = |LED_{ order-PONumber }|
                      PostingDate = today  EntryType = 'E'  "Expense!
                      Amount = order-TotalCost  CurrencyCode = order-CurrencyCode
                      RefDocType = 'PO'  RefDocNumber = order-PONumber
                      Description = |Restock { order-PONumber }| ) TO ledger_creates.
      APPEND VALUE #( %tky = order-%tky OverallStatus = 'R' ReceivedDate = today ) TO header_updates.
    ENDLOOP.

    IF stock_updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_stock ENTITY Stock
        UPDATE FIELDS ( QtyOnHand ) WITH stock_updates REPORTED DATA(stock_upd_rep) FAILED DATA(stock_upd_failed).
    ENDIF.
    IF stock_creates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_stock ENTITY Stock
        CREATE FIELDS ( BranchID ProductID QtyOnHand ) WITH stock_creates REPORTED DATA(stock_crt_rep) FAILED DATA(stock_crt_failed).
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
      ENTITY PurchaseOrder FIELDS ( OverallStatus TotalCost )
      WITH CORRESPONDING #( keys ) RESULT DATA(orders).
    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.
    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'D'. CONTINUE. ENDIF.
      "--- purchase orders always need approval - no level 0 ---
      DATA(required_level) = zcl_its_approval=>get_required_level_po( order-TotalCost ).
      APPEND VALUE #( %tky = order-%tky OverallStatus = 'P' ApprovalLevel = required_level ) TO updates.
    ENDLOOP.
    MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder UPDATE FIELDS ( OverallStatus ApprovalLevel ) WITH updates REPORTED DATA(rep).
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(final).
    result = VALUE #( FOR o IN final ( %tky = o-%tky %param = o ) ).
  ENDMETHOD.

  METHOD setHeaderDefaults.
    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder FIELDS ( OverallStatus OrderDate CurrencyCode BranchID WarehouseStaffID )
      WITH CORRESPONDING #( keys ) RESULT DATA(orders).

    "--- employee record of the current user, if any, for the auto-fill below ---
    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).
    SELECT SINGLE FROM zits_employee
      FIELDS employee_id, branch_id
      WHERE upper( user_name ) = @current_user AND is_active = 'X'
      INTO @DATA(current_employee).

    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.
    LOOP AT orders INTO DATA(order).
      DATA(changed) = abap_false.
      IF order-OverallStatus IS INITIAL. order-OverallStatus = 'D'. changed = abap_true. ENDIF.
      IF order-OrderDate IS INITIAL. order-OrderDate = cl_abap_context_info=>get_system_date( ). changed = abap_true. ENDIF.
      IF order-CurrencyCode IS INITIAL. order-CurrencyCode = 'THB'. changed = abap_true. ENDIF.
      IF order-BranchID IS INITIAL AND current_employee-branch_id IS NOT INITIAL.
        order-BranchID = current_employee-branch_id. changed = abap_true.
      ENDIF.
      IF order-WarehouseStaffID IS INITIAL AND current_employee-employee_id IS NOT INITIAL.
        order-WarehouseStaffID = current_employee-employee_id. changed = abap_true.
      ENDIF.
      IF changed = abap_true.
        APPEND VALUE #( %tky = order-%tky OverallStatus = order-OverallStatus
                        OrderDate = order-OrderDate CurrencyCode = order-CurrencyCode
                        BranchID = order-BranchID WarehouseStaffID = order-WarehouseStaffID ) TO updates.
      ENDIF.
    ENDLOOP.
    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
        ENTITY PurchaseOrder UPDATE FIELDS ( OverallStatus OrderDate CurrencyCode BranchID WarehouseStaffID ) WITH updates
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


*--------------------------------------------------------------------*
* VALIDATION - Warehouse staff is derived from the current user; if
* it's still blank, the current user has no active Employee record
*--------------------------------------------------------------------*
  METHOD validateWarehouseStaff.

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( WarehouseStaffID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order).

      IF order-WarehouseStaffID IS INITIAL.
        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Your user is not linked to an active employee record' )
                      ) TO reported-purchaseorder.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - regional managers cannot create purchase orders
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
      APPEND VALUE #( %tky = key-%tky ) TO failed-purchaseorder.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Regional managers cannot create purchase orders' )
                    ) TO reported-purchaseorder.
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

    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    READ ENTITIES OF zi_its_purchaseorder IN LOCAL MODE
      ENTITY purchaseOrder FIELDS ( OverallStatus BranchID ApprovalLevel )
      WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DATA updates TYPE TABLE FOR UPDATE zi_its_purchaseorder.

    LOOP AT orders INTO DATA(order).
      IF order-OverallStatus <> 'P'.
        CONTINUE.
      ENDIF.

      IF zcl_its_approval=>can_approve(
           iv_user           = current_user
           iv_branch_id      = order-BranchID
           iv_required_level = CONV i( order-ApprovalLevel ) ) = abap_false.

        APPEND VALUE #( %tky = order-%tky ) TO failed-purchaseorder.
        APPEND VALUE #( %tky = order-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = COND #(
                                   WHEN order-ApprovalLevel = 2
                                   THEN 'This purchase order requires regional manager approval'
                                   ELSE 'You may only approve purchase orders for your own branch' ) )
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


