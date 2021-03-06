include config.mk

all: concurrent generator reify_reflect simple

js: simple_2 concurrent reify_reflect
	$(JSOO_PATH)/compiler/js_of_ocaml --no-runtime $(JSOO_PATH)/runtime/runtime.js simple_2
	$(JSOO_PATH)/compiler/js_of_ocaml --no-runtime $(JSOO_PATH)/runtime/runtime.js concurrent
	$(JSOO_PATH)/compiler/js_of_ocaml --no-runtime $(JSOO_PATH)/runtime/runtime.js reify_reflect

simple: simple_1 simple_2

simple_1: simple_1.ml
	$(OCAMLC) -o simple_1 simple_1.ml

simple_2: simple_2.ml
	$(OCAMLC) -o simple_2 simple_2.ml

concurrent: sched.mli sched.ml concurrent.ml
	$(OCAMLC) -o concurrent sched.mli sched.ml concurrent.ml

generator: generator.ml
	$(OCAMLC) -o generator generator.ml

reify_reflect: reify_reflect.ml
	$(OCAMLC) -o reify_reflect reify_reflect.ml

clean:
	rm -f *.cmi *.cmo *.o concurrent generator *~ a.out state reify_reflect ref \
		transaction aio simple_1 simple_2 *cmx *.js
	make -Cchameneos-redux clean
	make -Casync-io clean
