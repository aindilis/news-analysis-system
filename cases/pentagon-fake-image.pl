/*  Case: the fake image of an explosion at the Pentagon, 22 May 2023.

    Part of the News Analysis System (news-analysis-cases).
    License: GPL-3.0-or-later (encoding); facts are from the cited reports.

    What it shows: a viral image is accepted on first sight because
    nothing yet answers its critical questions; within the day, official
    statements and image analysis refute it. The market reaction stays
    accepted: it happened, even though the event did not.

    Times are US Eastern. When a report gives no time for a statement,
    its date is the time the report was published (precision(upper_bound)):
    the statement was public by then, possibly earlier.
    Encoding conventions: see the tutorial (info news-analysis, node
    "Case File Reference") and doc/examples/bridge-rumour.pl.
*/

case_title('Fake image of an explosion at the Pentagon (22 May 2023)').

src(npr, 'NPR, "Fake viral images of an explosion at the Pentagon were probably created by AI", 2023-05-22 18:19 EDT',
         'https://www.npr.org/2023/05/22/1177590231/fake-viral-images-of-an-explosion-at-the-pentagon-were-probably-created-by-ai').
src(pp,  'PetaPixel, "AI-Generated Image of Pentagon Explosion Caused Markets to Dip", 2023-05-22',
         'https://petapixel.com/2023/05/22/ai-generated-image-of-pentagon-explosion-caused-markets-to-dip/').

premise(Id, L, [date(D), source(S), url(U), prio(P), note(N)|X]) :-
    p(Id, L, D, K, P, N, X),
    src(K, S, U).

topic(explosion_at_pentagon,
      'Was there an explosion at the Pentagon?').
topic(image_is_authentic,
      'Is the viral image a real photograph of the scene?').
topic(markets_reacted_to_claim,
      'Did markets react to the claim?').

%% --- Evidence -------------------------------------------------------------

p(viral_image, viral_image_of_explosion_at_pentagon, '2023-05-22T10:06', pp, 1,
  'Image of black smoke "at the Pentagon" spreads on Twitter, shared by blue-check accounts',
  []).
p(market_dip, stocks_fell_sharply_after_post, '2023-05-22T10:10', pp, 3,
  'U.S. stocks turn sharply lower within minutes, then rebound',
  []).
p(official, officials_state_no_explosion, '2023-05-22T18:19', npr, 3,
  'Arlington County Fire and Pentagon Force Protection Agency: no explosion or incident',
  [precision(upper_bound)]).
p(analysis, analyst_found_artifacts_and_no_witnesses, '2023-05-22T18:19', npr, 3,
  'Bellingcat analyst: building and fence artifacts; no other images or firsthand witnesses',
  [precision(upper_bound)]).
p(impostor, spreading_accounts_included_impostor, '2023-05-22T18:19', npr, 3,
  'Spreaders included an account impersonating Bloomberg News; RT later deleted its post',
  [precision(upper_bound)]).

%% --- Rules ----------------------------------------------------------------

defeasible(r_photo_authentic, [viral_image_of_explosion_at_pentagon], image_is_authentic,
           [prio(1), scheme(photograph),
            label('an image shared as news is presumed to be a real photograph')]).
critical_question(r_photo_authentic, 'Are there other images or firsthand witnesses?').
critical_question(r_photo_authentic, 'Is the account that posted it who it claims to be?').
critical_question(r_photo_authentic, 'Does the image show signs of generation or editing?').

defeasible(r_depicts, [viral_image_of_explosion_at_pentagon, image_is_authentic],
           explosion_at_pentagon,
           [prio(1), scheme(photograph),
            label('an authentic photograph shows what happened')]).

defeasible(r_market, [stocks_fell_sharply_after_post], markets_reacted_to_claim,
           [prio(2), scheme(correlation),
            label('a sharp fall minutes after the post suggests traders reacted to it')]).
critical_question(r_market, 'A market reaction shows that people believed it, not that it was true.').

defeasible(r_official, [officials_state_no_explosion], neg(explosion_at_pentagon),
           [prio(4), scheme(authority_with_direct_access),
            label('the agencies responsible for the site report no incident')]).
critical_question(r_official, 'Are the officials in a position to know?').

defeasible(r_forensic, [analyst_found_artifacts_and_no_witnesses], neg(image_is_authentic),
           [prio(3), scheme(image_forensics),
            label('visible artifacts and no corroborating witnesses mark the image as fabricated')]).

defeasible(r_impostor, [spreading_accounts_included_impostor], undercut(r_photo_authentic),
           [prio(2), scheme(source_credibility),
            label('impostor and state-media accounts are not credible sources')]).
