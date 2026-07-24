CLASS lhc_Product DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Product RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Product~setDefaults.

    METHODS validateProductID FOR VALIDATE ON SAVE
      IMPORTING keys FOR Product~validateProductID.

    METHODS validateCategory FOR VALIDATE ON SAVE
      IMPORTING keys FOR Product~validateCategory.

    METHODS validatePrices FOR VALIDATE ON SAVE
      IMPORTING keys FOR Product~validatePrices.

ENDCLASS.


CLASS lhc_Product IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - set default values on create
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_product IN LOCAL MODE
      ENTITY Product
        FIELDS ( CurrencyCode Unit IsActive StockQty ReorderLevel )
        WITH CORRESPONDING #( keys )
      RESULT DATA(products).

    DATA updates TYPE TABLE FOR UPDATE zi_its_product.

    LOOP AT products INTO DATA(product).

      DATA(needs_update) = abap_false.

      IF product-CurrencyCode IS INITIAL.
        product-CurrencyCode = 'THB'.
        needs_update = abap_true.
      ENDIF.

      IF product-Unit IS INITIAL.
        product-Unit = 'EA'.
        needs_update = abap_true.
      ENDIF.

      IF product-IsActive IS INITIAL.
        product-IsActive = 'X'.
        needs_update = abap_true.
      ENDIF.

      IF product-StockQty IS INITIAL.
        product-StockQty = 0.
        needs_update = abap_true.
      ENDIF.

      IF product-ReorderLevel IS INITIAL.
        product-ReorderLevel = 0.
        needs_update = abap_true.
      ENDIF.

      IF needs_update = abap_true.
        APPEND VALUE #( %tky         = product-%tky
                        CurrencyCode = product-CurrencyCode
                        Unit         = product-Unit
                        IsActive     = product-IsActive
                        StockQty     = product-StockQty
                        ReorderLevel = product-ReorderLevel ) TO updates.
      ENDIF.

    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_product IN LOCAL MODE
        ENTITY Product
          UPDATE FIELDS ( CurrencyCode Unit IsActive StockQty ReorderLevel )
          WITH updates
        REPORTED DATA(modify_reported).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Product ID must exist and be unique
*--------------------------------------------------------------------*
  METHOD validateProductID.

    READ ENTITIES OF zi_its_product IN LOCAL MODE
      ENTITY Product
        FIELDS ( ProductID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(products).

    LOOP AT products INTO DATA(product).

      IF product-ProductID IS INITIAL.
        APPEND VALUE #( %tky = product-%tky ) TO failed-product.
        APPEND VALUE #( %tky               = product-%tky
                        %element-ProductID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Product ID must be entered' )
                      ) TO reported-product.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_product
        FIELDS product_id
        WHERE product_id = @product-ProductID
        INTO @DATA(existing_id).

      IF existing_id IS NOT INITIAL.
        APPEND VALUE #( %tky = product-%tky ) TO failed-product.
        APPEND VALUE #( %tky               = product-%tky
                        %element-ProductID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Product ID already exists' )
                      ) TO reported-product.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Category must be one of the allowed values
*--------------------------------------------------------------------*
  METHOD validateCategory.

    READ ENTITIES OF zi_its_product IN LOCAL MODE
      ENTITY Product
        FIELDS ( Category )
        WITH CORRESPONDING #( keys )
      RESULT DATA(products).

    LOOP AT products INTO DATA(product).

      IF product-Category <> 'HARDWARE' AND product-Category <> 'ACCESSORY'.
        APPEND VALUE #( %tky = product-%tky ) TO failed-product.
        APPEND VALUE #( %tky              = product-%tky
                        %element-Category = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Category must be HARDWARE or ACCESSORY' )
                      ) TO reported-product.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - price and quantity rules
*--------------------------------------------------------------------*
  METHOD validatePrices.

    READ ENTITIES OF zi_its_product IN LOCAL MODE
      ENTITY Product
        FIELDS ( SalePrice CostPrice ReorderLevel )
        WITH CORRESPONDING #( keys )
      RESULT DATA(products).

    LOOP AT products INTO DATA(product).

      IF product-CostPrice <= 0.
        APPEND VALUE #( %tky = product-%tky ) TO failed-product.
        APPEND VALUE #( %tky               = product-%tky
                        %element-CostPrice = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Cost price must be greater than zero' )
                      ) TO reported-product.
      ENDIF.

      IF product-SalePrice <= 0.
        APPEND VALUE #( %tky = product-%tky ) TO failed-product.
        APPEND VALUE #( %tky               = product-%tky
                        %element-SalePrice = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Sale price must be greater than zero' )
                      ) TO reported-product.

      ELSEIF product-SalePrice < product-CostPrice.
        APPEND VALUE #( %tky = product-%tky ) TO failed-product.
        APPEND VALUE #( %tky               = product-%tky
                        %element-SalePrice = if_abap_behv=>mk-on
                        %element-CostPrice = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Sale price must not be lower than cost price' )
                      ) TO reported-product.
      ENDIF.

      IF product-ReorderLevel < 0.
        APPEND VALUE #( %tky = product-%tky ) TO failed-product.
        APPEND VALUE #( %tky                  = product-%tky
                        %element-ReorderLevel = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Reorder level must not be negative' )
                      ) TO reported-product.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
