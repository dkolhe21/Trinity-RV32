#include <defs.h>
#include <stub.c>

void main() {
  reg_mprj_io_31 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_30 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_29 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_28 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_27 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_26 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_25 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_24 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_23 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_22 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_21 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_20 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_19 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_18 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_17 = GPIO_MODE_MGMT_STD_OUTPUT;
  reg_mprj_io_16 = GPIO_MODE_MGMT_STD_OUTPUT;

  reg_mprj_io_15 = GPIO_MODE_USER_STD_OUTPUT;
  reg_mprj_io_14 = GPIO_MODE_USER_STD_OUTPUT;
  reg_mprj_io_13 = GPIO_MODE_USER_STD_OUTPUT;
  reg_mprj_io_12 = GPIO_MODE_USER_STD_OUTPUT;
  reg_mprj_io_11 = GPIO_MODE_USER_STD_OUTPUT;
  reg_mprj_io_10 = GPIO_MODE_USER_STD_OUTPUT;
  reg_mprj_io_9 = GPIO_MODE_USER_STD_OUTPUT;
  reg_mprj_io_8 = GPIO_MODE_USER_STD_OUTPUT;

  // BIST outputs
  reg_mprj_io_7 = GPIO_MODE_USER_STD_OUTPUT;
  reg_mprj_io_6 = GPIO_MODE_USER_STD_OUTPUT;

  // BIST input
  reg_mprj_io_5 = GPIO_MODE_USER_STD_INPUT_NOPULL;

  // JTAG TRST_N
  reg_mprj_io_4 = GPIO_MODE_USER_STD_INPUT_NOPULL;

  // JTAG TDO
  reg_mprj_io_3 = GPIO_MODE_USER_STD_OUTPUT;

  // JTAG TDI, TMS, TCK
  reg_mprj_io_2 = GPIO_MODE_USER_STD_INPUT_NOPULL;
  reg_mprj_io_1 = GPIO_MODE_USER_STD_INPUT_NOPULL;
  reg_mprj_io_0 = GPIO_MODE_USER_STD_INPUT_NOPULL;

  reg_uart_enable = 1;

  // Apply configuration
  reg_mprj_xfer = 1;
  while (reg_mprj_xfer == 1)
    ;

  // Flag start of the test
  reg_mprj_datal = 0xAB400000;

  // Loop indefinitely - the testbench handles JTAG checks and finishes
  // simulation
  while (1) {
  }
}
