PROJECT   := WALKIN_PIR_IF
KICAD_DIR := hardware/pcb/kicad
KIBOT_CFG := hardware/kibot/kibot.yaml
OUT_DIR   := hardware/outputs

IMAGE     := niktt332/kicad9-kibot:1.8.4
PLATFORM  := --platform linux/amd64

REPO_ROOT := $(shell pwd)

FAB_DIR   := $(OUT_DIR)/fab/gerbers
FAB_ZIP   := $(OUT_DIR)/fab/$(PROJECT)_fab.zip

.PHONY: all build zip clean check

all: build zip

build: check
	@echo "==> Running KiBot (Docker)…"
	docker run --rm -t $(PLATFORM) \
	  -v "$(REPO_ROOT)":/work \
	  -w /work/$(KICAD_DIR) \
	  $(IMAGE) \
	  kibot -c ../../kibot/kibot.yaml -e $(PROJECT).kicad_sch -b $(PROJECT).kicad_pcb

zip: build
	@echo "==> Creating generic fab zip…"
	@mkdir -p "$(OUT_DIR)/fab"
	@rm -f "$(FAB_ZIP)"
	@cd "$(FAB_DIR)" && zip -r "../$(PROJECT)_fab.zip" .
	@echo "==> Done: $(FAB_ZIP)"

clean:
	@echo "==> Cleaning outputs…"
	@find "$(OUT_DIR)" -mindepth 1 -delete 2>/dev/null || true

check:
	@command -v docker >/dev/null 2>&1 || (echo "Docker not found in PATH" && exit 1)
	@test -f "$(KIBOT_CFG)" || (echo "Missing $(KIBOT_CFG)" && exit 1)
	@test -f "$(KICAD_DIR)/$(PROJECT).kicad_pcb" || (echo "Missing PCB file" && exit 1)
	@test -f "$(KICAD_DIR)/$(PROJECT).kicad_sch" || (echo "Missing SCH file" && exit 1)
