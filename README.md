# Quiz Cricket

Two builds live here:
- `index.html` + `assets/`: the Three.js prototype (static server on 8765). Kept as reference for the quiz loop and camera cuts.
- `godot/`: the Godot 4.7 project the game moves to. Runs entirely in Docker, no local Godot install.

## Godot workflow (Docker)

```
make import    # first run, and after adding assets: builds the .godot import cache
make test      # headless unit tests (match engine / rule book)
make export    # web export → godot/build/web/
make serve     # nginx on http://localhost:8766/
make demo      # headless auto-played innings at 7x speed: the integration check
make all       # import, test, export, serve
```

Add `#demo` to the web URL for an auto-playing attract mode at normal pace.

`docker compose run --rm godot <args>` runs any Godot CLI command headless against `godot/`. The web export is single-threaded (`thread_support=false`) so it works from any static server without cross-origin isolation headers. `nginx.conf` sends `Cache-Control: no-store` and gzips the wasm, so a plain reload always shows the latest export. Files the container writes are root-owned; `sudo chown -R $USER godot` if that ever gets in the way.

Layers, one script each:
- `match_engine.gd`: pure rules and innings state, no nodes. The rule book goes here. Tested in `tests/`.
- `quiz.gd`: question bank and deck.
- `world.gd`: stadium, scoreboard, ball, camera. No game logic.
- `player.gd`: one cricketer. The only script that knows which model is used.
- `ui.gd`: HUD, timer, question card, overlays. Emits answers, holds no rules.
- `game.gd`: the ball-by-ball sequence. `pace` multiplies every animation duration.

The bowling action is procedural: at the crease the sprint pose is frozen (a delivery stride), the bowling arm is rotated back, overhead and over the top with the ball pinned to the hand, and the ball is released at the top of the arc. A side-on camera shows it, then cuts behind the batter. Demo mode uses a fixed random seed so timings repeat between runs.

The batters are the **Claude Design "3D Stylized Cricket Player"** (`assets/characters/cricket_player.glb`), exported from the design's own Three.js model code. It has no animation clips, so `player.gd` swings its `leg_L / leg_R / arm_L / arm_R` groups procedurally for idle, sprint and the shot; the bat is part of the model. To regenerate after editing the design: paste the model code into `tools/design_export/export.html`, serve that folder, and run `tools/design_export/glbexport.mjs <out.glb>` against a Chrome started with `--remote-debugging-port=9222`. Any player can use it by passing its `res://` path as the skin in `game.gd`.

Fielders and umpires are Kenney's **Blocky Characters** (CC0, `assets/characters/`, licence file alongside): node-animated GLBs with idle, sprint, pick-up, a right-arm swing, holding and emote clips, so batting, running, fielding and umpire signals need no custom animation. Swap models by editing `player.gd` only.


3D cricket ground (Three.js from CDN, no build step). Run a static server in this folder and open it:

```
python3 -m http.server 8765   # then http://localhost:8765/
```

Add `#demo` to the URL for an auto-playing attract mode (70% correct answers).

**Players** are the rigged Mixamo mannequin `assets/Xbot.glb` (2.9 MB, taken from the three.js examples repo, r169). Its idle, run and crouch clips drive the fielders, batters, keeper and umpires; the bat swing and bowling arm are procedural on top of the skeleton. Team colour is a material tint, so a real kit model can replace it by swapping the file as long as it keeps Mixamo bone names.

**Pace** is one knob: `PACE` at the top of the script multiplies every animation duration (currently 1.8). `SECS` is the question clock (15 s). The runs ladder is in fractions of the clock, so changing `SECS` keeps the 6/4/2/1 split.

Each ball: the bowler runs in while the timer counts down. Answer, the batter plays a shot sized by your speed, fielders chase, batters run, then the camera cuts to the big scoreboard and the score ticks up.

**MVP rules** (rule book for caught, lbw, run-out etc. still to be designed)
- 12 balls, 3 wickets. Every ball is a question with 4 options and a 15 s timer.
- Correct answer → runs by how much of the clock you used: first 30% = 6, up to 60% = 4, up to 80% = 2, else 1.
- Wrong answer → wicket. Timer runs out → dot ball.
- Keys 1–4 answer. Best score kept in localStorage.

Tunables are the three constants at the top of the script. Questions are the `BANK` array.

---

## Making it addictive (in the good way)

The MVP already has the core loop that matters: **answer under pressure → instant, visible consequence**. Everything below strengthens that loop. Ordered by payoff per effort.

