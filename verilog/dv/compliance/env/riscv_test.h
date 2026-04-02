// Custom riscv_test.h for bare-metal RV32I core without CSR/trap support.
// Replaces the standard env/p/riscv_test.h which uses csrr/csrw/mret/ecall.

#ifndef _CUSTOM_RISCV_TEST_H
#define _CUSTOM_RISCV_TEST_H

//-----------------------------------------------------------------------
// Minimal defines — no CSR, no trap, no mret
//-----------------------------------------------------------------------

#define RVTEST_RV32U   .macro init; .endm
#define RVTEST_RV64U   RVTEST_RV32U

#define TESTNUM gp

// TOHOST address — word at byte address 0x2000 (in data memory region)
// The testbench watches for writes here.
#ifndef TOHOST_ADDR
#define TOHOST_ADDR 0x1000
#endif

#define RVTEST_CODE_BEGIN        \
        .section .text.init;     \
        .align  2;               \
        .globl _start;           \
_start:                          \
        /* Clear gp (TESTNUM) */ \
        li   gp, 0;              \
        /* Set sp for data area */\
        li   sp, 0x3000;         \
        init;

#define RVTEST_CODE_END          \
        unimp

#define RVTEST_PASS              \
        li   gp, 1;             \
        li   t0, TOHOST_ADDR;   \
        sw   gp, 0(t0);         \
1:      j    1b;

#define RVTEST_FAIL              \
        sll  gp, gp, 1;         \
        or   gp, gp, 1;         \
        li   t0, TOHOST_ADDR;   \
        sw   gp, 0(t0);         \
1:      j    1b;

#define RVTEST_DATA_BEGIN        \
        .data;                   \
        .align 4;                \
        .global tohost;          \
tohost: .word 0;                 \
        .align 4;                \
        .global begin_signature; \
begin_signature:

#define RVTEST_DATA_END          \
        .align 4;                \
        .global end_signature;   \
end_signature:

#endif // _CUSTOM_RISCV_TEST_H
