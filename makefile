test: test.o
	ld -o test test.o
test.o: test.s
	as -g test.s -o test.o

clean:
	rm -f *.o
	rm -f test
