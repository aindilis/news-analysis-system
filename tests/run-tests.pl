/*  Regression tests for the News Analysis System's demo cases.
    Run:  swipl tests/run-tests.pl CASE_DIR ENGINE_FILE
    Exits 0 when every expectation holds, 1 otherwise.
*/
:- initialization(main, main).

%   expect(Case, Date, Literal, Status)
expect('pentagon-fake-image', '2023-05-22T10:06', explosion_at_pentagon,    accepted).
expect('pentagon-fake-image', '2023-05-22T10:06', image_is_authentic,       accepted).
expect('pentagon-fake-image', '2023-05-22T10:10', markets_reacted_to_claim, accepted).
expect('pentagon-fake-image', '2023-05-22T18:19', explosion_at_pentagon,    refuted).
expect('pentagon-fake-image', '2023-05-22T18:19', image_is_authentic,       refuted).
expect('pentagon-fake-image', '2023-05-22T18:19', markets_reacted_to_claim, accepted). % it happened

expect('yandex-datacentres-bots', '2026-10-08', ukraine_struck_yandex_datacentres,   accepted).
expect('yandex-datacentres-bots', '2026-10-12', yandex_automated_traffic_fell,       accepted).
expect('yandex-datacentres-bots', '2026-10-12', russian_political_bot_activity_fell, defeated).
expect('yandex-datacentres-bots', '2026-10-12', bot_drop_caused_by_strikes,          defeated).
expect('yandex-datacentres-bots', '2026-10-12', pro_trump_bots_specifically_reduced, no_argument).

expect('opera-neutrinos', '2011-09-23', neutrinos_faster_than_light,  contested).
expect('opera-neutrinos', '2011-11-18', neutrinos_faster_than_light,  contested). % same apparatus
expect('opera-neutrinos', '2012-02-23', neutrinos_faster_than_light,  refuted).
expect('opera-neutrinos', '2012-02-23', measurement_fault_identified, accepted).
expect('opera-neutrinos', '2012-06-08', neutrinos_faster_than_light,  refuted).

%   expect_cn(Case, Date, Literal, Target, K): smallest number of sources
%   to set aside to reach Target (change = any other status); 0 = none <= 4.
expect_cn('pentagon-fake-image', '2023-05-22T18:19', explosion_at_pentagon, change, 1).
expect_cn('pentagon-fake-image', '2023-05-22T18:19', explosion_at_pentagon, accepted, 3).
expect_cn('opera-neutrinos', '2012-06-08', neutrinos_faster_than_light, change, 3).
expect_cn('opera-neutrinos', '2012-06-08', neutrinos_faster_than_light, accepted, 4).
expect_cn('yandex-datacentres-bots', '2026-10-12', russian_political_bot_activity_fell, accepted, 1).
expect_cn('yandex-datacentres-bots', '2026-10-12', pro_trump_bots_specifically_reduced, accepted, 0).

%   expect_flip(Case, Date, Item, NewPrio, Literal, NewStatus)
expect_flip('opera-neutrinos', '2011-09-23', rule(r_theory), 2, neutrinos_faster_than_light, accepted).
expect_flip('opera-neutrinos', '2011-09-23', rule(r_theory), 4, neutrinos_faster_than_light, refuted).
expect_flip('opera-neutrinos', '2012-06-08', rule(r_theory), 2, neutrinos_faster_than_light, refuted).

main([CaseDir, Engine]) :-
    use_module(Engine),
    findall(C, ( expect(C, _, _, _) ; expect_cn(C, _, _, _, _) ; expect_flip(C, _, _, _, _, _) ), Cs0),
    sort(Cs0, Cs),
    foldl(run_case(CaseDir), Cs, 0-0, N-NF),
    format("~d tests, ~d failures~n", [N, NF]),
    (   NF =:= 0 -> halt(0) ; halt(1) ).

run_case(Dir, C, N0-F0, N-F) :-
    atomic_list_concat([Dir, '/', C, '.pl'], File),
    colloquy:load_case(File),
    findall(ok-(D/L/S/Got),
            ( expect(C, D, L, S), colloquy:literal_status(D, L, Got) ),
            Rs),
    findall(ok-(D/cn(L,T)/K/Got),
            ( expect_cn(C, D, L, T, K), cn_of(D, L, T, Got) ), Rs2),
    findall(ok-(D/flip(I,P,L)/S/Got),
            ( expect_flip(C, D, I, P, L, S),
              colloquy:with_scenario([], [I-P], colloquy:literal_status(D, L, Got)) ), Rs3),
    append([Rs, Rs2, Rs3], All),
    include([_-(_/_/S/G)]>>(S \== G), All, Fails),
    forall(member(_-(D/L/S/G), Fails),
           format("FAIL ~w ~w ~w: expected ~w, got ~w~n", [C, D, L, S, G])),
    length(All, K), length(Fails, KF),
    N is N0 + K, F is F0 + KF.

cn_of(D, L, T, K) :-
    colloquy:literal_status(D, L, S0),
    (   T == change -> Target = change(S0) ; Target = reach(T) ),
    colloquy:origins_at(D, Os),
    colloquy:conspiracy_number(D, L, Os, 4, Target, R),
    (   R = found(K, _, _) -> true ; K = 0 ).
