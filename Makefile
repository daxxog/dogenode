SHELL := /bin/bash


.PHONY: help
help:
	@printf "available targets -->\n\n"
	@cat Makefile | grep ".PHONY" | grep -v ".PHONY: _" | sed 's/.PHONY: //g'


Dockerfile.phase1.built: Dockerfile.phase1
	podman build . \
		-f Dockerfile.phase1 \
		-t localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g'):phase1 \
	;
	echo "$$(date) :: localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g'):phase1" \
		| tee -a Dockerfile.phase1.built \
	;


Dockerfile.phase2.built: Dockerfile.phase1.built Dockerfile.phase2
	podman build . \
		-f Dockerfile.phase2 \
		--build-arg PHASE1_IMG=localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g'):phase1 \
		-t localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g'):phase2 \
	;
	echo "$$(date) :: localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g'):phase2" \
		| tee -a Dockerfile.phase2.built \
	;


Dockerfile.phase3.built: Dockerfile.phase2.built Dockerfile.phase3
	podman build . \
		-f Dockerfile.phase3 \
		--build-arg PHASE2_IMG=localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g'):phase2 \
		-t localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g'):phase3 \
	;
	echo "$$(date) :: localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g'):phase3" \
		| tee -a Dockerfile.phase3.built \
	;


container-built.txt: Dockerfile.phase1.built Dockerfile.phase2.built Dockerfile.phase3.built
	cat \
		<(echo Dockerfile.phase1.built) Dockerfile.phase1.built \
		<(echo Dockerfile.phase2.built) Dockerfile.phase2.built \
		<(echo Dockerfile.phase3.built) Dockerfile.phase3.built \
	> container-built.txt
	podman tag \
		localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g'):phase3 \
		localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g') \
	;


.PHONY: debug
debug: container-built.txt
	podman run \
		-i \
		-t \
		--entrypoint /bin/bash \
		localhost/$$(git remote get-url origin | awk '{split($$0,a,"/");print a[2]}' | sed 's/\.git//g') \
	;


env:
	python3 -m venv env
	if [ -f requirements.txt ]; then \
		bash -c 'source env/bin/activate && set -x && python3 -m pip install -r requirements.txt'; \
	fi


requirements.in:
	echo "pip-tools" > requirements.in
	echo "zest.releaser" >> requirements.in
	if git status requirements.in | grep -q requirements.in; then \
		git add requirements.in; \
		git commit -m 'new file:   requirements.in'; \
	fi


requirements.txt: requirements.in env
	bash -c 'source env/bin/activate && set -x && python3 -m pip install -r requirements.in && pip-compile --generate-hashes --resolver=backtracking'
	if git status requirements.txt | grep -q requirements.txt; then \
		git add requirements.txt; \
		git commit -m 'generated:   requirements.txt'; \
	fi


CHANGES.md:
	if [ ! -f CHANGES.md ]; then \
		touch CHANGES.md; \
		git add CHANGES.md; \
		git commit -m 'new file:   CHANGES.md'; \
	fi


VERSION:
	if [ ! -f VERSION ]; then \
		echo "0.0.1" > VERSION; \
		git add VERSION; \
		git commit -m 'new file:   VERSION'; \
	fi


.PHONY: release
release: env CHANGES.md VERSION requirements.txt .github/workflows/docker-push.yml
	bash -c 'source env/bin/activate && set -x && fullrelease'


.github/workflows:
	mkdir -p .github/workflows


.github/workflows/docker-push.yml: .github/workflows
	curl \
		-sL \
		https://raw.githubusercontent.com/daxxog/trufflehog-testing/master/.github/workflows/docker-push.yml \
		> .github/workflows/docker-push.yml \
	;
	if git status .github/workflows/docker-push.yml | grep -q .github/workflows/docker-push.yml; then \
		git add .github/workflows/docker-push.yml; \
		git commit -m 'downloaded:   .github/workflows/docker-push.yml'; \
	fi
