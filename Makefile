all:

CURL = curl
GIT = git
PERL = ./perl

updatenightly: local/bin/pmbp.pl build
	$(CURL) -s -S -L -f https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	$(GIT) add modules t_deps/modules
	perl local/bin/pmbp.pl --update-pmbp-pl
	perl local/bin/pmbp.pl --update
	$(GIT) add config
	$(CURL) -sSLf https://raw.githubusercontent.com/wakaba/ciconfig/master/ciconfig | RUN_GIT=1 REMOVE_UNUSED=1 perl

deps: git-submodules pmbp-install

deps-booter: git-submodules-min pmbp-install

git-submodules:
	$(GIT) submodule update --init
git-submodules-min:
	$(GIT) submodule update --init --depth 1 modules/ || \
	GIT_CONFIG_GLOBAL=/tmp/pmbpbootergitconfig $(GIT) submodule update --init --depth 1 modules/

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

build: bin/booter bin/booter.staging lib/_CharClasses.pm

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

## <https://wiki.suikawiki.org/n/%E8%AD%98%E5%88%A5%E5%AD%90%E6%96%87%E5%AD%97>
lib/_CharClasses.pm:
	echo 'package _CharClasses;use Carp;' > $@;
	echo 'sub import{my $$from_class = shift;my ($$to_class, $$file, $$line) = caller;no strict 'refs';for (@_ ? @_ : qw(InNotNameStartChar InNotNameEndChar InNotNameChar)) {my $$code = $$from_class->can ($$_) or croak qq{"$$_" is not exported by the $$from_class module at $$file line $$line};*{$$to_class . '::' . $$_} = $$code;}}' >> $@
	$(CURL) -f -l https://chars.suikawiki.org/set/perlrevars?item=InNotNameStartChar=%24unicode:Mark >> $@
	$(CURL) -f -l https://chars.suikawiki.org/set/perlrevars?item=InNotNameEndChar=%5B%5Cu%7B035C%7D-%5Cu%7B0362%7D%5Cu%7B1DFC%7D%5D >> $@
	$(CURL) -f -l https://chars.suikawiki.org/set/perlrevars?item=InNotNameChar=%24unicode%3ACs+%7C+%24unicode%3ANoncharacter_Code_Point+%7C+%24unicode%3Aprivate-use+%7C+%24unicode%3ACc+%7C+%24unicode%3AFormat+%7C+%24unicode%3AWhite_Space+%7C+%5B%5Cu034F%5D+-%24unicode:Prepended_Concatenation_Mark >> $@
	echo '1;' >> $@
	echo '## License: Public Domain.' >> $@
	$(PERL) -c $@

test: test-deps test-main

test-deps: local/bin/tesica

local/bin/tesica:
	mkdir -p local/bin
	$(CURL) -f https://raw.githubusercontent.com/pawjy/tesica/master/tesica > $@
	chmod ugo+x $@

test-main: local/bin/tesica
	local/bin/tesica 

## License: Public Domain.
