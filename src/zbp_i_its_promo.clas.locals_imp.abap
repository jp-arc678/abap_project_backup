CLASS lhc_Promotion DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      REQUEST requested_authorizations FOR Promotion RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Promotion~setDefaults.

    METHODS validateCreatorRole FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateCreatorRole.

    METHODS validateType FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateType.

    METHODS validateTypeFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateTypeFields.

    METHODS validateDiscountPercent FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateDiscountPercent.

    METHODS validateDateRange FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateDateRange.

    METHODS validateProduct FOR VALIDATE ON SAVE
      IMPORTING keys FOR Promotion~validateProduct.

ENDCLASS.


CLASS lhc_Promotion IMPLEMENTATION.

*--------------------------------------------------------------------*
* Global authorization is deliberately left open - see the comment on
* validateCreatorRole in the behaviour definition.
*--------------------------------------------------------------------*
  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DEFAULTS - a new promotion starts active, in THB, counted in pieces
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_promo IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( IsActive CurrencyCode Unit ValidFrom )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    DATA updates TYPE TABLE FOR UPDATE zi_its_promo.

    LOOP AT promos INTO DATA(promo).
      DATA(changed) = abap_false.

      IF promo-IsActive IS INITIAL.
        promo-IsActive = 'X'.
        changed = abap_true.
      ENDIF.
      IF promo-CurrencyCode IS INITIAL.
        promo-CurrencyCode = 'THB'.
        changed = abap_true.
      ENDIF.
      IF promo-Unit IS INITIAL.
        promo-Unit = 'EA'.
        changed = abap_true.
      ENDIF.
      IF promo-ValidFrom IS INITIAL.
        promo-ValidFrom = cl_abap_context_info=>get_system_date( ).
        changed = abap_true.
      ENDIF.

      IF changed = abap_true.
        APPEND VALUE #( %tky         = promo-%tky
                        IsActive     = promo-IsActive
                        CurrencyCode = promo-CurrencyCode
                        Unit         = promo-Unit
                        ValidFrom    = promo-ValidFrom ) TO updates.
      ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_promo IN LOCAL MODE
        ENTITY Promotion
          UPDATE FIELDS ( IsActive CurrencyCode Unit ValidFrom )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* Only branch managers ('M') and regional managers ('R') may maintain
* promotions - a discount is a commercial decision, not a counter one.
*--------------------------------------------------------------------*
  METHOD validateCreatorRole.

    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    SELECT SINGLE FROM zits_employee
      FIELDS role_code
      WHERE upper( user_name ) = @current_user
        AND is_active = 'X'
      INTO @DATA(role).

    IF role = 'M' OR role = 'R'.
      RETURN.
    ENDIF.

    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky = key-%tky ) TO failed-promotion.
      APPEND VALUE #( %tky = key-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Only branch or regional managers may maintain promotions' )
                    ) TO reported-promotion.
    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* TYPE - I = one product, Q = quantity threshold, A = amount threshold
*--------------------------------------------------------------------*
  METHOD validateType.

    READ ENTITIES OF zi_its_promo IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( PromoType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    LOOP AT promos INTO DATA(promo).

      IF promo-PromoType = 'I' OR promo-PromoType = 'Q' OR promo-PromoType = 'A'.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
      APPEND VALUE #( %tky               = promo-%tky
                      %element-PromoType = if_abap_behv=>mk-on
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Type must be I (product), Q (quantity) or A (amount)' )
                    ) TO reported-promotion.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* Each type uses exactly one qualifying field, and the other two must
