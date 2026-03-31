
uppercase.bin:     file format elf32-littleriscv


Disassembly of section .text:

00010074 <_start>:
   10074:	ffff2517          	auipc	a0,0xffff2
   10078:	f8c50513          	addi	a0,a0,-116 # 2000 <__DATA_BEGIN__>
   1007c:	02000393          	li	t2,32
   10080:	07a00e13          	li	t3,122
   10084:	06100e93          	li	t4,97

00010088 <loop>:
   10088:	00050283          	lb	t0,0(a0)
   1008c:	00028e63          	beqz	t0,100a8 <end_program>
   10090:	005e4663          	blt	t3,t0,1009c <continue>
   10094:	01d2c463          	blt	t0,t4,1009c <continue>
   10098:	407282b3          	sub	t0,t0,t2

0001009c <continue>:
   1009c:	00550023          	sb	t0,0(a0)
   100a0:	00150513          	addi	a0,a0,1
   100a4:	fe5ff06f          	j	10088 <loop>

000100a8 <end_program>:
   100a8:	0000006f          	j	100a8 <end_program>
