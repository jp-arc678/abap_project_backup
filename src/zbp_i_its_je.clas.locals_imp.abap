CLASS lhc_JournalEntry DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR JournalEntry RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR JournalEntry RESULT result.

    METHODS getItemFeatures FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR JournalEntryItem RESULT result.

    METHODS setHeaderDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR JournalEntry~setHeaderDefaults.

    METHODS assignJENumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR JournalEntry~assignJENumber.

    METHODS assignItemPos FOR DETERMINE ON MODIFY
      IMPORTING keys FOR JournalEntryItem~assignItemPos.

    METHODS calcTotals FOR DETERMINE ON MODIFY
      IMPORTING keys FOR JournalEntryItem~calcTotals.

    METHODS autoPostSystemEntry FOR DETERMINE ON SAVE
      IMPORTING keys FOR JournalEntry~autoPostSystemEntry.

    METHODS validateBalance FOR VALIDATE ON SAVE
      IMPORTING keys FOR JournalEntry~validateBalance.

    METHODS validateManualCreator FOR VALIDATE ON SAVE
      IMPORTING keys FOR JournalEntry~validateManualCreator.

    METHODS validateLine FOR VALIDATE ON SAVE
      IMPORTING keys FOR JournalEntryItem~validateLine.

    METHODS Post FOR MODIFY
      IMPORTING keys FOR ACTION JournalEntry~Post RESULT result.

    "--- is the logged-in user an active employee with the accounting role? ---
    METHODS is_accounting RETURNING VALUE(rv_ok) TYPE abap_bool.

ENDCLASS.


CLASS lhc_JournalEntry IMPLEMENTATION.

*--------------------------------------------------------------------*
* Helper - only role 'A' (accounting) may maintain journal entries.
* Everybody else can read them but not create, change or post.
*--------------------------------------------------------------------*
  METHOD is_accounting.

    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    SELECT SINGLE FROM zits_employee
      FIELDS role_code
      WHERE upper( user_name ) = @current_user
        AND is_active = 'X'
      INTO @DATA(role).

    rv_ok = COND abap_bool( WHEN role = 'A' THEN abap_true ELSE abap_false ).

  ENDMETHOD.


*--------------------------------------------------------------------*
* GLOBAL AUTHORIZATION
*
* Create has to stay open here. Sales orders and purchase orders create
* their journal entry through cross-BO EML, and that EML runs under the
* salesperson's / warehouse staff's user - a global check on role 'A'
* would reject those postings before they ever reach the BO.
*
* "Only accounting may create a journal entry BY HAND" is therefore
* enforced at save time in validateManualCreator instead, which can see
* whether the entry carries a reference document. Same two-layer idea as
* SalesOrder (get_global_authorizations + validateCreatorRole), just with
* the decisive check on the instance layer because that is the only layer
* that knows where the entry came from.
*--------------------------------------------------------------------*
  METHOD get_global_authorizations.

    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* HEADER DEFAULTS - posting date, currency, document type, status,
* and the branch of the logged-in employee.
* Accounting staff have no branch of their own, so BranchID simply
* stays blank for them - that is correct, a journal entry does not
* have to belong to one branch.
*--------------------------------------------------------------------*
  METHOD setHeaderDefaults.

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntry
        FIELDS ( PostingDate CurrencyCode DocType PostingStatus BranchID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entries).

    DATA(current_user) = to_upper( cl_abap_context_info=>get_user_technical_name( ) ).

    SELECT SINGLE FROM zits_employee
      FIELDS branch_id
      WHERE upper( user_name ) = @current_user
        AND is_active = 'X'
      INTO @DATA(current_branch).

    DATA updates TYPE TABLE FOR UPDATE zi_its_je.

    LOOP AT entries INTO DATA(entry).
      DATA(changed) = abap_false.

      IF entry-PostingDate IS INITIAL.
        entry-PostingDate = cl_abap_context_info=>get_system_date( ).
        changed = abap_true.
      ENDIF.
      IF entry-CurrencyCode IS INITIAL.
        entry-CurrencyCode = 'THB'.
        changed = abap_true.
      ENDIF.
      IF entry-DocType IS INITIAL.
        entry-DocType = 'SA'.               "SA = manual accounting entry
        changed = abap_true.
      ENDIF.
      IF entry-PostingStatus IS INITIAL.
        entry-PostingStatus = 'D'.          "D = Draft
        changed = abap_true.
      ENDIF.
      IF entry-BranchID IS INITIAL AND current_branch IS NOT INITIAL.
        entry-BranchID = current_branch.
        changed = abap_true.
      ENDIF.

      IF changed = abap_true.
        APPEND VALUE #( %tky          = entry-%tky
                        PostingDate   = entry-PostingDate
                        CurrencyCode  = entry-CurrencyCode
                        DocType       = entry-DocType
                        PostingStatus = entry-PostingStatus
                        BranchID      = entry-BranchID ) TO updates.
      ENDIF.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry
          UPDATE FIELDS ( PostingDate CurrencyCode DocType PostingStatus BranchID )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* ITEM - number the lines 001, 002, 003... inside their own parent and
