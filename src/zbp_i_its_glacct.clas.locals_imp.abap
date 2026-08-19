CLASS lhc_GLAccount DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR GLAccount RESULT result.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR GLAccount~setDefaults.

    METHODS validateGLAccount FOR VALIDATE ON SAVE
      IMPORTING keys FOR GLAccount~validateGLAccount.

    METHODS validateAccountName FOR VALIDATE ON SAVE
      IMPORTING keys FOR GLAccount~validateAccountName.

    METHODS validateAccountType FOR VALIDATE ON SAVE
      IMPORTING keys FOR GLAccount~validateAccountType.

    METHODS validateNormalBalance FOR VALIDATE ON SAVE
      IMPORTING keys FOR GLAccount~validateNormalBalance.

ENDCLASS.


CLASS lhc_GLAccount IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - default values: IsActive, and NormalBalance derived
* from AccountType when the user leaves it blank
*--------------------------------------------------------------------*
  METHOD setDefaults.

    READ ENTITIES OF zi_its_glacct IN LOCAL MODE
      ENTITY GLAccount
        FIELDS ( AccountType IsActive NormalBalance )
        WITH CORRESPONDING #( keys )
      RESULT DATA(accounts).

    DATA updates TYPE TABLE FOR UPDATE zi_its_glacct.

    LOOP AT accounts INTO DATA(account).

      DATA(needs_update) = abap_false.

      IF account-IsActive IS INITIAL.
        account-IsActive = 'X'.
        needs_update = abap_true.
      ENDIF.

      IF account-NormalBalance IS INITIAL.
        CASE account-AccountType.
          WHEN 'A' OR 'X'.
            account-NormalBalance = 'D'.
            needs_update = abap_true.
          WHEN 'L' OR 'Q' OR 'R'.
            account-NormalBalance = 'C'.
            needs_update = abap_true.
        ENDCASE.
      ENDIF.

      IF needs_update = abap_true.
        APPEND VALUE #( %tky          = account-%tky
                        IsActive      = account-IsActive
                        NormalBalance = account-NormalBalance ) TO updates.
      ENDIF.

    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_glacct IN LOCAL MODE
        ENTITY GLAccount
          UPDATE FIELDS ( IsActive NormalBalance )
          WITH updates
        REPORTED DATA(modify_reported).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - GL Account must exist and be unique
*--------------------------------------------------------------------*
  METHOD validateGLAccount.

    READ ENTITIES OF zi_its_glacct IN LOCAL MODE
      ENTITY GLAccount
        FIELDS ( GLAccount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(accounts).

    LOOP AT accounts INTO DATA(account).

      IF account-GLAccount IS INITIAL.
        APPEND VALUE #( %tky = account-%tky ) TO failed-glaccount.
        APPEND VALUE #( %tky              = account-%tky
                        %element-GLAccount = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'GL Account must be entered' )
                      ) TO reported-glaccount.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_glacct
        FIELDS gl_account
        WHERE gl_account = @account-GLAccount
        INTO @DATA(existing_account).

      IF existing_account IS NOT INITIAL.
        APPEND VALUE #( %tky = account-%tky ) TO failed-glaccount.
        APPEND VALUE #( %tky              = account-%tky
                        %element-GLAccount = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'GL Account already exists' )
                      ) TO reported-glaccount.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Account Name must be entered
*--------------------------------------------------------------------*
  METHOD validateAccountName.

    READ ENTITIES OF zi_its_glacct IN LOCAL MODE
      ENTITY GLAccount
        FIELDS ( AccountName )
        WITH CORRESPONDING #( keys )
      RESULT DATA(accounts).

    LOOP AT accounts INTO DATA(account).

      IF account-AccountName IS INITIAL.
        APPEND VALUE #( %tky = account-%tky ) TO failed-glaccount.
        APPEND VALUE #( %tky                = account-%tky
                        %element-AccountName = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Account Name must be entered' )
                      ) TO reported-glaccount.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Account Type must be one of the allowed values
*--------------------------------------------------------------------*
  METHOD validateAccountType.

    READ ENTITIES OF zi_its_glacct IN LOCAL MODE
      ENTITY GLAccount
        FIELDS ( AccountType )
        WITH CORRESPONDING #( keys )
      RESULT DATA(accounts).

    LOOP AT accounts INTO DATA(account).

      IF account-AccountType <> 'A' AND account-AccountType <> 'L' AND account-AccountType <> 'Q'
     AND account-AccountType <> 'R' AND account-AccountType <> 'X'.
        APPEND VALUE #( %tky = account-%tky ) TO failed-glaccount.
        APPEND VALUE #( %tky                = account-%tky
                        %element-AccountType = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Account Type must be A (Asset), L (Liability), Q (Equity), R (Revenue) or X (Expense)' )
                      ) TO reported-glaccount.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* VALIDATION - Normal Balance must be D (Debit) or C (Credit)
*--------------------------------------------------------------------*
  METHOD validateNormalBalance.

    READ ENTITIES OF zi_its_glacct IN LOCAL MODE
      ENTITY GLAccount
        FIELDS ( NormalBalance )
        WITH CORRESPONDING #( keys )
      RESULT DATA(accounts).

    LOOP AT accounts INTO DATA(account).

      IF account-NormalBalance <> 'D' AND account-NormalBalance <> 'C'.
        APPEND VALUE #( %tky = account-%tky ) TO failed-glaccount.
        APPEND VALUE #( %tky                  = account-%tky
                        %element-NormalBalance = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Normal Balance must be D (Debit) or C (Credit)' )
                      ) TO reported-glaccount.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
