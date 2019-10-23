#define GPBCON (volatile unsigned long*)0x56000010
#define GPBDAT (volatile unsigned long*)0x56000014

int tboot_main()
{
    *(GPBCON)=0x15400;
    *(GPBDAT)=0x0;
    return 0;
}