* copy the currency down from the header.
* Idempotent: a line that already carries a number keeps it, so the
* numbering does not shuffle when a later line is added.
*--------------------------------------------------------------------*
  METHOD assignItemPos.

    "--- from the item keys, find the parent headers ---
    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntryItem BY \_JournalEntry
        FROM CORRESPONDING #( keys )
      RESULT DATA(headers).

    SORT headers BY %tky.
    DELETE ADJACENT DUPLICATES FROM headers COMPARING %tky.

    DATA updates TYPE TABLE FOR UPDATE zi_its_jeitem.

    LOOP AT headers INTO DATA(header_key).

      "--- currency of this entry, to copy down onto its lines ---
      READ ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry
          FIELDS ( CurrencyCode )
          WITH VALUE #( ( %tky = header_key-%tky ) )
        RESULT DATA(header_data).

      READ TABLE header_data INTO DATA(header) INDEX 1.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      READ ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry BY \_Item
          FIELDS ( ItemPos CurrencyCode )
          WITH VALUE #( ( %tky = header_key-%tky ) )
        RESULT DATA(items).

      "--- highest line number already handed out inside this entry ---
      DATA(next_pos) = 0.
      LOOP AT items INTO DATA(item).
        IF item-ItemPos > next_pos.
          next_pos = item-ItemPos.
        ENDIF.
      ENDLOOP.

      LOOP AT items INTO item.

        DATA(needs_pos)      = COND abap_bool( WHEN item-ItemPos IS INITIAL
                                               THEN abap_true ELSE abap_false ).
        DATA(needs_currency) = COND abap_bool( WHEN item-CurrencyCode IS INITIAL
                                                AND header-CurrencyCode IS NOT INITIAL
                                               THEN abap_true ELSE abap_false ).

        IF needs_pos = abap_false AND needs_currency = abap_false.
          CONTINUE.
        ENDIF.

        IF needs_pos = abap_true.
          next_pos = next_pos + 1.
          item-ItemPos = next_pos.
        ENDIF.

        IF needs_currency = abap_true.
          item-CurrencyCode = header-CurrencyCode.
        ENDIF.

        APPEND VALUE #( %tky         = item-%tky
                        ItemPos      = item-ItemPos
                        CurrencyCode = item-CurrencyCode ) TO updates.
      ENDLOOP.

    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntryItem
          UPDATE FIELDS ( ItemPos CurrencyCode )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* HEADER TOTALS - sum the debit lines and the credit lines separately.
