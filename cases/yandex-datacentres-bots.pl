/*  Case: strikes on Yandex data centres and the claim that bot activity
    fell (October 2026). A live case: expect updates.

    Part of the News Analysis System (news-analysis-cases).
    License: GPL-3.0-or-later (encoding); facts are from the cited reports.

    What it shows:
      - the strikes are well supported, because both sides' statements agree;
      - the measured drop in automated traffic is real but does not show
        that political bots were affected;
      - the claim that political bot activity fell rests on testimony with
        no stated basis and unverified user reports, so it is DEFEATED:
        not established, which is different from shown false;
      - a version of the story naming pro-Trump bots specifically appears
        in no source checked (as of 2026-10-14): it has no argument at all.
*/

case_title('Strikes on Yandex data centres and the bot-activity claim (Oct 2026)').

src(liga1, 'LIGA.net, "\'We always respond in kind.\' Zelenskyy confirmed the strike on a Russian data center", 2026-10-08',
           'https://news.liga.net/en/war/news/we-always-respond-in-kind-zelenskyy-confirmed-the-strike-on-a-russian-data-center').
src(liga2, 'LIGA.net, "Attacks on Yandex data centers have reduced bot activity on social media: Zelenskyy", 2026-10-12',
           'https://news.liga.net/en/amp/politics/news/attacks-on-yandex-data-centers-have-reduced-bot-activity-on-social-media-zelenskyy').
src(eun,   'Euronews, "Did Ukrainian strikes on Yandex data centres cause Russian bot activity to plummet?", 2026-10-12',
           'https://euronews.com/2026/10/12/did-ukrainian-strikes-on-yandex-data-centres-cause-russian-bot-activity-to-plummet').
src(mm,    'Malay Mail, "Hit more Russian data centres, says Lithuanian PM", 2026-10-12',
           'https://malaymail.com/news/world/2026/10/12/hit-more-russian-data-centres-says-lithuanian-pm/238860').

premise(Id, L, [date(D), source(S), url(U), prio(P), note(N)|X]) :-
    p(Id, L, D, K, P, N, X),
    src(K, S, U).

topic(ukraine_struck_yandex_datacentres,
      'Did Ukraine strike Yandex data centres?').
topic(yandex_automated_traffic_fell,
      'Did automated traffic from Yandex\'s network fall?').
topic(russian_political_bot_activity_fell,
      'Did Russian political bot activity fall?').
topic(bot_drop_caused_by_strikes,
      'Did the strikes cause a fall in bot activity?').
topic(pro_trump_bots_specifically_reduced,
      'Were pro-Trump bots specifically taken out? (not stated in any source checked)').

%% --- Evidence -------------------------------------------------------------

p(sasovo, yandex_reports_sasovo_datacentre_stopped, '2026-10-08', liga1, 3,
  'Yandex: its Sasovo (Ryazan region) data centre stopped; infrastructure damaged',
  []).
p(zel_confirm, zelensky_confirms_strike_on_datacentre, '2026-10-08', liga1, 3,
  'Zelensky, asked about the strike: Ukraine "always responds in kind"',
  []).
p(vladimir, yandex_reports_vladimir_datacentre_suspended, '2026-10-11', eun, 3,
  'Third reported strike; Yandex says Vladimir data centre operations suspended',
  []).
p(cloudflare, cloudflare_radar_shows_yandex_automated_traffic_down, '2026-10-12', eun, 4,
  'Cloudflare Radar analysis: automated traffic from Yandex down about 94% on 11 Oct',
  []).
p(caveat, yandex_automated_traffic_includes_crawlers, '2026-10-12', eun, 4,
  'That figure includes legitimate crawlers; it cannot show Kremlin-linked bots were hit',
  []).
p(zel_claim, zelensky_says_bots_reduced, '2026-10-12', liga2, 3,
  'Zelensky at the Warsaw Security Forum: fewer bots, social media less hostile',
  []).
p(zel_nodata, zelensky_cited_no_data, '2026-10-12', liga2, 3,
  'No measurements or studies cited for the bot claim',
  []).
p(reports, users_report_fewer_bot_replies, '2026-10-12', eun, 1,
  'Users in Germany, the UK and the US report fewer apparently automated political replies',
  []).
p(noverify, no_verified_figures_for_user_reports, '2026-10-12', eun, 4,
  'No independently verified figures for those declines',
  []).
p(pm, lithuanian_pm_urges_more_strikes, '2026-10-12', mm, 3,
  'Lithuanian PM urges allies to ask for more data-centre strikes (advocacy, not evidence)',
  []).

%% --- Rules ----------------------------------------------------------------

defeasible(r_struck, [yandex_reports_sasovo_datacentre_stopped,
                      zelensky_confirms_strike_on_datacentre],
           ukraine_struck_yandex_datacentres,
           [prio(4), scheme(agreeing_adversaries),
            label('the target and the attacker both describe the strike')]).

defeasible(r_traffic, [cloudflare_radar_shows_yandex_automated_traffic_down],
           yandex_automated_traffic_fell,
           [prio(4), scheme(measurement),
            label('independent network measurement')]).

defeasible(r_bots_from_traffic, [yandex_automated_traffic_fell],
           russian_political_bot_activity_fell,
           [prio(2), scheme(sign),
            label('less automated traffic from the network suggests fewer bots')]).
critical_question(r_bots_from_traffic, 'Does the traffic figure include automation that is not bots?').
critical_question(r_bots_from_traffic, 'Were the political bots hosted on this network at all?').

defeasible(r_crawlers, [yandex_automated_traffic_includes_crawlers],
           undercut(r_bots_from_traffic),
           [prio(4), scheme(measurement_validity),
            label('the measure counts crawlers too, so it cannot isolate bots')]).

defeasible(r_zelensky, [zelensky_says_bots_reduced],
           russian_political_bot_activity_fell,
           [prio(2), scheme(testimony),
            label('a head of state reports a noticeable change')]).
critical_question(r_zelensky, 'Is the witness an interested party?').
critical_question(r_zelensky, 'What is the basis of the claim: measurement or impression?').

defeasible(r_no_basis, [zelensky_cited_no_data], undercut(r_zelensky),
           [prio(3), scheme(basis_of_knowledge),
            label('testimony with no stated basis does not establish a measurable claim')]).

defeasible(r_reports, [users_report_fewer_bot_replies],
           russian_political_bot_activity_fell,
           [prio(1), scheme(anecdote),
            label('many users noticing the same change')]).
critical_question(r_reports, 'Has anyone measured it?').
critical_question(r_reports, 'Could expectation create the impression?').

defeasible(r_unverified, [no_verified_figures_for_user_reports], undercut(r_reports),
           [prio(4), scheme(measurement_validity),
            label('unmeasured impressions cannot establish a rate change')]).

defeasible(r_cause, [russian_political_bot_activity_fell, ukraine_struck_yandex_datacentres],
           bot_drop_caused_by_strikes,
           [prio(2), scheme(cause_from_sequence),
            label('the fall followed the strikes')]).
critical_question(r_cause, 'Is "after" being taken for "because of"?').
