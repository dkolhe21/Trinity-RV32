/* Custom linker script for bare-metal RV32I core.
 * Memory starts at 0x0000 (not 0x80000000 like standard riscv-tests).
 * Unified memory: code at 0x0000, TOHOST at 0x1000, data after that.
 */

OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }
  .text : { *(.text) }
  . = ALIGN(0x10);
  .data : { *(.data) }
  .bss : { *(.bss) }
  _end = .;
}
