class_name Quiz
## Question bank. ponytail: hardcoded; load from JSON when teachers upload their own banks.

const BANK := [
	["7 × 8 = ?", ["56", "54", "64", "48"], 0],
	["Square root of 144?", ["14", "12", "11", "13"], 1],
	["Largest planet in the solar system?", ["Saturn", "Earth", "Jupiter", "Neptune"], 2],
	["H₂O is the formula for?", ["Hydrogen", "Salt", "Oxygen", "Water"], 3],
	["15% of 200?", ["30", "25", "35", "20"], 0],
	["Capital of Australia?", ["Sydney", "Canberra", "Melbourne", "Perth"], 1],
	["Which gas do plants absorb?", ["Oxygen", "Nitrogen", "Carbon dioxide", "Helium"], 2],
	["Smallest prime number?", ["0", "1", "3", "2"], 3],
	["Boiling point of water (°C)?", ["100", "90", "110", "212"], 0],
	["Who wrote Hamlet?", ["Dickens", "Shakespeare", "Tolstoy", "Austen"], 1],
	["Angles in a triangle sum to?", ["90°", "360°", "180°", "270°"], 2],
	["Speed = distance ÷ ?", ["mass", "force", "energy", "time"], 3],
	["12² = ?", ["144", "124", "148", "164"], 0],
	["Longest river in the world?", ["Amazon", "Nile", "Ganga", "Yangtze"], 1],
	["Powerhouse of the cell?", ["Nucleus", "Ribosome", "Mitochondria", "Vacuole"], 2],
	["Hardest natural substance?", ["Iron", "Quartz", "Gold", "Diamond"], 3],
	["Next in 2, 4, 8, 16, ?", ["32", "24", "20", "64"], 0],
	["Chemical symbol for Gold?", ["Gd", "Au", "Ag", "Go"], 1],
	["How many continents?", ["5", "6", "7", "8"], 2],
	["Opposite of 'ancient'?", ["Old", "Historic", "Antique", "Modern"], 3],
	["3/4 as a decimal?", ["0.75", "0.34", "0.5", "0.25"], 0],
	["Light travels fastest in?", ["Water", "Vacuum", "Glass", "Air"], 1],
	["First Prime Minister of India?", ["Gandhi", "Patel", "Nehru", "Bose"], 2],
	["How many sides in a hexagon?", ["4", "5", "8", "6"], 3],
]


static func deck(n: int) -> Array:
	var d := BANK.duplicate()
	d.shuffle()
	return d.slice(0, n)