* Amounts are always stored positive; the direction comes from
* DCIndicator, never from a negative number.
*
* Triggered only by the fields the user actually edits (Amount,
* DCIndicator) plus create/delete of a line - never by TotalDebit or
* TotalCredit, which are the fields this determination writes itself
* (hard-won rule 3).
*--------------------------------------------------------------------*
  METHOD calcTotals.

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntryItem BY \_JournalEntry
        FROM CORRESPONDING #( keys )
      RESULT DATA(headers).

    SORT headers BY %tky.
    DELETE ADJACENT DUPLICATES FROM headers COMPARING %tky.

    DATA updates    TYPE TABLE FOR UPDATE zi_its_je.
    DATA sum_debit  TYPE zits_je-total_debit.
    DATA sum_credit TYPE zits_je-total_credit.

    LOOP AT headers INTO DATA(header).

      READ ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry BY \_Item
          FIELDS ( DCIndicator Amount )
          WITH VALUE #( ( %tky = header-%tky ) )
        RESULT DATA(items).

      CLEAR sum_debit.
      CLEAR sum_credit.

      LOOP AT items INTO DATA(item).
        IF item-DCIndicator = 'D'.
          sum_debit = sum_debit + item-Amount.
        ELSEIF item-DCIndicator = 'C'.
          sum_credit = sum_credit + item-Amount.
        ENDIF.
      ENDLOOP.

      APPEND VALUE #( %tky        = header-%tky
                      TotalDebit  = sum_debit
                      TotalCredit = sum_credit ) TO updates.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry
          UPDATE FIELDS ( TotalDebit TotalCredit )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* AUTO-POST - an entry that carries a reference document was generated
* by an already approved sale or goods receipt, not typed by a person,
* so it goes straight to Posted instead of waiting in Draft.
*
* This runs on save, not on modify, for two reasons: the lines have to
* exist before the entry can be called posted, and setting the status
* earlier would freeze the entry (see get_instance_features) while its
* own lines are still being created.
*
* Hand-typed entries (no reference document) are untouched here - they
* stay Draft until accounting presses Post.
*
* ⚠️ PARALLEL PATH: this and the Post action below are the only two
* places that set PostingStatus = 'P'. They are deliberately separate -
* this one for documents generated by a business flow, Post for entries
* a person typed - but they must stay in step. Change one, change the
* other, and keep the balance check identical in both.
*--------------------------------------------------------------------*
  METHOD autoPostSystemEntry.

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntry
        FIELDS ( RefDocType PostingStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entries).

    DATA updates TYPE TABLE FOR UPDATE zi_its_je.

    LOOP AT entries INTO DATA(entry).

      IF entry-RefDocType <> 'SO' AND entry-RefDocType <> 'PO'.
        CONTINUE.
      ENDIF.

      IF entry-PostingStatus = 'P'.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky          = entry-%tky
                      PostingStatus = 'P' ) TO updates.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry
          UPDATE FIELDS ( PostingStatus )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* NUMBERING - JENumber = MAX(je_number) + 1 on save
*--------------------------------------------------------------------*
  METHOD assignJENumber.

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntry
        FIELDS ( JENumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entries).

    SELECT SINGLE FROM zits_je
      FIELDS MAX( je_number )
      INTO @DATA(max_number).

    DATA updates TYPE TABLE FOR UPDATE zi_its_je.

    LOOP AT entries INTO DATA(entry).

      "--- skip entries that already carry a number ---
      IF entry-JENumber IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      max_number += 1.

      APPEND VALUE #( %tky     = entry-%tky
                      JENumber = max_number ) TO updates.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry
          UPDATE FIELDS ( JENumber )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.


*--------------------------------------------------------------------*
* THE RULE THAT DEFINES DOUBLE-ENTRY BOOKKEEPING
*   total of all debit lines must equal total of all credit lines
*
* The sums are recomputed here from the lines themselves rather than
* trusting TotalDebit / TotalCredit on the header, so a stale total can
* never let an unbalanced document through.
*--------------------------------------------------------------------*
  METHOD validateBalance.

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntry
        FIELDS ( JENumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entries).

    DATA sum_debit  TYPE zits_je-total_debit.
    DATA sum_credit TYPE zits_je-total_credit.

    LOOP AT entries INTO DATA(entry).

      READ ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry BY \_Item
          FIELDS ( DCIndicator Amount )
          WITH VALUE #( ( %tky = entry-%tky ) )
        RESULT DATA(items).

      "--- a journal entry needs at least one debit and one credit line ---
      IF lines( items ) < 2.
        APPEND VALUE #( %tky = entry-%tky ) TO failed-journalentry.
        APPEND VALUE #( %tky = entry-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'A journal entry must have at least two line items' )
                      ) TO reported-journalentry.
        CONTINUE.
      ENDIF.

      CLEAR sum_debit.
      CLEAR sum_credit.

      LOOP AT items INTO DATA(item).
        IF item-DCIndicator = 'D'.
          sum_debit = sum_debit + item-Amount.
        ELSEIF item-DCIndicator = 'C'.
          sum_credit = sum_credit + item-Amount.
        ENDIF.
      ENDLOOP.

      IF sum_debit <= 0.
        APPEND VALUE #( %tky = entry-%tky ) TO failed-journalentry.
        APPEND VALUE #( %tky = entry-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Total debit must be greater than zero' )
                      ) TO reported-journalentry.
        CONTINUE.
      ENDIF.

      IF sum_debit <> sum_credit.
        APPEND VALUE #( %tky = entry-%tky ) TO failed-journalentry.
        APPEND VALUE #( %tky = entry-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Debits ({ sum_debit }) do not equal credits ({ sum_credit })| )
                      ) TO reported-journalentry.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* Only accounting may create a journal entry BY HAND.
