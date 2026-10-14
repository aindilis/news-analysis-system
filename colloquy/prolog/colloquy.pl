/*  Colloquy -- a small ASPIC+ argumentation engine with dated evidence.

    Part of the News Analysis System.
    Copyright (C) 2026 Andrew Dougherty
    License: GPL-3.0-or-later

    No assert/retract: each case is loaded into its own module, the
    current case is a global variable, and argument labellings are
    memoised with tabling (cleared when a case is loaded).

    Model (ASPIC+, Modgil & Prakken 2014, simplified):
      - ordinary premises (attackable), axioms (not attackable)
      - strict and defeasible rules
      - attacks: undermine (on an ordinary premise), rebut (on a
        defeasible conclusion), undercut (on a defeasible rule's
        applicability, via the literal undercut(RuleId))
      - preferences: last-link principle with the elitist set ordering,
        over integer priorities (higher = stronger)
      - acceptability: grounded semantics (most sceptical)
    Every premise may carry date('YYYY-MM-DD') or date('YYYY-MM-DDTHH:MM');
    querying "at" a date uses only premises public on or before it,
    which gives replay. Priorities are an ordinal ranking of kinds of
    evidence, not certainty values.
*/

:- module(colloquy,
          [ load_case/1,            % +File
            arguments_at/2,         % +Date, -Args
            label_at/4,             % +Date, -Args, -In, -Out
            literal_status/3,       % +Date, +Literal, -Status
            conc/2,                 % +Arg, -Literal
            case_dates/1,           % -Dates
            with_scenario/3,        % +Excluded, +Overrides, :Goal
            conspiracy_number/6,    % +Date, +Lit, +Origins, +Max, +Target, -Res
            colloquy_main/1         % +Argv
          ]).

:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(pairs)).

colloquy_version('0.3.0').

%% -------------------------------------------------------------------
%% Case loading

%!  load_case(+File) is det.
%   Loads a case file into its own module (case:<basename>) and makes it
%   the current case. Loading several cases in one process is fine.

load_case(File) :-
    (   exists_file(File) -> true
    ;   format(user_error, "colloquy: no such case file: ~w~n", [File]),
        halt(2)
    ),
    absolute_file_name(File, Abs),
    file_base_name(Abs, Base),
    file_name_extension(Stem, _, Base),
    atom_concat(case_, Stem, M),
    style_check(-discontiguous),
    load_files(M:Abs, [silent(true)]),
    style_check(+discontiguous),
    nb_setval(colloquy_case, M),
    abolish_all_tables.

%   c(+Goal): call a predicate of the current case; undefined ones fail.
c(Goal) :-
    nb_current(colloquy_case, M),
    catch(M:Goal, error(existence_error(procedure, _), _), fail).

%% -------------------------------------------------------------------
%% Language

complement(neg(X), X) :- !.
complement(X, neg(X)).

conflicts(A, B) :- complement(A, B).
conflicts(A, B) :- c(contrary(A, B)).
conflicts(A, B) :- c(contrary(B, A)).

rule_def(R, Ants, Cons, strict)     :- c(strict(R, Ants, Cons)).
rule_def(R, Ants, Cons, defeasible) :- c(defeasible(R, Ants, Cons, _)).

meta_of_premise(Id, M) :- c(premise(Id, _, M)).

%   A scenario changes the theory without changing the case file:
%   s(Excluded, Overrides) sets aside the listed premise ids, and gives
%   new priorities as premise(Id)-P or rule(Id)-P pairs. It is held in
%   a global variable and is part of every tabled key.
scenario(S) :-
    (   nb_current(colloquy_scenario, S0) -> S = S0 ; S = s([], []) ).

with_scenario(Excl, Over, Goal) :-
    scenario(Old),
    msort(Excl, E), msort(Over, O),
    setup_call_cleanup(nb_setval(colloquy_scenario, s(E, O)),
                       Goal,
                       nb_setval(colloquy_scenario, Old)).

base_prio_premise(Id, P) :-
    (   meta_of_premise(Id, M), memberchk(prio(P0), M) -> P = P0 ; P = 1 ).
base_prio_rule(R, P) :-
    (   c(defeasible(R, _, _, M)), memberchk(prio(P0), M) -> P = P0 ; P = 1 ).

prio_premise(Id, P) :-
    scenario(s(_, O)),
    (   memberchk(premise(Id)-P0, O) -> P = P0 ; base_prio_premise(Id, P) ).
