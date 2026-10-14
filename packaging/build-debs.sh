#!/bin/sh
# Build the three binary packages with dpkg-deb alone (no debhelper needed).
# Usage: sh packaging/build-debs.sh VERSION STAGEDIR OUTDIR
set -eu
VER="$1"; STAGE="$2"; OUT="$3"
MAINT="Andrew Dougherty <552578+aindilis@users.noreply.github.com>"
HOME_URL="https://github.com/aindilis/news-analysis-system"

stage_doc() {   # $1 = package dir, $2 = package name
    d="$1/usr/share/doc/$2"
    install -d "$d"
    install -m 0644 debian/copyright "$d/copyright"
    gzip -9n -c debian/changelog > "$d/changelog.gz"
    chmod 0644 "$d/changelog.gz"
}

finish() {      # $1 = package dir, $2 = package name, $3 = control body
    pkg="$1"; name="$2"
    size=$(du -sk --exclude=DEBIAN "$pkg" | cut -f1)
    install -d "$pkg/DEBIAN"
    {
        echo "Package: $name"
        echo "Version: $VER"
        echo "Architecture: all"
        echo "Maintainer: $MAINT"
        echo "Installed-Size: $size"
        echo "Section: science"
        echo "Priority: optional"
        echo "Homepage: $HOME_URL"
        printf '%s\n' "$3"
    } > "$pkg/DEBIAN/control"
    ( cd "$pkg" && find . -type f ! -path './DEBIAN/*' -printf '%P\0' \
        | sort -z | xargs -0 md5sum > DEBIAN/md5sums )
    chmod 0644 "$pkg/DEBIAN/control" "$pkg/DEBIAN/md5sums"
    find "$pkg" -type d -exec chmod 0755 {} +
    dpkg-deb --root-owner-group -Zxz --build "$pkg" "$OUT/${name}_${VER}_all.deb"
}

# colloquy
P="$STAGE/colloquy"
install -D -m 0644 colloquy/prolog/colloquy.pl "$P/usr/share/colloquy/colloquy.pl"
install -D -m 0755 colloquy/bin/colloquy       "$P/usr/bin/colloquy"
install -d "$P/usr/share/man/man1"
gzip -9n -c colloquy/man/colloquy.1 > "$P/usr/share/man/man1/colloquy.1.gz"
chmod 0644 "$P/usr/share/man/man1/colloquy.1.gz"
stage_doc "$P" colloquy
finish "$P" colloquy "Depends: swi-prolog-core (>= 9.0) | swi-prolog-nox (>= 9.0)
Description: ASPIC+ argumentation engine over dated, sourced evidence
 Colloquy builds every argument a case allows from attackable premises,
 axioms, and strict and defeasible rules; computes undermining, rebutting
 and undercutting defeats with last-link preferences; and labels the
 arguments under grounded semantics.
 .
 Premises carry the date they became public, so any past date can be
 replayed. It explains each verdict, lists the evidence and critical
 questions that would change it, and exports the graph as AIF JSON."

# news-analysis-cases
P="$STAGE/news-analysis-cases"
install -d "$P/usr/share/news-analysis-system/cases"
install -m 0644 cases/*.pl "$P/usr/share/news-analysis-system/cases/"
install -D -m 0644 tests/run-tests.pl "$P/usr/share/news-analysis-system/tests/run-tests.pl"
stage_doc "$P" news-analysis-cases
finish "$P" news-analysis-cases "Depends: colloquy (>= $VER)
Description: worked news cases for the News Analysis System
 Sourced, dated encodings of public news stories for the Colloquy
 argumentation engine: a fake image of an explosion at the Pentagon
 (2023), refuted within hours; the OPERA faster-than-light neutrino
 result (2011-12), contested and then refuted by its own authors; and
 the October 2026 claim that strikes on Yandex data centres cut bot
 activity, which the record does not establish."

# news-analysis-system (metapackage + demo)
P="$STAGE/news-analysis-system"
install -D -m 0755 app/bin/news-analysis-demo "$P/usr/bin/news-analysis-demo"
install -d "$P/usr/share/info"
gzip -9n -c doc/news-analysis.info > "$P/usr/share/info/news-analysis.info.gz"
chmod 0644 "$P/usr/share/info/news-analysis.info.gz"
stage_doc "$P" news-analysis-system
install -m 0644 doc/paper/news-analysis-system.pdf "$P/usr/share/doc/news-analysis-system/"
install -D -m 0644 doc/examples/bridge-rumour.pl "$P/usr/share/doc/news-analysis-system/examples/bridge-rumour.pl"
finish "$P" news-analysis-system "Depends: colloquy (>= $VER), news-analysis-cases (>= $VER)
Description: News Analysis System (metapackage and demo)
 Installs the Colloquy engine and the worked cases, plus
 news-analysis-demo, which replays each case and shows why its
 conclusions changed as evidence became public. Includes a tutorial
 (info news-analysis) and the proposal paper."
