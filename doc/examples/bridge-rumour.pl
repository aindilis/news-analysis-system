/*  Tutorial example: a FICTIONAL rumour, used to teach case writing.
    Riverside Bridge and every source here are invented.
*/

case_title('Tutorial: the Riverside Bridge rumour (fictional)').

%  Where each piece of evidence came from.
src(post,  'A social media post (fictional)',        'none').
src(city,  'City traffic department account (fictional)', 'none').
src(check, 'Reverse image search result (fictional)', 'none').
src(tv,    'Local TV live broadcast (fictional)',      'none').

%  A helper: p/7 facts become premise/3 facts with their sources attached.
premise(Id, L, [date(D), source(S), url(U), prio(P), note(N)|X]) :-
    p(Id, L, D, K, P, N, X),
    src(K, S, U).

%  The questions this case tracks.
topic(bridge_collapsed, 'Did the Riverside Bridge collapse?').
topic(photo_is_current, 'Is the viral photo from today?').

%  Evidence, in the order it became public.
p(photo,  viral_photo_of_collapsed_bridge, '2026-03-01T08:00', post, 1,
  'A post shows a collapsed bridge captioned "Riverside Bridge is gone"', []).
p(city,   city_says_bridge_open,           '2026-03-01T08:30', city, 3,
  'City traffic department: bridge open, a minor accident was cleared', []).
p(search, photo_found_online_in_2019,      '2026-03-01T08:45', check, 3,
  'The same photo appears online in 2019, from a different country', []).
p(live,   live_tv_shows_traffic_on_bridge, '2026-03-01T09:00', tv, 4,
  'Live TV shows traffic crossing the bridge', []).

%  Rules: how evidence supports conclusions.
defeasible(r_photo_current, [viral_photo_of_collapsed_bridge], photo_is_current,
           [prio(1), label('a photo posted as news is presumed to be from today')]).
critical_question(r_photo_current, 'Has the photo appeared anywhere before?').

defeasible(r_photo_shows, [viral_photo_of_collapsed_bridge, photo_is_current],
           bridge_collapsed,
           [prio(1), label('a current photo shows what happened')]).

defeasible(r_city, [city_says_bridge_open], neg(bridge_collapsed),
           [prio(3), label('the authority responsible for the bridge reports it open')]).

defeasible(r_old_photo, [photo_found_online_in_2019], neg(photo_is_current),
           [prio(3), label('a photo published in 2019 is not from today')]).

defeasible(r_live, [live_tv_shows_traffic_on_bridge], neg(bridge_collapsed),
           [prio(4), label('a live broadcast shows the bridge standing')]).