*
* An entry that carries a reference document was generated by a sales
* order or a purchase order, so the user who completed that document is
* allowed to have caused it - that is the whole point of automatic
* posting. An entry with no reference document was typed by a person,
* and that person must be accounting.
*--------------------------------------------------------------------*
  METHOD validateManualCreator.

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntry
        FIELDS ( RefDocType RefDocUUID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entries).

    DATA(is_acc) = is_accounting( ).

    LOOP AT entries INTO DATA(entry).

      "--- A reference type alone proves nothing - anybody could type 'SO'
      "    into the field. The referenced document has to actually exist
      "    and be in a state that really does produce a journal entry. ---
      DATA(from_real_document) = abap_false.

      IF entry-RefDocType = 'SO' AND entry-RefDocUUID IS NOT INITIAL.

        SELECT SINGLE FROM zits_so
          FIELDS overall_status
          WHERE so_uuid = @entry-RefDocUUID
          INTO @DATA(so_status).

        "--- 'F' = already completed, 'C' = being completed right now.
        "    'C' has to count: this validation runs before the save writes
        "    the new status, so an order completing in THIS unit of work
        "    still reads as Confirmed from the database. ---
        IF sy-subrc = 0 AND ( so_status = 'F' OR so_status = 'C' ).
          from_real_document = abap_true.
        ENDIF.

      ELSEIF entry-RefDocType = 'PO' AND entry-RefDocUUID IS NOT INITIAL.

        SELECT SINGLE FROM zits_po
          FIELDS overall_status
          WHERE po_uuid = @entry-RefDocUUID
          INTO @DATA(po_status).

        "--- 'R' = already received, 'A' = being received right now ---
        IF sy-subrc = 0 AND ( po_status = 'R' OR po_status = 'A' ).
          from_real_document = abap_true.
        ENDIF.

      ENDIF.

      IF from_real_document = abap_true.
        CONTINUE.
      ENDIF.

      "--- everything else is a hand-typed entry: accounting only ---
      IF is_acc = abap_true.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = entry-%tky ) TO failed-journalentry.
      APPEND VALUE #( %tky = entry-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-error
                               text     = 'Only accounting may create journal entries' )
                    ) TO reported-journalentry.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* LINE VALIDATION - account, direction, amount, cost center
