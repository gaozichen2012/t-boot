#define GPBCON (volatile unsigned long*)0x56000010
#define GPBDAT (volatile unsigned long*)0x56000014

int tboot_main()
{
    light_led();
    return 0;
}