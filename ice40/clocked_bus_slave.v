module dff #(parameter W=1)
   (input wire[W-1:0] D, input clk, output reg[W-1:0] Q);

   always @(posedge clk)
     Q <= D;
endmodule // dff


module synchroniser #(parameter W=1)
   (input wire[W-1:0] D, input clk, output wire[W-1:0] Q);

   wire[W-1:0] M;

   dff #(W) first_reg(D, clk, M);
   dff #(W) last_reg(M, clk, Q);
endmodule


module clocked_bus_slave #(parameter ADRW=1, DATW=1)
  (input aNE, aNOE, aNWE,
   input wire [ADRW-1:0] aAn, input wire[DATW-1:0] aDn,
   input 		 clk,
   output wire[ADRW-1:0] r_adr, output wire[ADRW-1:0] w_adr,
   output reg 		 do_read, input wire[DATW-1:0] read_data,
   output reg 		 do_write, output reg[DATW-1:0] w_data,
   output 		 io_output, output wire[DATW-1:0] io_data);

   wire sNE, sNOE, sNWE;
   reg[ADRW-1:0] sAn_r;
   reg[ADRW-1:0] sAn_w;
   reg[DATW-1:0] rDn;
   reg[DATW-1:0] wDn;
   wire[ADRW-1:0] next_sAn_r;
   wire[ADRW-1:0] next_sAn_w;
   wire[DATW-1:0] next_rDn;
   wire[DATW-1:0] next_wDn;
   wire next_do_write, next_do_read;

   // States for one-hot state machine.
   reg st_idle=1, st_write=0, st_read1=0, st_read2=0;
   wire next_st_idle, next_st_write, next_st_read1, next_st_read2;

   synchroniser sync_NE(aNE, clk, sNE);
   synchroniser sync_NOE(aNOE, clk, sNOE);
   synchroniser sync_NWE(aNWE, clk, sNWE);

   always @(posedge clk) begin
      st_idle <= next_st_idle;
      st_write <= next_st_write;
      st_read1 <= next_st_read1;
      st_read2 <= next_st_read2;

      do_write <= next_do_write;
      do_read <= next_do_read;

      sAn_r <= next_sAn_r;
      sAn_w <= next_sAn_w;
      wDn <= next_wDn;
      rDn <= next_rDn;
   end

   /* Latch the address on the falling edge of NOE (read) or NWE (write).
      We can use the external address unsynchronised, as it will be stable
      when NOE/NWE toggles.
    */
   assign next_sAn_r = st_idle & ~sNE & ~sNOE ? aAn : sAn_r;
   assign next_sAn_w = st_idle & ~sNE & ~sNWE ? aAn : sAn_w;

   /* Incoming write. */
   /* Latch the write data on the falling edge of NWE. NWE is synchronised,
      so the synchronisation delay is enough to ensure that the async external
      data signal is stable at this point.
    */
   assign next_wDn = st_idle & ~sNE & ~sNWE ? aDn : wDn;
   // Trigger a register write when NWE goes low.
   assign next_do_write = st_idle & ~sNE & ~sNWE;
   assign next_st_write = (st_idle | st_write) & (~sNE & ~sNWE);

   /* Incoming read. */
   assign next_do_read = st_idle & ~sNE & ~sNOE;
   /* Wait one cycle for register read data to become available. */
   assign next_st_read1 = st_idle & ~sNE & ~sNOE;
   /* Put read data on the bus while NOE is asserted. */
   assign next_st_read2 = (st_read1 | st_read2) & ~sNE & ~sNOE;

   assign next_st_idle = ((st_read1 | st_read2) & (sNOE | sNE)) |
			 (st_write & (sNWE | sNE)) |
			 (st_idle & (sNE | (sNOE & sNWE)));

   /* Latch register read data one cycle after asserting do_read. */
   assign next_rDn = st_read1 ? read_data : rDn;
   /* Output data during read after latching read data. */
   assign io_output = st_read2 & next_st_read2;
   assign io_data = rDn;

   assign r_adr = sAn_r;
   assign w_adr = sAn_w;
   assign w_data = wDn;
endmodule
