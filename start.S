@注意事项
@1汇编注释用@符号
@2汇编中不能出现中文空格
@3汇编是个直男，程序是自上而下一行一行运行

.text
.global _start
_start:
	b reset
	ldr pc, _undifined_instruction
	ldr pc, _software_interrupt
	ldr pc, _prefetch_abort
	ldr pc, _data_abort
	ldr pc, _not_used
	ldr pc, _irq
	ldr pc, _fiq
	
@以下几组标号_xx的内存单元存放标号xx的地址，目的是为了使用ldr直接让pc指针直接跳转到xx，装载而不是偏移
_undifined_instruction: .word undifined_instruction
_software_interrupt: .word software_interrupt
_prefetch_abort: .word prefetch_abort
_data_abort: .word data_abort
_not_used: .word not_used
_irq: .word irq
_fiq: .word reset

undifined_instruction:
	nop

software_interrupt:
	nop
	
prefetch_abort:
	nop
	
data_abort:
	nop

not_used:
	nop

irq:
	nop

fiq:	
	nop

reset:
	bl set_svc
	bl disable_watchdog
	bl disable_interrupt
	bl disable_mmu
	bl clock_init
	bl init_sdram
	bl copy_to_ram
	bl stack_init
	bl clean_bss
	@bl light_led //暂时屏蔽，在main.c中实现点灯
	ldr pc,=tboot_main @tboot_main是main.c中的函数名，函数名实际上也是地址，将pc指针直接赋值绝对跳转到main函数的位置

set_svc:
	mrs r0, cpsr
	bic r0, r0,#0x1f
	orr r0, r0,#0xd3
	msr cpsr, r0
	mov pc, lr @调用bl必须使用此指令才能返回之前的地址

@不同处理器的看门狗寄存器地址不同，通过查阅芯片手册获取地址
#define pWTCON 0x53000000
disable_watchdog:
	ldr r0,=pWTCON @把看门狗寄存器地址装载到r0中
	mov r1,#0x0 @将r1赋值0
	str r1,[r0] @最后用存储器访问指令str将r1中的值放到pWTCON地址的存储器中去
	mov pc,lr @调用bl必须使用此指令才能返回之前的地址

disable_interrupt:
	mvn r1, #0x0 @mvn指令类似于mov，但是是先取反再装载，将0x0取反变成0xff，再将0xff装载到r1中
	ldr r0, =0x4a000008
	str r1, [r0] @参考关闭看门狗，将设置值装载到特定地址
	mov pc, lr @调用bl必须使用此指令才能返回之前的地址
	
disable_mmu:
	mcr p15,0,r0,c7,c7,0 @使Icache和Dcache失效，此为固定指令，参考对应芯片手册
	mrc p15,0,r0,c1,c0,0 @读取控制寄存器，此为固定指令，参考对应芯片手册
	bic r0, r0, #0x00000007 @将值写入r0
	mcr p15,0,r0,c1,c0,0 @将r0值写入控制寄存器，此为固定指令，参考对应芯片手册
	mov pc, lr @调用bl必须使用此指令才能返回之前的地址

#define CLKDIVN 0x4c000014
#define MPLLCON 0x4c000008
#define MPLL_405MHZ	((127<<12)|(2<<4)|(1<<0))
clock_init:
@第一步通过HDIVN和PDIVN设置分频系数为1:4:8（参考uboot）
	ldr r0,=CLKDIVN
	mov r1,#0x5
	str r1,[r0]
@第二步如果FCLK≠HCLK，设置CPU为异步模式（此段代码从芯片手册获取）
	mcr p15,0,r0,c1,c0,0
	orr r0,r0,#0xc0000000
	mcr p15,0,r0,c1,c0,0
@第三步配置FCCLK
	ldr r0,=MPLLCON
	ldr r1,=MPLL_405MHZ
	str r1,[r0]
	mov pc, lr @调用bl必须使用此指令才能返回之前的地址

@由于2440的内存控制器有13个，采用一个一个设置，程序太繁琐，所以采用指针指指针的方式，一个指针指向第一个寄存器，另一个指针指向第一个寄存器的赋值，持续赋值直到13个寄存器全都赋值
#define mem_control 0x48000000
init_sdram:
    ldr r0,=mem_control @将r0指向内存控制器寄存器第一个地址
    add r3,r0,#4*13 @r3指向内存控制器寄存器最后一个地址（第13个）
    adrl r1,mem_data @将p1指针指向一个内存控制器初始化值的数组

0: @下面这一段程序是一个循环，
	ldr r2,[r1],#4 @将r1地址中取出数据mem_data放入r2中，然后将指针+4
	str r2,[r0],#4 @将r0地址中取出寄存器地址数据放入r2中，然后将指针+4
	cmp r0,r3 @对比r0和r3
	bne 0b @ne表示不相等，当r0≠r3时，则跳转到0标出，实现循环
	mov pc,lr 

mem_data:
	.long 0x22000000
	.long 0x00000700
	.long 0x00000700
	.long 0x00000700
	.long 0x00000700
	.long 0x00000700
	.long 0x00000700
	.long 0x00018001
	.long 0x00018001
	.long 0x008c04f5
	.long 0x000000b1
	.long 0x00000030
	.long 0x00000030

@2440/6410/210的内存拷贝都是一模一样的，不同的是拷贝的起点终点不同
@2440的起点0x00000000,终点是0x30008000
@6410的起点0x0c000000,终点是0x50008000
@210 的起点0x00020000,
copy_to_ram:
	ldr r0,=0x00000000 @定义拷贝起点的起始地址
	ldr r1,=0x30008000 @定义拷贝终点的起始地址
	add r3,r0,#1024*4 @拷贝数据的大小为4k

copy_loop:
	ldr r2,[r0],#4
	ldr r2,[r1],#4
	cmp r0,r3
	bne copy_loop
	mov pc,lr 

@初始化栈，栈的起始地址都是内存的起始地址+64M，2440的起始地址0x30000000+0x040000000=0x34000000
stack_init:
	ldr sp,=0x34000000 @6410为0x54000000,210为0x24000000
	mov pc,lr 

@bss段的起始地址和结束地址可以在.lds链接器脚本文件查到
clean_bss:
	ldr r0,=bss_start
	ldr r1,=bss_end
	cmp r0,r1 @比较r0和r1，如果r0=r1,则bss段数据都为0，则moveq结束此函数运行；如果r0≠r1，则运行clean_loop
	moveq pc,lr @mov+eq，eq表示equal等于

clean_loop:
    mov r2, #0
    str r2, [r0], #4
    cmp r0, r1
    bne clean_loop
    mov pc,lr

@#define GPBCON 0x56000010
@#define GPBDAT 0x56000014
@light_led:
@	ldr r0, =GPBCON
@	mov r1, #0x15400 @将PB5678设置为输出模式
@	str r1, [r0]
@	
@	ldr r0, =GPBDAT
@	mov r1, #0x0 @将PB56置1
@	str r1, [r0]
@	mov pc, lr @调用bl必须使用此指令才能返回之前的地址

