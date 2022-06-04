dist/libtil_tcl.so: til source/app.d dist/bindings.o
	ldc2 --shared \
		source/app.d dist/bindings.o \
		-I=til/source \
		-link-defaultlib-shared \
		-L-L${PWD}/dist -L-L${PWD}/til/dist -L-ltil -L-ltcl8.6 \
		--O2 -of=dist/libtil_tcl.so

dist/bindings.o: source/bindings.c
	-mkdir dist
	gcc -c \
		-fPIC \
		source/bindings.c \
		-o dist/bindings.o

test:
	til/til.release test.til

til:
	git clone https://github.com/til-lang/til.git til

clean:
	-rm dist/*.so
	-rm dist/*.o
