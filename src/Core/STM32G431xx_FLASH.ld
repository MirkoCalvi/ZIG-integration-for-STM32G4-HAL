/* STM32G431 linker script */

MEMORY
{
    FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 128K  /* Adjust as needed */
    RAM (xrw)  : ORIGIN = 0x20000000, LENGTH = 32K    /* Adjust as needed */
}

SECTIONS
{
    .text :
    {
        KEEP(*(.isr_vector))      /* Keep interrupt vector table in flash */
        *(.text*)                 /* Code */
        *(.rodata*)               /* Read-only data */
    } > FLASH

    .data : AT(ADDR(.text) + SIZEOF(.text))
    {
        __data_start__ = .;
        *(.data*)                 /* Initialized data */
        __data_end__ = .;
    } > RAM

    .bss :
    {
        __bss_start__ = .;
        *(.bss*)                  /* Uninitialized data */
        *(COMMON)
        __bss_end__ = .;
    } > RAM

    .stack :
    {
        _stack_start = .;
        . += 0x800;               /* Allocate 2KB for the stack */
        _stack_end = .;
    } > RAM
}

/* Define symbols for entry and exit points */
ENTRY(Reset_Handler)
PROVIDE(_stack_top = ORIGIN(RAM) + LENGTH(RAM)); /* Define stack top */