prio_rule(R, P) :-
    scenario(s(_, O)),
    (   memberchk(rule(R)-P0, O) -> P = P0 ; base_prio_rule(R, P) ).

available(M, Date) :-
    (   memberchk(date(D), M) -> D @=< Date ; true ).

%% -------------------------------------------------------------------
%% Arguments
%   prem(Id) | ax(Id) | rule(RuleId, SubArgs)

conc(prem(Id), L)    :- c(premise(Id, L, _)).
conc(ax(Id), L)      :- c(axiom(Id, L, _)).
conc(rule(R, _), L)  :- rule_def(R, _, L, _).

sub_arg(A, A).
sub_arg(rule(_, Subs), X) :- member(S, Subs), sub_arg(S, X).

%!  arguments_at(+Date, -Args) is det.

arguments_at(Date, Args) :-
    scenario(s(Excl, _)),
    findall(prem(Id), ( c(premise(Id, _, M)), available(M, Date),
                        \+ memberchk(Id, Excl) ), Ps),
    findall(ax(Id),   ( c(axiom(Id, _, M)),   available(M, Date) ), Xs),
    append(Ps, Xs, Base0),
    sort(Base0, Base),
    closure(Base, Args).

closure(As0, As) :-
    findall(rule(R, Subs),
            ( rule_def(R, Ants, Cons, _),
              subs_for(Ants, As0, Subs),
              \+ circular(Cons, Subs),
              \+ memberchk(rule(R, Subs), As0)
            ),
            New0),
    sort(New0, New),
    (   New == []
    ->  As = As0
    ;   append(As0, New, As1),
        closure(As1, As)
    ).

subs_for([], _, []).
subs_for([L|Ls], As, [A|Sub]) :-
    member(A, As),
    conc(A, L),
    subs_for(Ls, As, Sub).

circular(C, Subs) :-
    member(S, Subs),
    sub_arg(S, S1),
    conc(S1, C), !.

%% -------------------------------------------------------------------
%% Preferences: last link, elitist

last_def_rules(rule(R, Subs), Ps) :- !,
    (   rule_def(R, _, _, defeasible)
    ->  prio_rule(R, P), Ps = [P]
    ;   maplist(last_def_rules, Subs, Pss), append(Pss, Ps)
    ).
last_def_rules(_, []).

ordinary_prios(A, Ps) :-
    findall(P, ( sub_arg(A, prem(Id)), prio_premise(Id, P) ), Ps).

%   set_weaker(S1, S2): S1 is strictly weaker than S2 (elitist).
set_weaker([], _) :- !, fail.
set_weaker(_, []) :- !.
set_weaker(S1, S2) :-
    min_list(S1, M1), min_list(S2, M2), M1 < M2.

weaker(A, B) :-
    last_def_rules(A, LA), last_def_rules(B, LB),
    (   ( LA \== [] ; LB \== [] )
    ->  set_weaker(LA, LB)
    ;   ordinary_prios(A, PA), ordinary_prios(B, PB),
        set_weaker(PA, PB)
    ).

%% -------------------------------------------------------------------
%% Attack and defeat

attack_on(CA, prem(Id), undermine) :-
    c(premise(Id, L, _)), conflicts(CA, L).
attack_on(CA, rule(R, _), rebut) :-
    rule_def(R, _, C, defeasible), conflicts(CA, C).
attack_on(undercut(R), rule(R, _), undercut) :-
    rule_def(R, _, _, defeasible).

%!  defeat(+A, ?B, -Target, -Kind)
defeat(A, B, B1, Kind) :-
    conc(A, CA),
    sub_arg(B, B1),
    attack_on(CA, B1, Kind),
    (   Kind == undercut -> true ; \+ weaker(A, B1) ).

defeat_pairs(Args, Pairs) :-
    findall(A-B,
            ( member(A, Args), member(B, Args), once(defeat(A, B, _, _)) ),
            Pairs0),
    sort(Pairs0, Pairs).

%% -------------------------------------------------------------------
%% Grounded labelling

%!  label_at(+Date, -Args, -In, -Out) is det.
%   Memoised by tabling, keyed on the current case and the date.

label_at(Date, Args, In, Out) :-
    nb_getval(colloquy_case, M),
    scenario(S),
    label_case_at(M, S, Date, Args, In, Out).

