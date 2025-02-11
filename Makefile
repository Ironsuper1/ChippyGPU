# Makefile
# Define variables
TOP_MODULE = processor
VERILOG_SRC = src/core.v
OUTPUT_JSON = core.json
OUTPUT_SYNTH = synth/core_synth.v
OUTPUT_DOT = core.dot
OUTPUT_PNG = core.png

# Yosys command
YOSYS_CMD = yosys -p "read_verilog -sv $(VERILOG_SRC); synth -top $(TOP_MODULE); write_json $(OUTPUT_JSON); write_verilog -noattr $(OUTPUT_SYNTH)"

YOSYS_NO_OP_CMD = yosys -p "read_verilog -sv $(VERILOG_SRC); hierarchy -top $(TOP_MODULE); proc; flatten; write_json $(OUTPUT_JSON); write_verilog -noattr $(OUTPUT_SYNTH)"

YOSYS_SHOW_CMD = yosys -p "read_json $(OUTPUT_JSON); show -format png -prefix my_design -colors 42 -enum"

# Default target
all: synthesize viz

synth_no_op:
	$(YOSYS_NO_OP_CMD)
# Synthesize target
synthesize:
	$(YOSYS_CMD)

viz: $(OUTPUT_JSON)
	$(YOSYS_SHOW_CMD)	

# Clean target
clean:
	rm -f $(OUTPUT_JSON) $(OUTPUT_SYNTH) $(OUTPUT_DOT) $(OUTPUT_PNG)
	
