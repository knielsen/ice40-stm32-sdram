PROJ = sdram-stm32
PIN_DEF = sdram-stm32.pcf
DEVICE = hx8k

all: $(PROJ).rpt $(PROJ).bin

%.blif: %.v
	yosys -q -p 'synth_ice40 -top top -blif $@' \
		clocked_bus_slave.v \
		sdram_controller.v sdram_control_fsm.v \
		autorefresh_counter.v delay_gen150us.v lfsr_count64.v lfsr_count255.v $<

%.asc: $(PIN_DEF) %.blif
	arachne-pnr -d $(subst hx,,$(subst lp,,$(DEVICE))) -o $@ -p $^

%.bin: %.asc
	icepack $< $@

%.rpt: %.asc
	icetime -d $(DEVICE) -mtr $@ $<

$(PROJ).blif: clocked_bus_slave.v \
	sdram_controller.v sdram_control_fsm.v sdram_defines.v \
	autorefresh_counter.v delay_gen150us.v lfsr_count64.v lfsr_count255.v

prog: $(PROJ).bin
	iceprog $<

clean:
	rm -f $(PROJ).blif $(PROJ).asc $(PROJ).rpt $(PROJ).bin

.SECONDARY:
.PHONY: all prog clean