:- table label_case_at/6.
label_case_at(_Case, _Scenario, Date, Args, In, Out) :-
    arguments_at(Date, Args),
    defeat_pairs(Args, Pairs),
    grounded(Args, Pairs, [], [], In, Out).

grounded(Args, Pairs, In0, Out0, In, Out) :-
    findall(A, ( member(A, Args), \+ memberchk(A, In0),
                 forall(member(X-A, Pairs), memberchk(X, Out0)) ), NewIn),
    findall(A, ( member(A, Args), \+ memberchk(A, Out0),
                 member(X-A, Pairs), memberchk(X, In0) ), NewOut0),
    sort(NewOut0, NewOut),
    (   NewIn == [], NewOut == []
    ->  In = In0, Out = Out0
    ;   append(In0, NewIn, In1), append(Out0, NewOut, Out1),
        grounded(Args, Pairs, In1, Out1, In, Out)
    ).

%% -------------------------------------------------------------------
%% Literal status

%!  literal_status(+Date, +Literal, -Status) is det.
%   accepted      some argument for Literal is in the grounded extension
%   refuted       a conflicting literal is accepted
%   contested     an argument exists, neither in nor out (undecided)
%   defeated      arguments exist, but every one is defeated
%   no_argument   nothing supports Literal on this date

literal_status(Date, L, Status) :-
    label_at(Date, Args, In, Out),
    findall(A, ( member(A, Args), conc(A, L) ), ForL),
    (   member(A, ForL), memberchk(A, In)
    ->  Status = accepted
    ;   conflicts(L, L2), member(B, In), conc(B, L2)
    ->  Status = refuted
    ;   ForL == []
    ->  Status = no_argument
    ;   member(A, ForL), \+ memberchk(A, Out)
    ->  Status = contested
    ;   Status = defeated
    ).

status_word(accepted,    'ACCEPTED').
status_word(refuted,     'REFUTED').
status_word(contested,   'CONTESTED').
status_word(defeated,    'DEFEATED').
status_word(no_argument, '-').

case_dates(Dates) :-
    findall(D, ( c(premise(_, _, M)), memberchk(date(D), M) ), D1),
    findall(D, ( c(axiom(_, _, M)),   memberchk(date(D), M) ), D2),
    append(D1, D2, D0),
    sort(D0, Dates).

latest_date(Date) :-
    (   case_dates(Ds), last(Ds, Date) -> true ; Date = '9999-12-31' ).

topics(Ts) :-
    findall(L-Desc, c(topic(L, Desc)), Ts0),
    (   Ts0 == []
    ->  findall(L-'', ( c(defeasible(_, _, L, _)), L \= undercut(_) ), Ts1),
        sort(Ts1, Ts)
    ;   Ts = Ts0
    ).

%% -------------------------------------------------------------------
%% Printing

premise_line(Id, Indent) :-
    c(premise(Id, L, M)),
    tab(Indent),
    format("premise ~w: ~q~n", [Id, L]),
    (   memberchk(date(D), M) -> tab(Indent+4), format("public: ~w~n", [D]) ; true ),
    (   memberchk(source(S), M) -> tab(Indent+4), format("source: ~w~n", [S]) ; true ),
    (   memberchk(url(U), M) -> tab(Indent+4), format("url:    ~w~n", [U]) ; true ).

print_arg(prem(Id), Indent) :- !, premise_line(Id, Indent).
print_arg(ax(Id), Indent) :- !,
    c(axiom(Id, L, _)), tab(Indent), format("axiom ~w: ~q~n", [Id, L]).
print_arg(rule(R, Subs), Indent) :-
    rule_def(R, _, C, Type),
    (   Type == defeasible -> Arrow = '=>' ; Arrow = '->' ),
    (   c(defeasible(R, _, _, M)), memberchk(label(Lbl), M)
    ->  format(atom(Extra), "  (~w)", [Lbl]) ; Extra = '' ),
    tab(Indent), format("~q   by rule ~w ~w~w~n", [C, R, Arrow, Extra]),
    I2 is Indent + 4,
    forall(member(S, Subs), print_arg(S, I2)).

kind_word(undermine, 'undermines premise of').
kind_word(rebut,     'rebuts').
kind_word(undercut,  'undercuts rule of').

%% -------------------------------------------------------------------
%% Commands