*--------------------------------------------------------------------*
  METHOD validateLine.

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntryItem
        FIELDS ( GLAccount DCIndicator Amount CostCenterID )
        WITH CORRESPONDING #( keys )
      RESULT DATA(items).

    LOOP AT items INTO DATA(item).

      "--- GL account must be entered, exist and be active ---
      IF item-GLAccount IS INITIAL.
        APPEND VALUE #( %tky = item-%tky ) TO failed-journalentryitem.
        APPEND VALUE #( %tky               = item-%tky
                        %element-GLAccount = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'GL account must be entered' )
                      ) TO reported-journalentryitem.
        CONTINUE.
      ENDIF.

      SELECT SINGLE FROM zits_glacct
        FIELDS is_active
        WHERE gl_account = @item-GLAccount
        INTO @DATA(gl_active).

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-journalentryitem.
        APPEND VALUE #( %tky               = item-%tky
                        %element-GLAccount = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'GL account does not exist' )
                      ) TO reported-journalentryitem.
        CONTINUE.
      ENDIF.

      IF gl_active <> 'X'.
        APPEND VALUE #( %tky = item-%tky ) TO failed-journalentryitem.
        APPEND VALUE #( %tky               = item-%tky
                        %element-GLAccount = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'GL account is not active' )
                      ) TO reported-journalentryitem.
        CONTINUE.
      ENDIF.

      "--- direction must be debit or credit ---
      IF item-DCIndicator <> 'D' AND item-DCIndicator <> 'C'.
        APPEND VALUE #( %tky = item-%tky ) TO failed-journalentryitem.
        APPEND VALUE #( %tky                 = item-%tky
                        %element-DCIndicator = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Debit/credit indicator must be D or C' )
                      ) TO reported-journalentryitem.
        CONTINUE.
      ENDIF.

      "--- amounts are always stored positive; direction comes from DCIndicator ---
      IF item-Amount <= 0.
        APPEND VALUE #( %tky = item-%tky ) TO failed-journalentryitem.
        APPEND VALUE #( %tky            = item-%tky
                        %element-Amount = if_abap_behv=>mk-on
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Amount must be positive - use the debit/credit indicator for direction' )
                      ) TO reported-journalentryitem.
        CONTINUE.
      ENDIF.

      "--- cost center is optional, but if filled it must exist and be active ---
      IF item-CostCenterID IS NOT INITIAL.

        SELECT SINGLE FROM zits_costctr
          FIELDS is_active
          WHERE cost_center_id = @item-CostCenterID
          INTO @DATA(cc_active).

        IF sy-subrc <> 0.
          APPEND VALUE #( %tky = item-%tky ) TO failed-journalentryitem.
          APPEND VALUE #( %tky                  = item-%tky
                          %element-CostCenterID = if_abap_behv=>mk-on
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'Cost center does not exist' )
                        ) TO reported-journalentryitem.
          CONTINUE.
        ENDIF.

        IF cc_active <> 'X'.
          APPEND VALUE #( %tky = item-%tky ) TO failed-journalentryitem.
          APPEND VALUE #( %tky                  = item-%tky
                          %element-CostCenterID = if_abap_behv=>mk-on
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = 'Cost center is not active' )
                        ) TO reported-journalentryitem.
        ENDIF.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* INSTANCE FEATURES (header)
*
* A posted entry is frozen: no update, no delete, no new line. This is
* done here rather than by dropping update/delete from the behaviour
* definition, because the framework still needs the update capability
* for the Post action itself to write PostingStatus.
*
* Freezing depends on the document's own state only, never on who is
* looking. Mixing the role into it would block the cross-BO postings
* from SalesOrder and PurchaseOrder, which run under the salesperson's
* user - who may act is decided by validateManualCreator and by the
* accounting-only check inside Post.
*--------------------------------------------------------------------*
  METHOD get_instance_features.

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntry
        FIELDS ( PostingStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entries).

    DATA(is_acc) = is_accounting( ).

    result = VALUE #( FOR entry IN entries
      LET is_frozen = COND abap_bool( WHEN entry-PostingStatus = 'P'
                                      THEN abap_true ELSE abap_false )
      IN
      ( %tky = entry-%tky

        %update = COND #( WHEN is_frozen = abap_true
                          THEN if_abap_behv=>fc-o-disabled
                          ELSE if_abap_behv=>fc-o-enabled )

        %delete = COND #( WHEN is_frozen = abap_true
                          THEN if_abap_behv=>fc-o-disabled
                          ELSE if_abap_behv=>fc-o-enabled )

        %assoc-_Item = COND #( WHEN is_frozen = abap_true
                               THEN if_abap_behv=>fc-o-disabled
                               ELSE if_abap_behv=>fc-o-enabled )

        %action-Post = COND #( WHEN entry-PostingStatus = 'D' AND is_acc = abap_true
                               THEN if_abap_behv=>fc-o-enabled
                               ELSE if_abap_behv=>fc-o-disabled )
      ) ).

  ENDMETHOD.


