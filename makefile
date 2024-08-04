ASM = nasm
ASM_FLAGS = -gdwarf -f elf64

LD = gcc
LD_FLAGS = -no-pie -lraylib

$(shell mkdir -p bin obj)

.PHONY: all
all: bin/ttt

obj/ttt.o: ttt.asm
	$(ASM) $(ASM_FLAGS) -o $@ $<

bin/ttt: obj/ttt.o
	$(LD) $(LD_FLAGS) -o $@ $<

.PHONY: clean
clean:
	rm -rf bin obj