cmd_status(Date) :-
    case_title_or_file(T),
    format("~w~nStatus as of ~w (grounded semantics)~n~n", [T, Date]),
    topics(Ts),
    forall(member(L-Desc, Ts),
           ( literal_status(Date, L, S), status_word(S, W),
             format("  ~w~t~13|~q~n", [W, L]),
             (   Desc \== '' -> format("~t~13|~w~n", [Desc]) ; true ) )),
    legend.

cmd_explain(Date, L) :-
    literal_status(Date, L, S), status_word(S, W),
    format("~q is ~w as of ~w~n~n", [L, W, Date]),
    label_at(Date, Args, In, Out),
    findall(A, ( member(A, Args), conc(A, L) ), ForL),
    (   ForL == [] -> format("No argument supports it on this date.~n") ; true ),
    forall(member(A, ForL),
           ( (   memberchk(A, In) -> Lab = 'IN (survives every attack)'
             ;   memberchk(A, Out) -> Lab = 'OUT (defeated)'
             ;   Lab = 'UNDECIDED'
             ),
             format("Argument [~w]:~n", [Lab]),
             print_arg(A, 2),
             forall(( member(B, In), defeat(B, A, T, K) ),
                    ( conc(T, TC), conc(B, BC), kind_word(K, KW),
                      format("  defeated by an argument for ~q, which ~w ~q~n",
                             [BC, KW, TC]),
                      print_arg(B, 6) )),
             nl )),
    (   S == refuted
    ->  forall(( conflicts(L, L2), member(B, In), conc(B, L2) ),
               ( format("Accepted contrary ~q:~n", [L2]), print_arg(B, 2), nl ))
    ;   true
    ).

cmd_timeline :-
    case_title_or_file(T),
    format("~w~nTimeline: status of each question as evidence became public~n", [T]),
    case_dates(Dates),
    topics(Ts),
    findall(L-no_argument, member(L-_, Ts), Start),
    foldl(timeline_step(Ts), Dates, Start, _),
    legend.

legend :-
    format("~nACCEPTED   an argument for it survives every attack~n"),
    format("REFUTED    an argument for a contrary is accepted~n"),
    format("DEFEATED   arguments exist, but none survives (not shown false)~n"),
    format("CONTESTED  undecided: attacks neither win nor lose~n"),
    format("-          nothing supports it yet~n").

timeline_step(Ts, Date, Prev, Now) :-
    findall(L-S, ( member(L-_, Ts), literal_status(Date, L, S) ), Now),
    format("~n~w~n", [Date]),
    forall(( c(premise(Id, _, M)), memberchk(date(Date), M) ),
           ( (   memberchk(note(N), M) -> true ; c(premise(Id, N, _)) ),
             format("  + ~w~n", [N]) )),
    findall(L-S, ( member(L-S, Now), \+ memberchk(L-S, Prev) ), Changed),
    (   Changed == []
    ->  format("    (no change in any conclusion)~n")
    ;   forall(member(L-S, Changed),
               ( status_word(S, W),
                 (   memberchk(L-S0, Prev) -> status_word(S0, W0)
                 ;   W0 = '-' ),
                 format("    ~q: ~w -> ~w~n", [L, W0, W]) ))
    ).

cmd_whatif(Date, L) :-
    literal_status(Date, L, S), status_word(S, W),
    format("~q is ~w as of ~w.~n", [L, W, Date]),
    label_at(Date, Args, In, _),
    (   S == accepted
    ->  findall(A, ( member(A, In), conc(A, L) ), As),
        format("~nIt would change if new evidence defeated any of these:~n", []),
        attack_points(As)
    ;   S == refuted
    ->  findall(B, ( conflicts(L, L2), member(B, In), conc(B, L2) ), Bs),
        format("~nIt is refuted by accepted arguments. It could be restored only~n"),
        format("by defeating these points in them:~n", []),
        attack_points(Bs)
    ;   findall(A, ( member(A, Args), conc(A, L) ), As),
        (   As == []
        ->  format("~nNothing supports it yet. It would need a premise and a rule~n"),
            format("concluding it. Rules in this case that conclude it:~n"),
            (   rule_def(_, _, L, _)
            ->  forall(rule_def(R, Ants, L, _), format("  ~w: from ~q~n", [R, Ants]))
            ;   format("  (none: no source in this case makes this claim)~n")
            )
        ;   format("~nIts arguments are defeated. They are restored if their~n"),
            format("defeaters lose. Those defeaters rest on:~n"),
            findall(B, ( member(A, As), member(B, In), defeat(B, A, _, _) ), Bs0),
            sort(Bs0, Bs),
            attack_points(Bs)
        )
    ).