*--------------------------------------------------------------------*
* INSTANCE FEATURES (item) - lines follow the state of their header
*--------------------------------------------------------------------*
  METHOD getItemFeatures.

    LOOP AT keys INTO DATA(item_key).

      READ ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntryItem BY \_JournalEntry
          FIELDS ( PostingStatus )
          WITH VALUE #( ( %tky = item_key-%tky ) )
        RESULT DATA(headers).

      READ TABLE headers INTO DATA(header) INDEX 1.

      DATA(is_frozen) = COND abap_bool(
                          WHEN sy-subrc = 0 AND header-PostingStatus = 'P'
                          THEN abap_true ELSE abap_false ).

      APPEND VALUE #( %tky    = item_key-%tky
                      %update = COND #( WHEN is_frozen = abap_true
                                        THEN if_abap_behv=>fc-o-disabled
                                        ELSE if_abap_behv=>fc-o-enabled )
                      %delete = COND #( WHEN is_frozen = abap_true
                                        THEN if_abap_behv=>fc-o-disabled
                                        ELSE if_abap_behv=>fc-o-enabled )
                    ) TO result.

    ENDLOOP.

  ENDMETHOD.


*--------------------------------------------------------------------*
* POST - Draft -> Posted, accounting only.
* After this the entry is history: it can never be edited or deleted.
* A correction is made by posting a reversing entry, not by changing
* what is already there.
*
* ⚠️ PARALLEL PATH: this and autoPostSystemEntry above are the only two
* places that set PostingStatus = 'P'. This one is the manual route for
* entries somebody typed; that one is the automatic route for entries a
* sales or purchase document generated. They must be changed together,
* and the balance check must stay identical in both.
*--------------------------------------------------------------------*
  METHOD Post.

    DATA(is_acc) = is_accounting( ).

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntry
        FIELDS ( PostingStatus JENumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(entries).

    DATA updates    TYPE TABLE FOR UPDATE zi_its_je.
    DATA sum_debit  TYPE zits_je-total_debit.
    DATA sum_credit TYPE zits_je-total_credit.

    LOOP AT entries INTO DATA(entry).

      IF is_acc = abap_false.
        APPEND VALUE #( %tky = entry-%tky ) TO failed-journalentry.
        APPEND VALUE #( %tky = entry-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Only accounting may post journal entries' )
                      ) TO reported-journalentry.
        CONTINUE.
      ENDIF.

      IF entry-PostingStatus <> 'D'.
        APPEND VALUE #( %tky = entry-%tky ) TO failed-journalentry.
        APPEND VALUE #( %tky = entry-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = 'Only a draft journal entry can be posted' )
                      ) TO reported-journalentry.
        CONTINUE.
      ENDIF.

      "--- balance is re-checked here, straight from the lines ---
      READ ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry BY \_Item
          FIELDS ( DCIndicator Amount )
          WITH VALUE #( ( %tky = entry-%tky ) )
        RESULT DATA(items).

      CLEAR sum_debit.
      CLEAR sum_credit.

      LOOP AT items INTO DATA(item).
        IF item-DCIndicator = 'D'.
          sum_debit = sum_debit + item-Amount.
        ELSEIF item-DCIndicator = 'C'.
          sum_credit = sum_credit + item-Amount.
        ENDIF.
      ENDLOOP.

      IF lines( items ) < 2 OR sum_debit <= 0 OR sum_debit <> sum_credit.
        APPEND VALUE #( %tky = entry-%tky ) TO failed-journalentry.
        APPEND VALUE #( %tky = entry-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Debits ({ sum_debit }) do not equal credits ({ sum_credit }) - entry cannot be posted| )
                      ) TO reported-journalentry.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky          = entry-%tky
                      PostingStatus = 'P' ) TO updates.

    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_je IN LOCAL MODE
        ENTITY JournalEntry
          UPDATE FIELDS ( PostingStatus )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

    READ ENTITIES OF zi_its_je IN LOCAL MODE
      ENTITY JournalEntry
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(final).

    result = VALUE #( FOR e IN final ( %tky = e-%tky %param = e ) ).

  ENDMETHOD.

ENDCLASS.
