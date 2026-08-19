CLASS lhc_Partner DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Partner RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Partner~setDefaults.

    METHODS validatePartnerID FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validatePartnerID.

    METHODS validatePartnerName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validatePartnerName.

    METHODS validateRole FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validateRole.

    METHODS validateType FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validateType.

    METHODS validateTaxID FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validateTaxID.

    METHODS validateEmail FOR VALIDATE ON SAVE
      IMPORTING keys FOR Partner~validateEmail.

ENDCLASS.


CLASS lhc_Partner IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - set default values on create
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_partner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( IsActive )
        WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    DATA updates TYPE TABLE FOR UPDATE zi_its_partner.

    LOOP AT partners INTO DATA(partner).
      IF partner-IsActive IS INITIAL.
        APPEND VALUE #( %tky     = partner-%tky
                        IsActive = 'X' ) TO updates.
      ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_partner IN LOCAL MODE
        ENTITY Partner
          UPDATE FIELDS ( IsActive )
          WITH updates
        REPORTED DATA(modify_reported).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Partner ID must exist and be unique
*--------------------------------------------------------------------*
  METHOD validatePartnerID.

    READ ENTITIES OF zi_its_partner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( PartnerID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    LOOP AT partners INTO DATA(partner).

      IF partner-PartnerID IS INITIAL.
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky               = partner-%tky
                        %element-PartnerID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Partner ID must be entered' )
                      ) TO reported-partner.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_partner
        FIELDS partner_id
        WHERE partner_id = @partner-PartnerID
        INTO @DATA(existing_id).

      IF existing_id IS NOT INITIAL.
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky               = partner-%tky
                        %element-PartnerID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Partner ID already exists' )
                      ) TO reported-partner.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Partner Name must be entered
*--------------------------------------------------------------------*
  METHOD validatePartnerName.

    READ ENTITIES OF zi_its_partner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( PartnerName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    LOOP AT partners INTO DATA(partner).

      IF partner-PartnerName IS INITIAL.
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky                 = partner-%tky
                        %element-PartnerName = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Partner Name must be entered' )
                      ) TO reported-partner.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Partner Role must be C (Customer), S (Supplier) or B (Both)
*--------------------------------------------------------------------*
  METHOD validateRole.

    READ ENTITIES OF zi_its_partner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( PartnerRole )
        WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    LOOP AT partners INTO DATA(partner).

      IF partner-PartnerRole <> 'C' AND partner-PartnerRole <> 'S' AND partner-PartnerRole <> 'B'.
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky                 = partner-%tky
                        %element-PartnerRole = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Partner Role must be C (Customer), S (Supplier) or B (Both)' )
                      ) TO reported-partner.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Partner Type must be I (Individual) or O (Organization)
*--------------------------------------------------------------------*
  METHOD validateType.

    READ ENTITIES OF zi_its_partner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( PartnerType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    LOOP AT partners INTO DATA(partner).

      IF partner-PartnerType <> 'I' AND partner-PartnerType <> 'O'.
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky                 = partner-%tky
                        %element-PartnerType = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Partner Type must be I (Individual) or O (Organization)' )
                      ) TO reported-partner.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Tax ID, if entered, must be 13 digits
*--------------------------------------------------------------------*
  METHOD validateTaxID.

    READ ENTITIES OF zi_its_partner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( TaxID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    LOOP AT partners INTO DATA(partner).

      IF partner-TaxID IS INITIAL.
        CONTINUE.
      ENDIF.

      IF strlen( partner-TaxID ) <> 13 OR partner-TaxID CN '0123456789'.
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky            = partner-%tky
                        %element-TaxID  = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Tax ID must be 13 digits' )
                      ) TO reported-partner.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Email, if entered, must contain '@'
*--------------------------------------------------------------------*
  METHOD validateEmail.

    READ ENTITIES OF zi_its_partner IN LOCAL MODE
      ENTITY Partner
        FIELDS ( Email )
        WITH CORRESPONDING #( keys )
      RESULT DATA(partners).

    LOOP AT partners INTO DATA(partner).

      IF partner-Email IS INITIAL.
        CONTINUE.
      ENDIF.

      IF NOT partner-Email CS '@'.
        APPEND VALUE #( %tky = partner-%tky ) TO failed-partner.
        APPEND VALUE #( %tky           = partner-%tky
                        %element-Email = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Email address is not valid' )
                      ) TO reported-partner.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