attack_points(As) :-
    findall(Id, ( member(A, As), sub_arg(A, prem(Id)) ), Ps0), sort(Ps0, Ps),
    findall(R,  ( member(A, As), sub_arg(A, rule(R, _)),
                  rule_def(R, _, _, defeasible) ), Rs0), sort(Rs0, Rs),
    forall(member(Id, Ps),
           ( c(premise(Id, PL, M)),
             (   memberchk(source(Src), M) -> true ; Src = '?' ),
             format("  premise ~w  ~q~n      (undermine: show the record is wrong; recorded by ~w)~n",
                    [Id, PL, Src]) )),
    forall(member(R, Rs),
           ( rule_def(R, _, RC, _),
             format("  rule ~w  => ~q~n      (rebut with stronger evidence for a contrary, or undercut)~n",
                    [R, RC]),
             forall(c(critical_question(R, Q)),
                    format("      critical question: ~w~n", [Q])) )).

%% AIF (Argument Interchange Format) JSON, nodes and edges only.
cmd_aif(Date) :-
    label_at(Date, Args, _, _),
    findall(L, ( member(A, Args), sub_arg(A, X), conc(X, L) ), Ls0), sort(Ls0, Ls),
    findall(R-Subs, member(rule(R, Subs), Args), RAs0), sort(RAs0, RAs),
    defeat_pairs(Args, Pairs),
    format("{~n  \"nodes\": [~n", []),
    length(Ls, NL),
    numlist(1, NL, INums),
    pairs_keys_values(LIs, Ls, INums),
    findall(Line,
            ( member(L-I, LIs), term_string(L, S0), json_escape(S0, S),
              format(string(Line), "    {\"nodeID\": \"i~w\", \"text\": \"~w\", \"type\": \"I\"}", [I, S]) ),
            ILines),
    findall(Line,
            ( nth1(K, RAs, R-_), rule_def(R, _, _, T),
              format(string(Line), "    {\"nodeID\": \"ra~w\", \"text\": \"~w (~w)\", \"type\": \"RA\"}", [K, R, T]) ),
            RALines),
    findall(Line,
            ( nth1(K, Pairs, _),
              format(string(Line), "    {\"nodeID\": \"ca~w\", \"text\": \"Default Conflict\", \"type\": \"CA\"}", [K]) ),
            CALines),
    append([ILines, RALines, CALines], NodeLines),
    atomic_list_concat(NodeLines, ',\n', NodesTxt),
    format("~w~n  ],~n  \"edges\": [~n", [NodesTxt]),
    findall(E,
            ( nth1(K, RAs, R-Subs), member(S1, Subs), conc(S1, L1),
              memberchk(L1-I1, LIs),
              format(string(E), "    {\"fromID\": \"i~w\", \"toID\": \"ra~w\"}", [I1, K]) ),
            E1),
    findall(E,
            ( nth1(K, RAs, R-_), rule_def(R, _, C, _), memberchk(C-I2, LIs),
              format(string(E), "    {\"fromID\": \"ra~w\", \"toID\": \"i~w\"}", [K, I2]) ),
            E2),
    findall(E,
            ( nth1(K, Pairs, A-B), conc(A, LA), memberchk(LA-IA, LIs),
              conc(B, LB), memberchk(LB-IB, LIs),
              member(Dir, [from, to]),
              (   Dir == from
              ->  format(string(E), "    {\"fromID\": \"i~w\", \"toID\": \"ca~w\"}", [IA, K])
              ;   format(string(E), "    {\"fromID\": \"ca~w\", \"toID\": \"i~w\"}", [K, IB])
              ) ),
            E3),
    append([E1, E2, E3], Es0), sort(Es0, Es),
    atomic_list_concat(Es, ',\n', EdgesTxt),
    format("~w~n  ]~n}~n", [EdgesTxt]).

json_escape(S0, S) :-
    split_string(S0, "\"", "", Parts),
    atomic_list_concat(Parts, '\\"', A),
    atom_string(A, S).

case_title_or_file(T) :-
    (   c(case_title(T)) -> true ; T = 'Colloquy case' ).

