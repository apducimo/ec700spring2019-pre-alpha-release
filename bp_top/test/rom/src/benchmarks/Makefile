RISCV_GCC=riscv64-unknown-elf-gcc -fPIC -march=rv64i -mabi=lp64 -mcmodel=medany -static -nostdlib -nostartfiles -T test.ld
COMMON_FILES = start.S -I../env util.h 

all: median.elf multiply.elf towers.elf vvadd.elf komodo_test.elf
#all: median.elf multiply.elf towers.elf vvadd.elf binary_search.elf binary_search_hanoi.elf binary_sum_count.elf factorial.elf factorial_fibonacci.elf fibonacci.elf fibonacci_gcd.elf  gcd.elf hanoi.elf

median.elf: 
	$(RISCV_GCC) -o median.elf median.c median.h median_dataset.h median_main.c $(COMMON_FILES)

multiply.elf:
	$(RISCV_GCC) -o multiply.elf multiply.c multiply.h multiply_dataset.h multiply_main.c $(COMMON_FILES)

towers.elf:
	$(RISCV_GCC) -o towers.elf towers_main.c $(COMMON_FILES)

vvadd.elf:
	$(RISCV_GCC) -o vvadd.elf vvadd_main.c vvadd_dataset.h $(COMMON_FILES)

binary_search.elf:
	$(RISCV_GCC) -o binary_search.c $(COMMON_FILES)

binary_search_hanoi.elf:
	$(RISCV_GCC) -o binary_search_hanoi.c $(COMMON_FILES)

binary_sum_count.elf:
	$(RISCV_GCC) -o binary_sum_count.c $(COMMON_FILES)

factorial.elf:
	$(RISCV_GCC) -o factorial.c $(COMMON_FILES)

factorial_fibonacci.elf:
	$(RISCV_GCC) -o factorial_fibonacci.c $(COMMON_FILES)

fibonacci.elf:
	$(RISCV_GCC) -o fibonacci.c $(COMMON_FILES)

fibonacci_gcd.elf:
	$(RISCV_GCC) -o fibonacci_gcd.c $(COMMON_FILES)

gcd.elf:
	$(RISCV_GCC) -o gcd.c $(COMMON_FILES)

hanoi.elf:
	$(RISCV_GCC) -o hanoi.c $(COMMON_FILES)

komodo_test.elf:
	$(RISCV_GCC) -o komodo_test.elf komodo.c komodo_test.c $(COMMON_FILES)

clean:
	rm median.elf multiply.elf towers.elf vvadd.elf
