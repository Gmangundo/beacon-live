# Beacon: setup from start to finish

## A. Supabase (once)
1. Supabase dashboard > **SQL Editor** > New query. Paste and Run each file in the `sql/` folder, in order, one at a time:
   1. `sql/01_beacon_setup.sql` (Family Feud, security lockdown, emoji, double/triple points, phone answers). **Run this again whenever you update the site**: it adds the new phone-answers pieces and is safe to re-run.
   2. `sql/02_beacon_progress.sql` (XP, levels, streaks, badges, groups, leaderboards, name filter)

   Each should say "Success". Both are safe to re-run. The quiz tables and the `is_host` and `get_leaderboard` functions must already exist in your project, because the files above build on them.
   The old step-by-step files are kept in `sql/archive/` for reference only. Do not run them.
2. **Authentication > Sign In / Providers**: make sure **Allow anonymous sign-ins** is ON (players need it).
3. **Authentication > URL Configuration**: set **Site URL** to your GitHub Pages address (step B4), for example `https://YOURNAME.github.io/beacon/`, and add the same address under **Redirect URLs**.
4. `config.js` already holds your project URL and public key. Do not put any "service_role" or secret key in this repo.

## B. GitHub
1. Create a repository (for example `beacon`). Set it to Public (free Pages needs this on free accounts).
2. Unzip `beacon-github-files.zip`. On the repo page click **Add file > Upload files**, drag in ALL the files and the `sql` folder (not the zip itself), then **Commit changes**.
3. Go to **Settings > Pages**. Under Build and deployment choose **Deploy from a branch**, branch **main**, folder **/(root)**, then Save.
4. Wait about 1 minute. Your site is at `https://YOURNAME.github.io/beacon/`. Finish A3 with that address.

## C. Test before a real session (10 minutes)
1. Open `present.html`, log in as host, create a session. Open the site on your phone, join with the code. Confirm the emoji shows on the leaderboard.
2. Open `feud-host.html`, create a game (question plus 3 answers like `Genesis, 38`). Join `feud.html` from two phones, one with each team code. Confirm each lands on the right colour.
3. Click Open buzzers, buzz from both phones: only one team wins. Reveal an answer for a team and check the score.
4. Click Next question and check the scores are kept. Click Join call on the host and a phone.
5. Finish a quiz game and confirm the XP pop-up appears, then open `profile.html` and check your level, streak and badge.

## Family Feud with phone answers
1. On `feud-host.html` build the questions as usual, then Start game.
2. Players open `feud.html`, enter their team code, choose an animated character and join.
3. Click **Phone answers: OFF** to switch it ON (it turns green). Then click **Start face-off**.
4. One random player from each team is picked for the face-off. Only those two can buzz. The first to buzz types an answer on their phone.
5. Right answer: that team plays the round and its players take turns typing, with no buzzing. Wrong answer: the other face-off player gets a turn. Both wrong: a new face-off starts.
6. Three wrong answers give the other team one steal guess. The bank goes to the team that wins the round.
7. If an answer is close but not exact (a typo, or part of the answer), a yellow box appears on the host screen: tap **Accept** or **Reject**.
8. **Next question** resets the round. Leave Phone answers OFF to run the game the old way with the manual buttons.

Tip: write answers short and plain (for example `Genesis`, not `The Book of Genesis`), because players match against what you typed.

## Spline 3D background
Open `spline.js` and paste your Spline link after `all:`. Share links (`my.spline.design/...`) and exported `.splinecode` files both work.

## D. Later: move to Vercel
Vercel > Add New > Project > import the same GitHub repo > Deploy (no settings needed). Then add the new Vercel address to Supabase **URL Configuration** (A3).

## Known limits
- Calls use Jitsi's free public server. If it cuts calls short or limits you, tell me and we switch to a free-account version.
- Everyone with a team code can join that team. Share codes only with the right people.
