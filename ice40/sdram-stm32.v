parameter DW = 16;
parameter AW = 8;

parameter PERIPH_REG_ADR_LOW = 8'h00;
parameter PERIPH_REG_ADR_HIGH = 8'h01;
parameter PERIPH_REG_DATA = 8'h02;


module pllclk (input ext_clock, output pll_clock, input nrst, output lock);
   wire dummy_out;
   wire bypass, lock1;

   assign bypass = 1'b0;

   // DIVR=0 DIVF=71 DIVQ=3  freq=12/1*72/8 = 108 MHz
   // DIVR=0 DIVF=47 DIVQ=4  freq=12/1*48/16 = 36 MHz
   SB_PLL40_CORE #(.FEEDBACK_PATH("SIMPLE"), .PLLOUT_SELECT("GENCLK"),
		   .DIVR(4'd0), .DIVF(7'b1000111), .DIVQ(3'b011),    // 108 MHz
		   //.DIVR(4'd0), .DIVF(7'b0101111), .DIVQ(3'b100),  // 36 MHz
		   .FILTER_RANGE(3'b001)
   ) mypll1 (.REFERENCECLK(ext_clock),
	    .PLLOUTGLOBAL(pll_clock), .PLLOUTCORE(dummy_out), .LOCK(lock1),
	    .RESETB(nrst), .BYPASS(bypass));

endmodule


module top (
   // ICE40 hx8k breakout board stuff.
   //output [7:0]   LED,   // Conflicts with SDRAM pins :-/
   input 	  crystal_clk,
   // FSMC
   input 	  aNE, aNOE, aNWE,
   input [AW-1:0] aA,
   inout [DW-1:0] aD,
   // SDRAM
   output 	  sdram_gpio1, sdram_gpio2,
   input 	  sdram_gpio3, sdram_gpio4,
   input 	  sdram_gpio5,
   inout [DW-1:0] mem_d,
   output [12:0]  mem_a,
   output 	  mem_ras,
   output 	  mem_cas,
   output [1:0]   mem_dqm,
   output 	  mem_clk,
   output 	  mem_cke,
   output 	  mem_we,
   output [1:0]   mem_ba,
   output 	  mem_cs1,
   output 	  mem_cs2
);

   // Main clock, from PLL.
   wire      clk;
   wire      pll_nrst, lock;
   assign pll_nrst = 1'b1;
   pllclk my_pll(crystal_clk, clk, pll_nrst, lock);

   // Reset control (the sdram controller needs a reset signal).
   reg 		  st_after_startup = 0;
   reg [1:0] 	  startup_counter = 0'b00;
   always @(posedge clk) begin
      startup_counter <= startup_counter + 1;
      if (startup_counter == 2'b11)
	st_after_startup <= 1;
   end


   // Bi-directional I/O pads for data busses.
   wire 	  fsmc_io_d_output; // Controls direction of data bus to FSMC
   wire [DW-1:0]  aDn_output;
   wire [DW-1:0]  aDn_input;
   // Type 101001 is output with tristate/enable and simple input.
   SB_IO #(.PIN_TYPE(6'b1010_01), .PULLUP(1'b0))
     io_Dn[DW-1:0](.PACKAGE_PIN(aD),
	   .OUTPUT_ENABLE({16{fsmc_io_d_output}}),
	   .D_OUT_0(aDn_output),
	   .D_IN_0(aDn_input)
	   );

   wire 	  sdram_busdir;	// Controls direction of data bus to SDRAM
   wire [DW-1:0]  sdram_o_dq;
   wire [DW-1:0]  sdram_i_dq;
   SB_IO #(.PIN_TYPE(6'b1010_01), .PULLUP(1'b0))
     io_mem_d[DW-1:0](.PACKAGE_PIN(mem_d),
	   .OUTPUT_ENABLE({16{sdram_busdir}}),
	   .D_OUT_0(sdram_o_dq),
	   .D_IN_0(sdram_i_dq)
	   );


   // Interface to STM32 FSMC.
   wire [AW-1:0] fsmc_r_adr;
   wire [AW-1:0] fsmc_w_adr;
   wire 	 fsmc_do_read;
   wire [DW-1:0] fsmc_r_data;
   wire 	 fsmc_do_write;
   wire [DW-1:0] fsmc_w_data;

   clocked_bus_slave #(.ADRW(AW), .DATW(DW))
     my_bus_slave(aNE, aNOE, aNWE,
		  aA, aDn_input,
		  clk, fsmc_r_adr, fsmc_w_adr,
		  fsmc_do_read, fsmc_r_data,
		  fsmc_do_write, fsmc_w_data,
		  fsmc_io_d_output, aDn_output);


   // SDRAM controller.
   wire 	 sdram_data_valid;
   wire 	 sdram_busy;
   wire 	 sdram_init_done;
   wire 	 sdram_ack;
   wire [12:0] 	 sdram_o_addr;
   wire [1:0] 	 sdram_o_blkaddr;
   wire 	 sdram_casn, sdram_cke, sdram_csn, sdram_dqm, sdram_rasn, sdram_wen, sdram_o_clk;
   reg [DW-1:0]  sdram_data_in;
   reg [DW-1:0]  sdram_data_out;
   reg [26:0] 	 sdram_i_addr;
   reg 		 sdram_adv;
   wire 	 sdram_i_clk;
   wire 	 sdram_rst;
   reg 		 sdram_rwn;

   // Some dummy / not-used sdram controller signals.
   wire 	 sdram_data_req, sdram_write_done, sdram_read_done,
		 sdram_selfrefresh_req, sdram_loadmod_req, sdram_burststop_req,
		 sdram_disable_active, sdram_disable_precharge, sdram_precharge_req,
		 sdram_powerdown, sdram_disable_autorefresh;

   assign mem_a = sdram_o_addr;
   assign mem_ba = sdram_o_blkaddr;
   assign mem_cas = sdram_casn;
   assign mem_cke = sdram_cke;
   assign mem_cs1 = sdram_csn;
   assign mem_cs2 = 1;
   assign mem_dqm = sdram_dqm;
   assign mem_ras = sdram_rasn;
   assign mem_we = sdram_wen;
   assign mem_clk = sdram_o_clk;
   assign sdram_i_clk = clk;
   assign sdram_rst = !st_after_startup;
   assign sdram_selfrefresh_req = 0;
   assign sdram_loadmod_req = 0;
   assign sdram_burststop_req = 0;
   assign sdram_disable_active = 0;
   assign sdram_disable_precharge = 0;
   assign sdram_precharge_req = 0;
   assign sdram_powerdown = 0;
   assign sdram_disable_autorefresh = 0;

   sdram_controller
     sdram(.o_data_valid(sdram_data_valid),
	   .o_data_req(sdram_data_req),
	   .o_busy(sdram_busy),
	   .o_init_done(sdram_init_done),
	   .o_ack(sdram_ack),

           .o_sdram_addr(sdram_o_addr),
	   .o_sdram_blkaddr(sdram_o_blkaddr),
	   .o_sdram_casn(sdram_casn),
	   .o_sdram_cke(sdram_cke),
           .o_sdram_csn(sdram_csn),
	   .o_sdram_dqm(sdram_dqm),
	   .o_sdram_rasn(sdram_rasn),
	   .o_sdram_wen(sdram_wen),
	   .o_sdram_clk(sdram_o_clk),
           .o_write_done(sdram_write_done),
	   .o_read_done(sdram_read_done),

           .i_data(sdram_data_in),
           .o_data(sdram_data_out),
           .i_sdram_dq(sdram_i_dq),
           .o_sdram_dq(sdram_o_dq),
           .o_sdram_busdir(sdram_busdir),

           .i_addr(sdram_i_addr),
	   .i_adv(sdram_adv),
	   .i_clk(sdram_i_clk),
	   .i_rst(sdram_rst),
	   .i_rwn(sdram_rwn),
           .i_selfrefresh_req(sdram_selfrefresh_req),
	   .i_loadmod_req(sdram_loadmod_req),
	   .i_burststop_req(sdram_burststop_req),
	   .i_disable_active(sdram_disable_active),
	   .i_disable_precharge(sdram_disable_precharge),
	   .i_precharge_req(sdram_precharge_req),
	   .i_power_down(sdram_powerdown),
	   .i_disable_autorefresh(sdram_disable_autorefresh));


   reg [26:0] 	 cur_adr; // Value of peripheral register "address" (bits 1..27)
   wire 	 cur_status_busy; // Value of peripheral register "address" (bit 0)
   reg [15:0] 	 cur_value;	// Value of peripheral register "data"
   wire 	 sdram_idle;
   wire 	 decode_adr_low, decode_adr_high, decode_data;
   // State machine states.
   reg 		 st_pending_read, st_doing_read, st_pending_write, st_doing_write;

   // For debugging, can expose signals here on sdram pcb gpio header.
   assign sdram_gpio1 = 1'b0;
   assign sdram_gpio2 = 1'b0;

   // Decode FSMC read request.
   // We have no side effects on reads, so we can ignore fsmc_do_read and just
   // decode combinatorially the read address to provide the data-to-read.
   always @(*) begin
      case (fsmc_r_adr)
	PERIPH_REG_ADR_LOW:
	  fsmc_r_data = {cur_adr[14:0], cur_status_busy};
	PERIPH_REG_ADR_HIGH:
	  fsmc_r_data = {4'b0000, cur_adr[26:15]};
	PERIPH_REG_DATA:
	  fsmc_r_data = cur_value;
	default:
	  fsmc_r_data = 16'd0;
      endcase // case fsmc_r_adr
   end

   assign cur_status_busy = (st_pending_write || st_doing_write ||
			       st_pending_read || st_doing_read);

   // Decode write addresses.
   assign decode_adr_low = (fsmc_w_adr == PERIPH_REG_ADR_LOW);
   assign decode_adr_high = (fsmc_w_adr == PERIPH_REG_ADR_HIGH);
   assign decode_data = (fsmc_w_adr == PERIPH_REG_DATA);

   // Handle FSMC write, as well as updating cur_value from SDRAM read.
   always @(posedge clk) begin
      if (fsmc_do_write && decode_adr_low) begin
	 cur_adr[14:0] <= fsmc_w_data[15:1];
	 // Writes to low address triggers a read/write operation.
	 if (!cur_status_busy) begin
	    // Note: use newly written address low bits fsmc_w_data[15:1], not old!
	    sdram_i_addr <= {27{cur_adr[26:15], fsmc_w_data[15:1]}};
	 if (fsmc_w_data[0]) begin
	       // Start a write.
	       sdram_rwn <= 0;
	       sdram_data_in <= cur_value;
	    end else begin
	       // Start a read.
	       sdram_rwn <= 1;
	    end
	 end
      end

      if (fsmc_do_write && decode_adr_high)
	 cur_adr[26:15] <= fsmc_w_data[11:0];

      if (fsmc_do_write && decode_data)
	cur_value <= fsmc_w_data[15:0];
      else if (st_doing_read && sdram_data_valid)
	 cur_value <= sdram_data_out;
   end

   assign sdram_idle = sdram_init_done && !sdram_busy;

   // Handle address valid (sdram_adv) assertion - this is what starts
   // a request towards the sdram controller.
   // The sdram_adv signal is asserted the cycle after a read/write request
   // from the STM32 has arrived and the sdram controller is idle. It remains
   // asserted until acknowledged by the sdram controller.
   // ToDo: could maybe assert adv already when setting _pending, to
   // allow back-to-back operation and save one clockcycle?
   always @(posedge clk) begin
      if ((st_pending_read || st_pending_write) && sdram_idle)
	sdram_adv <= 1;
      else if ((st_doing_read || st_doing_write) && sdram_ack)
	sdram_adv <= 0;
   end

   // State changes.
   always @(posedge clk) begin
      // Write is triggered by writing a 1 to the low bit of address.
      if (fsmc_do_write && decode_adr_low && !cur_status_busy && fsmc_w_data[0])
	st_pending_write <= 1;
      else if (st_pending_write && sdram_idle)
	st_pending_write <= 0;

      // Read is triggered by writing a 0 to the low bit of address.
      if (fsmc_do_write && decode_adr_low && !cur_status_busy && !fsmc_w_data[0])
	st_pending_read <= 1;
      else if (st_pending_read && sdram_idle)
	st_pending_read <= 0;

      if (st_pending_read && sdram_idle)
	st_doing_read <= 1;
      else if (st_doing_read && sdram_data_valid)
	st_doing_read <= 0;

      if (st_pending_write && sdram_idle)
	st_doing_write <= 1;
      else if (st_doing_write && (sdram_write_done | (sdram_idle && !sdram_adv))) begin
	// For some reason we occasionally seem to miss the sdram_write_done
	// signal here. So added the extra condition (sdram_idle && !sdram_adv)
	// to avoid hanging in this case. Though would be good to find the
	// root cause of this...
	st_doing_write <= 0;
      end
      // Maybe could use sdram_ack instead of sdram_write_done, but let's keep
      // things simple for now. A better write optimisation would anyway be
      // to have a write queue.
   end

endmodule
