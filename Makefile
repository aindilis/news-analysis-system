# News Analysis System -- build, test, install, package.
VERSION   := 0.3.0

PREFIX    ?= /usr
DESTDIR   ?=
SWIPL     ?= swipl
DEBDIR    := build/deb
OUT       := dist

.PHONY: all test install deb doc clean

all: test

test:
	$(SWIPL) tests/run-tests.pl cases colloquy/prolog/colloquy.pl
	for c in cases/*.pl; do COLLOQUY_LIB=$(CURDIR)/colloquy/prolog/colloquy.pl \
	  sh colloquy/bin/colloquy timeline $$c > /dev/null || exit 1; done

install:
	install -D -m 0644 colloquy/prolog/colloquy.pl $(DESTDIR)$(PREFIX)/share/colloquy/colloquy.pl
	install -D -m 0755 colloquy/bin/colloquy      $(DESTDIR)$(PREFIX)/bin/colloquy
	install -D -m 0644 colloquy/man/colloquy.1    $(DESTDIR)$(PREFIX)/share/man/man1/colloquy.1
	install -d $(DESTDIR)$(PREFIX)/share/news-analysis-system/cases
	install -m 0644 cases/*.pl $(DESTDIR)$(PREFIX)/share/news-analysis-system/cases/
	install -D -m 0644 tests/run-tests.pl $(DESTDIR)$(PREFIX)/share/news-analysis-system/tests/run-tests.pl
	install -D -m 0755 app/bin/news-analysis-demo $(DESTDIR)$(PREFIX)/bin/news-analysis-demo

# Tutorial (Info) and paper (PDF). Uses makeinfo when present,
# otherwise the bundled minimal converter.
doc:
	if command -v makeinfo >/dev/null; then makeinfo -o doc/news-analysis.info doc/news-analysis.texi; \
	else python3 doc/texi2info.py doc/news-analysis.texi doc/news-analysis.info; fi
	cd doc/paper && pdflatex -interaction=nonstopmode news-analysis-system.tex >/dev/null && \
	  pdflatex -interaction=nonstopmode news-analysis-system.tex >/dev/null && \
	  rm -f *.aux *.log *.out

# Binary .debs without debhelper (dpkg-deb only). On a Debian box with
# debhelper, prefer:  dpkg-buildpackage -us -uc -b
deb: test
	rm -rf $(DEBDIR) && mkdir -p $(OUT)
	sh packaging/build-debs.sh $(VERSION) $(DEBDIR) $(OUT)

clean:
	rm -rf build $(OUT)
