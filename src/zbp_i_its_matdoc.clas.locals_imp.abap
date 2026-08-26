CLASS lhc_MaterialDocument DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR MaterialDocument RESULT result.

    METHODS assignMatDocNumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR MaterialDocument~assignMatDocNumber.

ENDCLASS.


CLASS lhc_MaterialDocument IMPLEMENTATION.

  METHOD get_global_authorizations.
  ENDMETHOD.


*--------------------------------------------------------------------*
* DETERMINATION - assign the next sequential material document number
*--------------------------------------------------------------------*
  METHOD assignMatDocNumber.

    READ ENTITIES OF zi_its_matdoc IN LOCAL MODE
      ENTITY MaterialDocument
        FIELDS ( MatDocNumber )
        WITH CORRESPONDING #( keys )
      RESULT DATA(matdocs).

    SELECT SINGLE FROM zits_matdoc
      FIELDS MAX( matdoc_number )
      INTO @DATA(max_number).

    DATA updates TYPE TABLE FOR UPDATE zi_its_matdoc.

    LOOP AT matdocs INTO DATA(matdoc).

      IF matdoc-MatDocNumber IS NOT INITIAL.
        CONTINUE.
      ENDIF.

      max_number += 1.

      APPEND VALUE #( %tky         = matdoc-%tky
                      MatDocNumber = max_number ) TO updates.
    ENDLOOP.

    IF updates IS NOT INITIAL.
      MODIFY ENTITIES OF zi_its_matdoc IN LOCAL MODE
        ENTITY MaterialDocument
          UPDATE FIELDS ( MatDocNumber )
          WITH updates
        REPORTED DATA(rep).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
