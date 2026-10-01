TOP = tb_skew_unit
DUT = skew_unit

include ../common.mk

# Use the repository-local rules for the integrated tile workflow.
.PHONY: tile-lint tile-sim tile-test
tile-lint:
	$(MAKE) -f common.mk TOP=tb_mac_tile DUT=mac_tile lint

tile-sim:
	$(MAKE) -f common.mk TOP=tb_mac_tile DUT=mac_tile sim

tile-test:
	$(MAKE) -f common.mk test-tile