%% -------------------------------------------------------------------
%% Robustness: conspiracy numbers and priority sensitivity
%
%   A "source" is an origin: by default each premise is its own origin;
%   premises that share origin(O) in their meta count as one source
%   (one outlet repeating another is not independent).
%   The conspiracy number of a literal is the smallest number of sources
%   that would have to be set aside (wrong, mistaken or colluding) for
%   its status to change. For a literal that is not accepted, we also
%   report the smallest number whose removal would make it ACCEPTED.

origin_of(Id, O) :-
    (   meta_of_premise(Id, M), memberchk(origin(O0), M) -> O = O0 ; O = Id ).

origins_at(Date, Os) :-
    findall(O, ( c(premise(Id, _, M)), available(M, Date), origin_of(Id, O) ), Os0),
    sort(Os0, Os).

premises_of_origins(Date, Os, Ids) :-
    findall(Id, ( c(premise(Id, _, M)), available(M, Date),
                  origin_of(Id, O), memberchk(O, Os) ), Ids0),
    sort(Ids0, Ids).

subset_of_size(0, _, []) :- !.
subset_of_size(K, [X|Xs], [X|Ys]) :- K1 is K - 1, subset_of_size(K1, Xs, Ys).
subset_of_size(K, [_|Xs], Ys) :- K > 0, subset_of_size(K, Xs, Ys).

%!  conspiracy_number(+Date, +Lit, +Origins, +Max, +Target, -Result)
%   Target is change(S0) (any status other than S0) or reach(S).
%   Result is found(K, Set, NewStatus) or none(Max).
conspiracy_number(Date, L, Os, Max, Target, Result) :-
    (   between(1, Max, K),
        subset_of_size(K, Os, Set),
        premises_of_origins(Date, Set, Ids),
        with_scenario(Ids, [], literal_status(Date, L, S)),
        target_met(Target, S)
    ->  Result = found(K, Set, S)
    ;   Result = none(Max)
    ).

target_met(change(S0), S) :- S \== S0.
target_met(reach(S), S).

cmd_robustness(Date, Max) :-
    case_title_or_file(T),
    format("~w~nRobustness as of ~w~n", [T, Date]),
    format("(a source is one premise unless premises share an origin/1)~n~n", []),
    origins_at(Date, Os),
    topics(Ts),
    forall(member(L-_, Ts), robustness_line(Date, L, Os, Max)),
    format("~nPriority sensitivity at ~w (each priority moved by one):~n", [Date]),
    sensitivity(Date, Ts).

robustness_line(Date, L, Os, Max) :-
    literal_status(Date, L, S0), status_word(S0, W0),
    format("~q  ~w~n", [L, W0]),
    conspiracy_number(Date, L, Os, Max, change(S0), R1),
    (   R1 = found(K, Set, S1)
    ->  status_word(S1, W1),
        format("  conspiracy number ~d: set aside ~w and it becomes ~w~n",
               [K, Set, W1])
    ;   format("  conspiracy number > ~d: no ~d sources change it~n", [Max, Max])
    ),
    (   S0 \== accepted
    ->  conspiracy_number(Date, L, Os, Max, reach(accepted), R2),
        (   R2 = found(K2, Set2, _)
        ->  format("  to become ACCEPTED: set aside ~d: ~w~n", [K2, Set2])
        ;   format("  to become ACCEPTED: setting sources aside is not enough; it needs new evidence~n")
        )
    ;   true
    ).

sensitivity(Date, Ts) :-
    findall(L-S, ( member(L-_, Ts), literal_status(Date, L, S) ), Base),
    findall(rule(R)-P, ( rule_def(R, _, _, defeasible), base_prio_rule(R, P) ), RItems),
    findall(premise(Id)-P, ( c(premise(Id, _, M)), available(M, Date),
                             base_prio_premise(Id, P) ), PItems),
    append(RItems, PItems, Items),
    findall(Item-P-P1-L-S0-S1,
            ( member(Item-P, Items),
              member(D, [-1, 1]), P1 is P + D, P1 >= 0,
              member(L-S0, Base),
              with_scenario([], [Item-P1], literal_status(Date, L, S1)),
              S1 \== S0 ),
            Flips),
    (   Flips == []
    ->  format("  no verdict changes if any single priority moves by one~n")
    ;   forall(member(Item-P-P1-L-S0-S1, Flips),
               ( Item =.. [_, Id], status_word(S0, W0), status_word(S1, W1),
                 format("  ~w ~d -> ~d: ~q ~w -> ~w~n", [Id, P, P1, L, W0, W1]) ))
    ).