* stay empty - otherwise a promotion could carry contradictory rules
* and there would be no single answer to "does this order qualify".
*--------------------------------------------------------------------*
  METHOD validateTypeFields.

    READ ENTITIES OF zi_its_promo IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( PromoType ProductID ThresholdQty ThresholdAmount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    LOOP AT promos INTO DATA(promo).

      CASE promo-PromoType.

        WHEN 'I'.
          IF promo-ProductID IS INITIAL.
            APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
            APPEND VALUE #( %tky               = promo-%tky
                            %element-ProductID = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'A product promotion needs a product' )
                          ) TO reported-promotion.
          ENDIF.
          IF promo-ThresholdQty IS NOT INITIAL OR promo-ThresholdAmount IS NOT INITIAL.
            APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
            APPEND VALUE #( %tky = promo-%tky
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'A product promotion must not carry a quantity or amount threshold' )
                          ) TO reported-promotion.
          ENDIF.

        WHEN 'Q'.
          IF promo-ThresholdQty <= 0.
            APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
            APPEND VALUE #( %tky                  = promo-%tky
                            %element-ThresholdQty = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'A quantity promotion needs a minimum quantity above zero' )
                          ) TO reported-promotion.
          ENDIF.
          IF promo-ProductID IS NOT INITIAL OR promo-ThresholdAmount IS NOT INITIAL.
            APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
            APPEND VALUE #( %tky = promo-%tky
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'A quantity promotion must not carry a product or amount threshold' )
                          ) TO reported-promotion.
          ENDIF.

        WHEN 'A'.
          IF promo-ThresholdAmount <= 0.
            APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
            APPEND VALUE #( %tky                     = promo-%tky
                            %element-ThresholdAmount = if_abap_behv=>mk-on
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'An amount promotion needs a minimum amount above zero' )
                          ) TO reported-promotion.
          ENDIF.
          IF promo-ProductID IS NOT INITIAL OR promo-ThresholdQty IS NOT INITIAL.
            APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
            APPEND VALUE #( %tky = promo-%tky
                            %msg = new_message_with_text(
                                     severity = if_abap_behv_message=>severity-error
                                     text     = 'An amount promotion must not carry a product or quantity threshold' )
                          ) TO reported-promotion.
          ENDIF.

      ENDCASE.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* DISCOUNT - a percentage, so it has to sit inside 0 < x <= 100
*--------------------------------------------------------------------*
  METHOD validateDiscountPercent.

    READ ENTITIES OF zi_its_promo IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( DiscountPercent )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    LOOP AT promos INTO DATA(promo).

      IF promo-DiscountPercent > 0 AND promo-DiscountPercent <= 100.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
      APPEND VALUE #( %tky                     = promo-%tky
                      %element-DiscountPercent = if_abap_behv=>mk-on
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Discount must be greater than 0 and at most 100 percent' )
                    ) TO reported-promotion.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* DATES - only checked when both are filled. An open-ended promotion
* (no end date) is legitimate.
*--------------------------------------------------------------------*
  METHOD validateDateRange.

    READ ENTITIES OF zi_its_promo IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( ValidFrom ValidTo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    LOOP AT promos INTO DATA(promo).

      IF promo-ValidFrom IS INITIAL OR promo-ValidTo IS INITIAL.
        CONTINUE.
      ENDIF.

      IF promo-ValidFrom <= promo-ValidTo.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
      APPEND VALUE #( %tky               = promo-%tky
                      %element-ValidTo   = if_abap_behv=>mk-on
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Valid To must not be earlier than Valid From' )
                    ) TO reported-promotion.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* PRODUCT - only type 'I' carries one. validateTypeFields already
* refuses a product on the other two types, so this only has to prove
* the product is real and still sold.
*--------------------------------------------------------------------*
  METHOD validateProduct.

    READ ENTITIES OF zi_its_promo IN LOCAL MODE
      ENTITY Promotion
        FIELDS ( PromoType ProductID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(promos).

    LOOP AT promos INTO DATA(promo).

      IF promo-PromoType <> 'I' OR promo-ProductID IS INITIAL.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_product
        FIELDS is_active
        WHERE product_id = @promo-ProductID
        INTO @DATA(prod_active).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
        APPEND VALUE #( %tky               = promo-%tky
                        %element-ProductID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Product does not exist' )
                      ) TO reported-promotion.
        CONTINUE.
      ENDIF.

      IF prod_active <> 'X'.
        APPEND VALUE #( %tky = promo-%tky ) TO failed-promotion.
        APPEND VALUE #( %tky               = promo-%tky
                        %element-ProductID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Product is not active' )
                      ) TO reported-promotion.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
