extends SceneTree
# Run: docker compose run --rm godot -s tests/test_match_engine.gd

func _init() -> void:
	var ok := true
	ok = ok and MatchEngine.runs_for(true, 1.0, 15.0) == 6
	ok = ok and MatchEngine.runs_for(true, 7.0, 15.0) == 4
	ok = ok and MatchEngine.runs_for(true, 11.0, 15.0) == 2
	ok = ok and MatchEngine.runs_for(true, 14.0, 15.0) == 1
	ok = ok and MatchEngine.runs_for(false, 1.0, 15.0) == -1
	ok = ok and MatchEngine.runs_for(null, 15.0, 15.0) == 0

	var inn := MatchEngine.Innings.new()
	for r in [4, 6, -1, 0, 1, 2, 4]:
		inn.record(r)
	ok = ok and inn.runs == 17 and inn.wkts == 1 and inn.balls == 7
	ok = ok and inn.overs() == "1.1" and inn.this_over == ["4"] and not inn.is_over()
	for r in [-1, -1]:
		inn.record(r)
	ok = ok and inn.is_over()

	print("match_engine: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
