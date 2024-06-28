all:

CURL = curl
GIT = git

updatenightly: local/bin/pmbp.pl build
	$(CURL) -s -S -L -f https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	$(GIT) add modules t_deps/modules
	perl local/bin/pmbp.pl --update-pmbp-pl
	perl local/bin/pmbp.pl --update
	$(GIT) add config
	$(CURL) -sSLf https://raw.githubusercontent.com/wakaba/ciconfig/master/ciconfig | RUN_GIT=1 REMOVE_UNUSED=1 perl

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

PMBP_OPTIONS=

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(CURL) -s -S -L -f https://raw.githubusercontent.com/wakaba/perl-setupenv/master/bin/pmbp.pl > $@
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update-pmbp-pl
pmbp-update: git-submodules pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) --install \
            --create-perl-command-shortcut @perl \
            --create-perl-command-shortcut @prove \
	    --create-perl-command-shortcut ddsd=perl\ bin/ddsd.pl
	chmod ugo+x ddsd

build: bin/booter bin/booter.staging

bin/booter: bin/booter.src
	sed s/@@BRANCH@@/master/g $< > local/booter.master
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) \
	    --create-bootstrap-script "local/booter.master $@"
	chmod ugo+x $@
bin/booter.staging: bin/booter.src
	sed s/@@BRANCH@@/staging/g $< > local/booter.staging
	perl local/bin/pmbp.pl $(PMBP_OPTIONS) \
	    --create-bootstrap-script "local/booter.staging $@"
	chmod ugo+x $@

test: test-deps test-main

test-deps: local/bin/tesica

local/bin/tesica:
	mkdir -p local/bin
	$(CURL) -f https://raw.githubusercontent.com/pawjy/tesica/master/tesica > $@
	chmod ugo+x $@

test-main: local/bin/tesica
	local/bin/tesica 

## License: Public Domain.
