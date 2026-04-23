#pragma once

// Trap Handler Declarations
// Applications should define ONE of the following modes:
//
// DIRECT MODE (mtvec[1:0] = 00):
//   - Define: trap_handler()
//   - Single handler dispatches all traps (exceptions + interrupts)
//
// VECTORED MODE (mtvec[1:0] = 01):
//   - Define: exception_handler() + individual ISRs (optional - weak defaults provided)
//   - Hardware jumps directly to ISR based on mcause
//   - Override only the ISRs you need; unused ISRs use weak defaults

// Direct mode: single trap handler for all traps
void __attribute__((interrupt("machine"))) trap_handler(void);

// Vectored mode: exception handler for synchronous traps
// Weak default provided - override in your application if needed
void __attribute__((weak, interrupt("machine"))) exception_handler(void);

// Vectored mode: individual interrupt service routines
// Weak defaults provided - override only the ISRs you need
void __attribute__((weak, interrupt("machine"))) isr_spi(void);    // mcause = 16
void __attribute__((weak, interrupt("machine"))) isr_uart(void);   // mcause = 17
void __attribute__((weak, interrupt("machine"))) isr_gpio(void);   // mcause = 18
void __attribute__((weak, interrupt("machine"))) isr_timer(void);  // mcause = 19
void __attribute__((weak, interrupt("machine"))) isr_mm(void);     // mcause = 20
