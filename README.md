# News Analysis System

The News Analysis System keeps a live argument map of a news story: which
claims are accepted now, which are defeated, what each verdict rests on, and
what evidence would change it. Its core is **Colloquy**, a small ASPIC+
argumentation engine in SWI-Prolog. Every premise carries the date (or time)
it became public, so any past moment can be replayed. Its purpose is
countering disinformation with a method anyone can check.

**Scope.** The system analyses *claims* from public sources: what was said,
by whom, when, and what it rests on. It does not collect data about private
individuals or build profiles of people, and cases should cite only public
statements and public records.

## Review status

The code, case encodings, tutorial and paper in this repository were drafted
by Claude (Anthropic) at Andrew Dougherty's direction, on 14 October 2026.
Claude checked each case fact against the cited source and each status
against the running engine and its tests. **Andrew has looked over the paper
and tutorial but has not yet verified their content.** This note will be
updated as he does.

## What it does

Version 0.3.0 ships the engine and three demo cases, chosen to end three
different ways:

| Case | What it shows |
| --- | --- |
| `pentagon-fake-image` | A viral AI-generated image (22 May 2023) is accepted on first sight, then refuted the same day by officials and image analysis. The market dip stays accepted: it happened, even though the event did not. |
| `opera-neutrinos` | A faster-than-light measurement (2011) is contested against well-tested theory, not dismissed; a re-test on the same apparatus changes nothing; the experimenters' own fault report refutes it. |
| `yandex-datacentres-bots` | Live (October 2026). The strikes are established; the drop in automated traffic is real; the claim that political bot activity fell is not established; the "pro-Trump bots" version has no source at all. |

For every conclusion it can also report a **conspiracy number**: the smallest
number of sources that would have to be wrong for the verdict to change. A
claim that one interested party is lying has a low number; a claim that needs
many independent sources to be coordinated has a high one. See
`colloquy robustness`.

## Documentation

- **Tutorial:** `info news-analysis` after installing (or `C-h i` in Emacs).
  Source: `doc/news-analysis.texi`.
- **Paper:** `/usr/share/doc/news-analysis-system/news-analysis-system.pdf`.
  Source: `doc/paper/news-analysis-system.tex`.
- **Worked example:** `doc/examples/bridge-rumour.pl`, built step by step in
  the tutorial.
- **Plans:** `ROADMAP.org`.
- Rebuild the tutorial and paper with `make doc` (needs pdflatex; uses
  makeinfo if installed, otherwise a bundled converter).

## Packages

| Package | Contents |
| --- | --- |
| `colloquy` | the engine (`/usr/share/colloquy/colloquy.pl`), the `colloquy` command, man page |
| `news-analysis-cases` | case files in `/usr/share/news-analysis-system/cases/`, regression tests |
| `news-analysis-system` | metapackage, `news-analysis-demo`, tutorial, paper, example |

## Install from the .deb files (Debian 12/13, Ubuntu 24.04)

1. Put the three `.deb` files in one folder and open a terminal there.
2. Run:

       sudo apt install ./colloquy_0.3.0_all.deb ./news-analysis-cases_0.3.0_all.deb ./news-analysis-system_0.3.0_all.deb

   apt pulls in `swi-prolog-core` automatically. It worked if the output
   includes `Setting up news-analysis-system (0.3.0) ...`.
3. Check the engine: `colloquy version`. Expect `colloquy 0.3.0`.
4. List the cases: `colloquy cases`. Expect `pentagon-fake-image`,
   `opera-neutrinos` and `yandex-datacentres-bots`.
5. Run the demo: `news-analysis-demo | less`.
6. Run the regression tests:

       swipl /usr/share/news-analysis-system/tests/run-tests.pl /usr/share/news-analysis-system/cases /usr/share/colloquy/colloquy.pl

   Expect: `25 tests, 0 failures`.

## Build from this source tree

With debhelper (preferred on a Debian machine):

    sudo apt install build-essential debhelper swi-prolog-core
    dpkg-buildpackage -us -uc -b      # debs appear in the parent folder

Without debhelper (only `dpkg-deb` and `swipl` needed):

    make deb                          # runs all tests, writes dist/*.deb

## Using colloquy

    colloquy timeline   opera-neutrinos
    colloquy status     yandex-datacentres-bots
    colloquy whatif     pentagon-fake-image explosion_at_pentagon --at 2023-05-22T10:06
    colloquy explain    yandex-datacentres-bots russian_political_bot_activity_fell
    colloquy robustness opera-neutrinos --at 2011-09-23
    colloquy aif        opera-neutrinos > graph.json

Statuses: **ACCEPTED** (an argument survives every attack), **REFUTED** (a
contrary is accepted), **DEFEATED** (arguments exist but none survives; not
shown false), **CONTESTED** (undecided), **-** (nothing supports it).

## Writing a case

The tutorial's "A Case From Scratch" and "Case File Reference" chapters cover
this; `doc/examples/bridge-rumour.pl` is the finished example. In short:

    premise(Id, Literal, [date('YYYY-MM-DD'), source(S), url(U), prio(P), note(N)]).
    defeasible(RuleId, [Antecedents], Conclusion, [prio(P), label(Text)]).
    strict(RuleId, [Antecedents], Conclusion).
    critical_question(RuleId, Text).
    contrary(A, B).                      % A and B cannot both hold
    topic(Literal, Description).         % questions the case tracks

Add `origin(O)` to a premise's metadata when several premises come from one
originating source, so the conspiracy number counts them once.

## Engine semantics

ASPIC+ (Modgil and Prakken, 2014), simplified: ordinary premises and axioms;
strict and defeasible rules; undermining, rebutting (restricted to defeasible
conclusions) and undercutting attacks; last-link preferences with the elitist
set ordering; grounded semantics. No assert/retract: each case loads into its
own module, and labellings are memoised by tabling, keyed on the case, the
moment and any what-if scenario.

## License

GPL-3.0-or-later. Case facts are from the public sources cited in each file.
