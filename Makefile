SHELL := /bin/bash


.PHONY: help
help:
	@printf "available targets -->\n\n"
	@cat Makefile | grep ".PHONY" | grep -v ".PHONY: _" | sed 's/.PHONY: //g'


container-built.txt: Dockerfile
	podman build . \
		-t localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g') \
	;
	echo "$$(date) :: localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g')" \
		| tee -a container-built.txt \
	;


.PHONY: debug
debug: container-built.txt
	podman run \
		-i \
		-t \
		--entrypoint /bin/bash \
		localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g') \
	;
