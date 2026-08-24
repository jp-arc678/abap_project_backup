CLASS lhc_Stock DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Stock RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Stock~setDefaults.

    METHODS setMovementDate FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Stock~setMovementDate.

    METHODS validateBranch FOR VALIDATE ON SAVE
      IMPORTING keys FOR Stock~validateBranch.

    METHODS validateProduct FOR VALIDATE ON SAVE
      IMPORTING keys FOR Stock~validateProduct.

    METHODS validateQty FOR VALIDATE ON SAVE
      IMPORTING keys FOR Stock~validateQty.

ENDCLASS.


CLASS lhc_Stock IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - default values on create: zero quantities, and
* Unit copied from the Product master if left blank
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_stock IN LOCAL MODE
      ENTITY Stock
        FIELDS ( ProductID QtyOnHand QtyReserved ReorderLevel Unit )
        WITH CORRESPONDING #( keys )
      RESULT DATA(stocks).

    DATA updates TYPE TABLE FOR UPDATE zi_its_stock.

    LOOP AT stocks INTO DATA(stock).

      DATA(needs_update) = abap_false.

      IF stock-QtyOnHand IS INITIAL.
        stock-QtyOnHand = 0.
        needs_update = abap_true.
      ENDIF.

      IF stock-QtyReserved IS INITIAL.
        stock-QtyReserved = 0.
        needs_update = abap_true.
      ENDIF.

      IF stock-ReorderLevel IS INITIAL.
        stock-ReorderLevel = 0.
        needs_update = abap_true.
      ENDIF.

      IF stock-Unit IS INITIAL.
        SELECT SINGLE FROM zits_product
          FIELDS unit
          WHERE product_id = @stock-ProductID
          INTO @DATA(product_unit).

        IF product_unit IS NOT INITIAL.
          stock-Unit = product_unit.
          needs_update = abap_true.
        ENDIF.
      ENDIF.

      IF needs_update = abap_true.
        APPEND VALUE #( %tky         = stock-%tky
                        QtyOnHand    = stock-QtyOnHand
                        QtyReserved  = stock-QtyReserved
                        ReorderLevel = stock-ReorderLevel
                        Unit         = stock-Unit ) TO updates.
      ENDIF.

    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_stock IN LOCAL MODE
        ENTITY Stock
          UPDATE FIELDS ( QtyOnHand QtyReserved ReorderLevel Unit )
          WITH updates
        REPORTED DATA(modify_reported).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - stamp Last Movement Date whenever a stock record
* is created or changed (e.g. by SalesOrder/PurchaseOrder via EML)
*--------------------------------------------------------------------*
  METHOD setMovementDate.

    DATA updates TYPE TABLE FOR UPDATE zi_its_stock.

    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky             = key-%tky
                      LastMovementDate = cl_abap_context_info=>get_system_date( ) ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zi_its_stock IN LOCAL MODE
      ENTITY Stock
        UPDATE FIELDS ( LastMovementDate )
        WITH updates
      REPORTED DATA(modify_reported).

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Branch must exist
*--------------------------------------------------------------------*
  METHOD validateBranch.

    READ ENTITIES OF zi_its_stock IN LOCAL MODE
      ENTITY Stock
        FIELDS ( BranchID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(stocks).

    LOOP AT stocks INTO DATA(stock).

      IF stock-BranchID IS INITIAL.
        APPEND VALUE #( %tky = stock-%tky ) TO failed-stock.
        APPEND VALUE #( %tky              = stock-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch must be entered' )
                      ) TO reported-stock.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_branch
        FIELDS branch_id
        WHERE branch_id = @stock-BranchID
        INTO @DATA(existing_branch).

      IF existing_branch IS INITIAL.
        APPEND VALUE #( %tky = stock-%tky ) TO failed-stock.
        APPEND VALUE #( %tky              = stock-%tky
                        %element-BranchID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Branch does not exist' )
                      ) TO reported-stock.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Product must exist
*--------------------------------------------------------------------*
  METHOD validateProduct.

    READ ENTITIES OF zi_its_stock IN LOCAL MODE
      ENTITY Stock
        FIELDS ( ProductID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(stocks).

    LOOP AT stocks INTO DATA(stock).

      IF stock-ProductID IS INITIAL.
        APPEND VALUE #( %tky = stock-%tky ) TO failed-stock.
        APPEND VALUE #( %tky               = stock-%tky
                        %element-ProductID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Product must be entered' )
                      ) TO reported-stock.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_product
        FIELDS product_id
        WHERE product_id = @stock-ProductID
        INTO @DATA(existing_product).

      IF existing_product IS INITIAL.
        APPEND VALUE #( %tky = stock-%tky ) TO failed-stock.
        APPEND VALUE #( %tky               = stock-%tky
                        %element-ProductID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Product does not exist' )
                      ) TO reported-stock.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - quantities must not be negative, reserved cannot
* exceed on-hand
*--------------------------------------------------------------------*
  METHOD validateQty.

    READ ENTITIES OF zi_its_stock IN LOCAL MODE
      ENTITY Stock
        FIELDS ( QtyOnHand QtyReserved )
        WITH CORRESPONDING #( keys )
      RESULT DATA(stocks).

    LOOP AT stocks INTO DATA(stock).

      IF stock-QtyOnHand < 0.
        APPEND VALUE #( %tky = stock-%tky ) TO failed-stock.
        APPEND VALUE #( %tky               = stock-%tky
                        %element-QtyOnHand = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Quantity on hand must not be negative' )
                      ) TO reported-stock.
      ENDIF.

      IF stock-QtyReserved < 0.
        APPEND VALUE #( %tky = stock-%tky ) TO failed-stock.
        APPEND VALUE #( %tky                 = stock-%tky
                        %element-QtyReserved = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Quantity reserved must not be negative' )
                      ) TO reported-stock.

      ELSEIF stock-QtyReserved > stock-QtyOnHand.
        APPEND VALUE #( %tky = stock-%tky ) TO failed-stock.
        APPEND VALUE #( %tky                 = stock-%tky
                        %element-QtyReserved = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Quantity reserved must not exceed quantity on hand' )
                      ) TO reported-stock.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
