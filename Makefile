G=docker compose run --rm godot
import:   ; $(G) --import
test:     ; $(G) -s tests/test_match_engine.gd
export:   ; mkdir -p godot/build/web && $(G) --export-release Web build/web/index.html
serve:    ; docker compose up -d web && echo "http://localhost:8766/"
all: import test export serve
demo:     ; docker compose run --rm -e QC_DEMO=1 godot
