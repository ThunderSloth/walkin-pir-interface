PROJECT   := WALKIN_PIR_IF
KICAD_DIR := hardware/pcb/kicad
KIBOT_CFG := hardware/kibot/kibot.yaml
OUT_DIR   := outputs

IMAGE     := niktt332/kicad9-kibot:1.8.4
PLATFORM  := --platform linux/amd64

REPO_ROOT := $(shell pwd)

FAB_DIR   := $(OUT_DIR)/fab/gerbers
FAB_ZIP   := $(OUT_DIR)/fab/$(PROJECT)_fab.zip

DOCS_DIR       := docs
DOCS_ARTIFACTS := $(DOCS_DIR)/artifacts

.PHONY: all build zip clean check sync_docs mkdocs

# Default: build outputs, create fab zip, and sync artifacts into MkDocs
all: build zip sync_docs

build: check
	@echo "==> Running KiBot (Docker)…"
	docker run --rm -t $(PLATFORM) \
	  -v "$(REPO_ROOT)":/work \
	  -w /work/$(KICAD_DIR) \
	  $(IMAGE) \
	  kibot -d /work/$(OUT_DIR) -c ../../kibot/kibot.yaml -e $(PROJECT).kicad_sch -b $(PROJECT).kicad_pcb

zip: build
	@echo "==> Creating generic fab zip…"
	@mkdir -p "$(OUT_DIR)/fab"
	@rm -f "$(FAB_ZIP)"
	@cd "$(FAB_DIR)" && zip -r "../$(notdir $(FAB_ZIP))" .
	@echo "==> Done: $(FAB_ZIP)"

sync_docs: build
	@echo "==> Syncing KiBot outputs into MkDocs docs/artifacts/…"
	@mkdir -p "$(DOCS_ARTIFACTS)"
	@rsync -a --delete "$(OUT_DIR)/docs/"     "$(DOCS_ARTIFACTS)/docs/"
	@rsync -a --delete "$(OUT_DIR)/assembly/" "$(DOCS_ARTIFACTS)/assembly/"
	@rsync -a --delete "$(OUT_DIR)/fab/"      "$(DOCS_ARTIFACTS)/fab/"
	@rsync -a --delete "$(OUT_DIR)/mcad/"     "$(DOCS_ARTIFACTS)/mcad/"

	@echo "==> Rendering CSV tables (HTML) for wide-table viewing…"
	@python3 tools/render_csv_tables.py

	@echo "==> Generating PDF preview thumbnails (macOS sips)…"
	@mkdir -p "$(DOCS_ARTIFACTS)/previews"
	@sips -s format png "$(DOCS_ARTIFACTS)/docs/schematic/$(PROJECT)-schematic.pdf" --out "$(DOCS_ARTIFACTS)/previews/schematic.png" >/dev/null 2>&1 || true
	@sips -s format png "$(DOCS_ARTIFACTS)/docs/fab/$(PROJECT)-fab-drawing.pdf" --out "$(DOCS_ARTIFACTS)/previews/fab-drawing.png" >/dev/null 2>&1 || true
	@sips -s format png "$(DOCS_ARTIFACTS)/docs/assembly/$(PROJECT)-assembly-top.pdf" --out "$(DOCS_ARTIFACTS)/previews/assembly-top.png" >/dev/null 2>&1 || true

mkdocs: sync_docs
	@echo "==> Serving MkDocs…"
	mkdocs serve

clean:
	@echo "==> Cleaning outputs and synced artifacts…"
	@find "$(OUT_DIR)" -mindepth 1 -delete 2>/dev/null || true
	@find "$(DOCS_ARTIFACTS)" -mindepth 1 -delete 2>/dev/null || true

check:
	@command -v docker >/dev/null 2>&1 || (echo "Docker not found in PATH" && exit 1)
	@command -v rsync  >/dev/null 2>&1 || (echo "rsync not found (try: brew install rsync)" && exit 1)
	@command -v mkdocs >/dev/null 2>&1 || (echo "mkdocs not found (try: pipx install mkdocs mkdocs-material --include-deps)" && exit 1)
	@test -f "$(KIBOT_CFG)" || (echo "Missing $(KIBOT_CFG)" && exit 1)
	@test -f "$(KICAD_DIR)/$(PROJECT).kicad_pcb" || (echo "Missing PCB file" && exit 1)
	@test -f "$(KICAD_DIR)/$(PROJECT).kicad_sch" || (echo "Missing SCH file" && exit 1)
