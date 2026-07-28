CLASS zbp_i_its_ustester DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zbp_i_its_ustester IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    DATA(current_user) = cl_abap_context_info=>get_user_technical_name( ).
    out->write( |Current user  : [{ current_user }] length={ strlen( current_user ) }| ).

    SELECT SINGLE FROM zits_employee
      FIELDS employee_id, user_name, role_code, is_active
      WHERE employee_id = 'E0001'
      INTO @DATA(mgr).
    out->write( |Manager stored: [{ mgr-user_name }] role={ mgr-role_code } active={ mgr-is_active }| ).

    " เทียบตรงแบบที่ action ใช้จริง
    SELECT SINGLE FROM zits_employee FIELDS employee_id
      WHERE user_name = @current_user AND role_code = 'M' AND is_active = 'X'
      INTO @DATA(match).
    out->write( COND #( WHEN match IS NOT INITIAL THEN |MATCH → { match }| ELSE |NO MATCH| ) ).

  ENDMETHOD.
ENDCLASS.
