/*  Case: the OPERA faster-than-light neutrino anomaly (2011-2012).

    Part of the News Analysis System (news-analysis-cases).
    License: GPL-3.0-or-later (encoding); facts are from the cited source.

    What it shows:
      - an extraordinary measurement against a well-tested theory is
        CONTESTED, not accepted and not dismissed;
      - a re-test on the same apparatus adds no independent weight;
      - once the experimenters find a fault in their own timing chain,
        the claim is refuted;
      - later confirmations and the leaders' resignations change nothing:
        the first is redundant, the second is not evidence.
*/

case_title('OPERA faster-than-light neutrino anomaly (2011-2012)').

src(wiki, 'Wikipedia, "2011 OPERA faster-than-light neutrino anomaly" (dates per its body and references)',
          'https://en.wikipedia.org/wiki/2011_OPERA_faster-than-light_neutrino_anomaly').

premise(Id, L, [date(D), source(S), url(U), prio(P), note(N)|X]) :-
    p(Id, L, D, K, P, N, X),
    src(K, S, U).

%   Background knowledge with no date: available at every point in time.
premise(relativity, relativity_extensively_confirmed,
        [source('Special relativity: over a century of confirming experiments'), prio(3)]).

topic(neutrinos_faster_than_light,
      'Do neutrinos travel faster than light?').
topic(measurement_fault_identified,
      'Was a fault found in the OPERA measurement?').

%% --- Evidence -------------------------------------------------------------

p(announce, opera_reports_early_arrival_6_sigma, '2011-09-23', wiki, 3,
  'OPERA reports neutrinos ~60.7 ns early (~6 sigma), offers no interpretation; CERN invites scrutiny',
  []).
p(retest, opera_short_pulse_retest_still_early, '2011-11-18', wiki, 3,
  'Re-test with short beam pulses, same detector: still ~57.8 ns early (6.2 sigma)',
  [precision(approximate)]).
p(fault, opera_finds_loose_fibre_and_clock_fault, '2012-02-23', wiki, 4,
  'OPERA finds a loose GPS fibre link (~73 ns effect) and a fast-running clock',
  [precision(approximate)]).
p(icarus, icarus_measures_speed_consistent_with_light, '2012-03-16', wiki, 4,
  'ICARUS, on the same beam: neutrino speed consistent with light',
  []).
p(resign, opera_leaders_resign, '2012-03-30', wiki, 3,
  'OPERA spokesperson and physics coordinator step down (not evidence either way)',
  []).
p(kyoto, cern_reports_speed_consistent_with_light, '2012-06-08', wiki, 4,
  'Neutrino 2012, Kyoto: speed consistent with light; original result due to equipment faults',
  []).

%% --- Rules ----------------------------------------------------------------

defeasible(r_measure, [opera_reports_early_arrival_6_sigma], neutrinos_faster_than_light,
           [prio(3), scheme(measurement),
            label('a high-significance measurement')]).
critical_question(r_measure, 'Has an independent experiment replicated it?').
critical_question(r_measure, 'Could a systematic timing error explain it?').
critical_question(r_measure, 'How does it square with other evidence on neutrino speed?').

defeasible(r_retest, [opera_short_pulse_retest_still_early], neutrinos_faster_than_light,
           [prio(3), scheme(measurement),
            label('the same result with a different beam timing')]).
critical_question(r_retest, 'Does the re-test share the original\'s apparatus and timing chain?').

defeasible(r_theory, [relativity_extensively_confirmed], neg(neutrinos_faster_than_light),
           [prio(3), scheme(established_theory),
            label('a theory confirmed in many independent tests predicts no particle exceeds c')]).

defeasible(r_fault, [opera_finds_loose_fibre_and_clock_fault], undercut(r_measure),
           [prio(5), scheme(identified_error),
            label('the experimenters found a fault large enough to produce the effect')]).
defeasible(r_fault_retest, [opera_finds_loose_fibre_and_clock_fault], undercut(r_retest),
           [prio(5), scheme(identified_error),
            label('the fault sits in the timing chain both measurements used')]).
defeasible(r_fault_found, [opera_finds_loose_fibre_and_clock_fault], measurement_fault_identified,
           [prio(4), scheme(testimony_against_interest),
            label('the experimenters report a fault in their own apparatus')]).

defeasible(r_icarus, [icarus_measures_speed_consistent_with_light],
           neg(neutrinos_faster_than_light),
           [prio(4), scheme(independent_replication),
            label('an independent detector on the same beam')]).

defeasible(r_kyoto, [cern_reports_speed_consistent_with_light],
           neg(neutrinos_faster_than_light),
           [prio(4), scheme(corrected_measurement),
            label('corrected measurements from several experiments')]).
