class_name MatchEngine
## Pure rules and innings state. No scene nodes. The full rule book lands here.

const BALLS := 12
const WICKETS := 3
const CLOCK := 15.0   # seconds per question


## Correct answer → runs by fraction of the clock used. Wrong → -1 (wicket). Timed out → 0.
static func runs_for(correct: Variant, elapsed_secs: float, clock_secs: float = CLOCK) -> int:
	if correct == null:
		return 0
	if not correct:
		return -1
	var f := elapsed_secs / clock_secs
	if f <= 0.3:
		return 6
	if f <= 0.6:
		return 4
	if f <= 0.8:
		return 2
	return 1


class Innings:
	var runs := 0
	var wkts := 0
	var balls := 0
	var this_over: Array[String] = []

	func record(r: int) -> void:
		if balls % 6 == 0:
			this_over = []
		if r < 0:
			wkts += 1
		else:
			runs += r
		balls += 1
		this_over.append("W" if r < 0 else ("•" if r == 0 else str(r)))

	func overs() -> String:
		return "%d.%d" % [floori(balls / 6.0), balls % 6]

	func is_over() -> bool:
		return balls >= BALLS or wkts >= WICKETS
