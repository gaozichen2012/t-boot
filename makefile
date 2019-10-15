all: start.o 
	arm-linux-ld -Ttboot.lds -o tboot.elf $^
	arm-linux-objcopy -O binary tboot.elf tboot.bin
	
%.o : %.S
	arm-linux-gcc -g -c $^
	
%.o : %.c
	arm-linux-gcc -g -c $^
	
.PHONY: clean
clean:
	rm *.o *.elf *.bin


