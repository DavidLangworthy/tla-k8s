TOOLS_DIR ?= .tools
TLA2TOOLS ?= $(TOOLS_DIR)/tla2tools.jar
TLA2TOOLS_URL ?= https://github.com/tlaplus/tlaplus/releases/latest/download/tla2tools.jar
TLC := java -cp $(TLA2TOOLS) tlc2.TLC

.PHONY: tools check safety stable-liveness failure-liveness explore explore-sequence

tools: $(TLA2TOOLS)

$(TLA2TOOLS):
	mkdir -p $(TOOLS_DIR)
	curl -fsSL -o $(TLA2TOOLS) $(TLA2TOOLS_URL)

check: safety stable-liveness failure-liveness

safety:
	$(TLC) -config K8sPodNodeGpuSafety.cfg K8sPodNodeGpu

stable-liveness:
	$(TLC) -config K8sPodNodeGpuStableLiveness.cfg K8sPodNodeGpu

failure-liveness:
	$(TLC) -config K8sPodNodeGpuFailureLiveness.cfg K8sPodNodeGpu

explore:
	@if [ -z "$(CONFIG)" ]; then echo "usage: make explore CONFIG=runs/configs/<name>.cfg [LABEL=name] [TIMEOUT_SECONDS=600]" >&2; exit 2; fi
	runs/scripts/run_tlc.sh "$(CONFIG)" "$(LABEL)"

explore-sequence:
	runs/scripts/run_sequence.sh