%% -------------------------------------------------------------------
%% CLI

usage :-
    format(user_error,
"Usage: colloquy COMMAND CASE [ARGS] [--at YYYY-MM-DD]

Commands:
  status   CASE              status of each question in the case
  explain  CASE LITERAL      the arguments for LITERAL and what defeats them
  whatif   CASE LITERAL      what evidence would change LITERAL's status
  timeline CASE              replay: status after each dated piece of evidence
  robustness CASE            conspiracy numbers and priority sensitivity
                             (--max N: largest set of sources tried, default 4)
  aif      CASE              export the argument graph as AIF JSON
  cases                      list installed cases
  version

CASE is a file, or the name of an installed case
(e.g. pentagon-fake-image, found in /usr/share/news-analysis-system/cases).
--at limits evidence to what was public on or before that date
(YYYY-MM-DD, or YYYY-MM-DDTHH:MM for events within one day).
", []).

case_dirs(Dirs) :-
    (   getenv('COLLOQUY_CASE_PATH', P) -> atomic_list_concat(D0, ':', P) ; D0 = [] ),
    append(D0, ['/usr/share/news-analysis-system/cases'], Dirs).

resolve_case(Name, File) :-
    (   exists_file(Name)
    ->  File = Name
    ;   case_dirs(Dirs), member(D, Dirs),
        atomic_list_concat([D, '/', Name, '.pl'], F), exists_file(F)
    ->  File = F
    ;   format(user_error, "colloquy: cannot find case '~w'~n", [Name]),
        halt(2)
    ).

take_max(Argv0, Argv, Max) :-
    (   append(Pre, ['--max', M|Post], Argv0)
    ->  append(Pre, Post, Argv), atom_number(M, Max)
    ;   Argv = Argv0, Max = 4
    ).

take_at(Argv0, Argv, Date) :-
    (   append(Pre, ['--at', D|Post], Argv0)
    ->  append(Pre, Post, Argv), Date = D
    ;   Argv = Argv0, Date = none
    ).

parse_literal(Atom, L) :-
    catch(term_to_atom(L, Atom), _,
          ( format(user_error, "colloquy: cannot parse literal ~w~n", [Atom]), halt(2) )).

with_case(Name, Date0, Date) :-
    resolve_case(Name, F),
    load_case(F),
    (   Date0 == none -> latest_date(Date) ; Date = Date0 ).

colloquy_main(Argv00) :-
    take_max(Argv00, Argv0, Max),
    nb_setval(colloquy_max, Max),
    take_at(Argv0, Argv, D0),
    check_date(D0),
    catch(( run(Argv, D0) -> true ; usage, halt(1) ),
          error(io_error(write, _), _),   % e.g. output piped into head
          halt(0)).

check_date(none) :- !.
check_date(D) :-
    (   atom_codes(D, Cs), length(Cs, N), memberchk(N, [10, 16]),
        catch(parse_time(D, iso_8601, _), _, fail)
    ->  true
    ;   format(user_error, "colloquy: --at expects YYYY-MM-DD or YYYY-MM-DDTHH:MM, got ~w~n", [D]),
        halt(2)
    ).

run([status, Case], D0)         :- with_case(Case, D0, D), cmd_status(D).
run([explain, Case, LA], D0)    :- with_case(Case, D0, D), parse_literal(LA, L), cmd_explain(D, L).
run([whatif, Case, LA], D0)     :- with_case(Case, D0, D), parse_literal(LA, L), cmd_whatif(D, L).
run([timeline, Case], _)        :- with_case(Case, none, _), cmd_timeline.
run([aif, Case], D0)            :- with_case(Case, D0, D), cmd_aif(D).
run([robustness, Case], D0)     :- with_case(Case, D0, D),
                                   nb_getval(colloquy_max, Max), cmd_robustness(D, Max).
run([cases], _) :-
    case_dirs(Dirs),
    forall(( member(D, Dirs), exists_directory(D),
             directory_files(D, Fs), member(F, Fs), file_name_extension(B, pl, F) ),
           format("~w~t~24|~w/~w~n", [B, D, F])).
run([version], _) :- colloquy_version(V), format("colloquy ~w~n", [V]).
run([help], _) :- usage.
run([], _) :- usage.
