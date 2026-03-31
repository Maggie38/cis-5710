        .section .data
input_string:   .asciz "He~ Jllo world!"

        # tohost/fromhost are data locations used by Spike
        .align 8
tohost: .byte 0
        .align 8
fromhost: .byte 0

        .section .text
        .globl _start
_start:
        # Load the address of the input string into a0
        la a0, input_string

        # Your code here!
        li t2, 32       # for subtracting from lower case ascii
        li t3, 122      # for upper bound (greater than z)
        li t4, 97       # for lower bound (less than a)
loop:
        lb t0, 0(a0)            # load current byte into register t0
        beqz t0, end_program    # if null jump to end of program, if out of lower case bounds jump to continue 
        bgt t0, t3, continue
        blt t0, t4, continue
        sub t0, t0, t2          # subtract 32 to make upper case
continue:
        sb t0, 0(a0)            # store modified byte back
        addi a0, a0, 1          # increment index
        j loop                  # loop back
end_program:
        # jump here when you're done
        j end_program