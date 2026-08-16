CLASS zbp_i_it_fix_active DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZBP_I_IT_FIX_ACTIVE IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    UPDATE zits_employee SET is_active = 'X' WHERE is_active = ' ' OR is_active IS INITIAL.
    COMMIT WORK.
    out->write( |Fixed active flag for all employees| ).
  ENDMETHOD.
ENDCLASS.
