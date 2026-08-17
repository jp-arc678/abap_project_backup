CLASS lhc_Company DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Company RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Company~setDefaults.

    METHODS validateCompanyID FOR VALIDATE ON SAVE
      IMPORTING keys FOR Company~validateCompanyID.

    METHODS validateCompanyName FOR VALIDATE ON SAVE
      IMPORTING keys FOR Company~validateCompanyName.

    METHODS validateTaxID FOR VALIDATE ON SAVE
      IMPORTING keys FOR Company~validateTaxID.

ENDCLASS.


CLASS lhc_Company IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - set default values on create
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_company IN LOCAL MODE
      ENTITY Company
        FIELDS ( Currency IsActive )
        WITH CORRESPONDING #( keys )
      RESULT DATA(companies).

    DATA updates TYPE TABLE FOR UPDATE zi_its_company.

    LOOP AT companies INTO DATA(company).

      DATA(needs_update) = abap_false.

      IF company-Currency IS INITIAL.
        company-Currency = 'THB'.
        needs_update = abap_true.
      ENDIF.

      IF company-IsActive IS INITIAL.
        company-IsActive = 'X'.
        needs_update = abap_true.
      ENDIF.

      IF needs_update = abap_true.
        APPEND VALUE #( %tky     = company-%tky
                        Currency = company-Currency
                        IsActive = company-IsActive ) TO updates.
      ENDIF.

    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_company IN LOCAL MODE
        ENTITY Company
          UPDATE FIELDS ( Currency IsActive )
          WITH updates
        REPORTED DATA(modify_reported).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Company ID must exist and be unique
*--------------------------------------------------------------------*
  METHOD validateCompanyID.

    READ ENTITIES OF zi_its_company IN LOCAL MODE
      ENTITY Company
        FIELDS ( CompanyID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(companies).

    LOOP AT companies INTO DATA(company).

      IF company-CompanyID IS INITIAL.
        APPEND VALUE #( %tky = company-%tky ) TO failed-company.
        APPEND VALUE #( %tky               = company-%tky
                        %element-CompanyID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Company ID must be entered' )
                      ) TO reported-company.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_company
        FIELDS company_id
        WHERE company_id = @company-CompanyID
        INTO @DATA(existing_id).

      IF existing_id IS NOT INITIAL.
        APPEND VALUE #( %tky = company-%tky ) TO failed-company.
        APPEND VALUE #( %tky               = company-%tky
                        %element-CompanyID = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Company ID already exists' )
                      ) TO reported-company.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Company Name must be entered
*--------------------------------------------------------------------*
  METHOD validateCompanyName.

    READ ENTITIES OF zi_its_company IN LOCAL MODE
      ENTITY Company
        FIELDS ( CompanyName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(companies).

    LOOP AT companies INTO DATA(company).

      IF company-CompanyName IS INITIAL.
        APPEND VALUE #( %tky = company-%tky ) TO failed-company.
        APPEND VALUE #( %tky                 = company-%tky
                        %element-CompanyName = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Company Name must be entered' )
                      ) TO reported-company.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Tax ID, if entered, must be 13 digits
*--------------------------------------------------------------------*
  METHOD validateTaxID.

    READ ENTITIES OF zi_its_company IN LOCAL MODE
      ENTITY Company
        FIELDS ( TaxID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(companies).

    LOOP AT companies INTO DATA(company).

      IF company-TaxID IS INITIAL.
        CONTINUE.
      ENDIF.

      IF strlen( company-TaxID ) <> 13 OR company-TaxID CN '0123456789'.
        APPEND VALUE #( %tky = company-%tky ) TO failed-company.
        APPEND VALUE #( %tky            = company-%tky
                        %element-TaxID  = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Tax ID must be 13 digits' )
                      ) TO reported-company.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