### 1. Flow: keep challenge glued to skill

Flow (Csíkszentmihályi) needs three things: clear goals, immediate feedback, and challenge matched to skill. The MVP has the first two. The third is the biggest missing piece.

- **Adaptive difficulty per ball.** Tag questions easy/medium/hard. Two correct in a row → bump difficulty. One wrong → drop. The player should be answering ~70–80% correctly. Below that it's anxiety, above it's boredom.
- **Bowler types as difficulty framing.** "Spinner" = easy, more time. "Fast bowler" = hard, 6 s timer, 6 runs guaranteed if correct. The game chooses the bowler from the player's recent form, so difficulty adjustment feels like cricket, not like a test adapting.
- **Shrinking timer on streaks.** Each consecutive correct answer shaves 0.5 s. Pressure rises exactly as competence shows. Reset on a wrong answer.
- **No pause between balls longer than ~1.5 s.** Flow dies in dead air. Result animation and next question should overlap.

### 2. Hooked (Nir Eyal): Trigger → Action → Variable Reward → Investment

**Trigger**
- External: daily "match" notification, "Your school's innings vs Class 8B starts in 10 min".
- Internal (the goal): the student feels a small itch of boredom or competitiveness and reaches for one more over. This only forms once the loop is reliable, so ship the reward and investment layers first.

**Action** is already minimal: one tap. Keep it that way. Never add a confirm step.

**Variable reward** (this is where the MVP is thinnest)
- *Rewards of the hunt:* runs are already variable by speed. Add **random wagon-wheel direction and shot name** ("Cover drive!", "Pulled over square leg!") so each correct answer looks different. Occasional **free hit** ball: wrong answer costs nothing, so the player swings big.
- *Rewards of the tribe:* commentary that reacts to context ("That's fifty up!", "Pressure's on, two wickets down"). Later, live class leaderboard during a session.
- *Rewards of the self:* milestones that aren't scores. 50, 100, hat-trick of sixes, "answered under 1 s", "survived a maiden".
- *Fielders and catches:* a slow-but-correct answer has a small chance of being **caught** (a fielder animation). Occasional unfairness on the margins is what makes slot machines and cricket both compelling. Keep it rare and only on slow answers so it never feels like the quiz was wrong.

**Investment**
- Persistent **career stats**: innings, average, strike rate, high score, per-topic averages. Students will grind to fix a weak topic average without being told to revise.
- **Unlockable bats/kits** earned by topic mastery, not purchase. "Chemistry bat" unlocks at 80% chemistry accuracy over 50 balls.
- **Build your own team**: pick questions you got wrong into a "nets" session. The player curates their own revision deck.

### 3. Gamification structure (Octalysis / "Actionable Gamification")

- **Epic meaning:** play for your class or house. Individual runs roll into a house total displayed in the classroom.
- **Accomplishment:** levels tied to cumulative runs (Club → District → State → National → Test cap).
- **Ownership:** the career stats and kit above.
- **Scarcity / urgency:** chase mode. "Need 24 off 12 balls". Required run rate on screen. This is the single most adrenaline-rich mechanic in cricket and it costs ten lines.
- **Unpredictability:** powerplay overs (runs doubled), DRS review (one per innings: on a wrong answer, see a 10 s explanation and the wicket is overturned if you then answer a follow-up correctly). DRS is also the main **learning** moment, so don't make it rare.
- **Loss aversion:** wickets already do this. Add **"Not Out" bonus**: finishing an innings with wickets in hand multiplies the score.
- **Social:** asynchronous head-to-head. You bat, your friend chases your total later on the same questions.

### 4. What keeps it educational and not just a reflex game

- Timer length should be set so reading the question is the bottleneck, not reaction. 10 s for recall, 20 s for a one-step calculation, 30 s for a word problem.
- **Wrong answer always shows the correct one with a one-line explanation** during the 1.4 s result pause. Extend the pause to 3 s on wrongs only. Mistakes are the only time the student is reading to learn; don't rush that moment.
- Spaced repetition hidden in the ball selection: questions answered wrong reappear 3–5 balls later, then next innings, then next week.
- Teachers upload question banks as CSV. Topic tags drive the adaptive difficulty and the per-topic stats.

### Suggested next three builds

1. **Chase mode + required run rate** (adrenaline, tiny).
2. **Streak timer shrink + adaptive difficulty tags** (flow).
3. **Career stats in localStorage with per-topic average** (investment, the start of the hook).
