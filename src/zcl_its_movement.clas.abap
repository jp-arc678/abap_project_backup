CLASS zcl_its_movement DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    "--- goods receipt from supplier, quantity + ---
    CONSTANTS gc_goods_receipt TYPE zits_matdoc-movement_type VALUE '101'.

    "--- goods issue to customer, quantity - ---
    CONSTANTS gc_goods_issue   TYPE zits_matdoc-movement_type VALUE '601'.

    "--- transfer out of a branch, quantity - (not yet used - Stock Transfer Order not built) ---
    CONSTANTS gc_transfer_out  TYPE zits_matdoc-movement_type VALUE '301'.

    "--- transfer into a branch, quantity + (not yet used - Stock Transfer Order not built) ---
    CONSTANTS gc_transfer_in   TYPE zits_matdoc-movement_type VALUE '302'.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_its_movement IMPLEMENTATION.
ENDCLASS.
