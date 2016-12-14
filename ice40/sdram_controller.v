//   ==================================================================
//   >>>>>>>>>>>>>>>>>>>>>>> COPYRIGHT NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<
//   ------------------------------------------------------------------
//   Copyright (c) 2013 by Lattice Semiconductor Corporation
//   ALL RIGHTS RESERVED 
//   ------------------------------------------------------------------
//
//   Permission:
//
//      Lattice SG Pte. Ltd. grants permission to use this code
//      pursuant to the terms of the Lattice Reference Design License Agreement. 
//
//
//   Disclaimer:
//
//      This VHDL or Verilog source code is intended as a design reference
//      which illustrates how these types of functions can be implemented.
//      It is the user's responsibility to verify their design for
//      consistency and functionality through the use of formal
//      verification methods.  Lattice provides no warranty
//      regarding the use or functionality of this code.
//
//   --------------------------------------------------------------------
//
//                  Lattice SG Pte. Ltd.
//                  101 Thomson Road, United Square #07-02 
//                  Singapore 307591
//
//
//                  TEL: 1-800-Lattice (USA and Canada)
//                       +65-6631-2000 (Singapore)
//                       +1-503-268-8001 (other locations)
//
//                  web: http://www.latticesemi.com/
//                  email: techsupport@latticesemi.com
//
//   --------------------------------------------------------------------
//


//--------------------------------------------------------------------------------------------------
// Description : This is the SDRAM control module, which instantiates SDRAM initilization and 
//               Read/Write Control FSM, 150us delay generator and Auto Refresh control signal 
//               generator. Refresh request is latched until SDRAM Control FSM is busy. As soon
//               as refresh request acknowledged by control FSM, this module clears the
//               refresh request. 
// -------------------------------------------------------------------------------------------------


`timescale 1 ns / 1 ps
`define DISABLE_CPU_IO_BUS 0

module sdram_controller (/*AUTOARG*/
                         // Outputs
                         o_data_valid, o_data_req, o_busy, o_init_done, o_ack, 
    
                         o_sdram_addr, o_sdram_blkaddr, o_sdram_casn, o_sdram_cke, 
                         o_sdram_csn, o_sdram_dqm, o_sdram_rasn, o_sdram_wen, o_sdram_clk,
                         o_write_done, o_read_done,

                         // Inouts
`ifdef DISABLE_CPU_IO_BUS
                         i_data, 
                         o_data,
`else
                         io_data, 
`endif 
                         //HUSK io_sdram_dq,
                         i_sdram_dq,
                         o_sdram_dq,
                         o_sdram_busdir,

                         // Inputs
                         i_addr, i_adv, i_clk, i_rst, i_rwn, 
                         i_selfrefresh_req, i_loadmod_req, i_burststop_req, i_disable_active, i_disable_precharge, i_precharge_req, i_power_down, i_disable_autorefresh
                         );

`include "sdram_defines.v"

    parameter SDRAM_BURST_LEN_1            = 3'b000;
    parameter SDRAM_BURST_LEN_2            = 3'b001;
    parameter SDRAM_BURST_LEN_4            = 3'b010;
    parameter SDRAM_BURST_LEN_8            = 3'b011;
   
    parameter SDRAM_BURST_PAGE             = 3'b111;
    defparam U0.SDRAM_BURST_PAGE = SDRAM_BURST_PAGE;
    
    parameter SDRAM_CAS_LATENCY_2          = 3'b010;
    parameter SDRAM_CAS_LATENCY_3          = 3'b011;

    parameter SDRAM_DATA_WIDTH = 16;
    defparam U0.SDRAM_DATA_WIDTH = SDRAM_DATA_WIDTH;

    parameter CPU_ADDR_WIDTH = 22;
    defparam U0.CPU_ADDR_WIDTH = CPU_ADDR_WIDTH;

    parameter SDRAM_ADDR_WIDTH = 12;
    defparam U0.SDRAM_ADDR_WIDTH = SDRAM_ADDR_WIDTH;

    parameter SDRAM_BLKADR_WIDTH = 2;
    defparam U0.SDRAM_BLKADR_WIDTH = SDRAM_BLKADR_WIDTH;

    parameter SDRAM_DQM_WIDTH = 2;
    defparam U0.SDRAM_DQM_WIDTH = SDRAM_DQM_WIDTH;

    parameter ROWADDR_MSB = 22;
    defparam U0.ROWADDR_MSB = ROWADDR_MSB;
   
    parameter ROWADDR_LSB = 10;
    defparam U0.ROWADDR_LSB = ROWADDR_LSB;

    parameter MODEREG_CAS_LATENCY = 2;
    defparam U0.MODEREG_CAS_LATENCY = MODEREG_CAS_LATENCY;

    parameter MODEREG_BURST_LENGTH = 3'b010;
    defparam U0.MODEREG_BURST_LENGTH = MODEREG_BURST_LENGTH;

    parameter MODEREG_BURST_TYPE = 1'b0;
    defparam U0.MODEREG_BURST_TYPE = MODEREG_BURST_TYPE;
   
    parameter MODEREG_OPERATION_MODE = 2'b00;
    defparam U0.MODEREG_OPERATION_MODE = MODEREG_OPERATION_MODE;

    parameter MODEREG_WRITE_BURST_MODE = 1'b0;
    defparam U0.MODEREG_WRITE_BURST_MODE = MODEREG_WRITE_BURST_MODE;
   
    parameter SDRAM_PAGE_LEN = 256;
       
    parameter CLK_PERIOD = 10;
    
    parameter LOAD_MODEREG_DELAY = 2*CLK_PERIOD;
    
    parameter PRECHARE_PERIOD = CLK_PERIOD/2 + 22;
    
    parameter AUTOREFRESH_PERIOD = CLK_PERIOD/2 + 67;
            
    parameter ACTIVE2RW_DELAY = CLK_PERIOD/2 + 22;
            
    parameter WRITE_RECOVERY_DELAY = CLK_PERIOD/2 + CLK_PERIOD + 8;
         
    parameter DATAIN2ACTIVE = CLK_PERIOD/2 + 37;
         
    parameter DATAIN2PRECHARGE = CLK_PERIOD + 14;
         
    parameter LDMODEREG2ACTIVE = 2 * CLK_PERIOD;
         
    parameter SELFREFRESH2ACTIVE_DELAY = CLK_PERIOD + 44;
    
    parameter NUM_CLK_CL    = (MODEREG_CAS_LATENCY == SDRAM_CAS_LATENCY_2 ) ? 2 :
                              (MODEREG_CAS_LATENCY == SDRAM_CAS_LATENCY_3) ? 3 :
                              3;  // default, for CAS_LATENCY_3
    defparam U0.NUM_CLK_CL = NUM_CLK_CL;

    parameter NUM_CLK_READ  = (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_1) ? 1 :
                              (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_2) ? 2 :
                              (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_4) ? 4 :
                              (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_8) ? 8 :
                              (MODEREG_BURST_LENGTH == SDRAM_BURST_PAGE) ? SDRAM_PAGE_LEN :
                              4; // default, for SDRAM_BURST_LEN_4
    defparam U0.NUM_CLK_READ = NUM_CLK_READ;
   
    parameter NUM_CLK_WRITE  = (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_1) ? 1 :
                               (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_2) ? 2 :
                               (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_4) ? 4 :
                               (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_8) ? 8 :
                               (MODEREG_BURST_LENGTH == SDRAM_BURST_PAGE) ? SDRAM_PAGE_LEN :
                               4; // default, for SDRAM_BURST_LEN_4
    defparam U0.NUM_CLK_WRITE = NUM_CLK_WRITE;
      
    parameter AUTO_REFRESH_COUNT = 1500;
    defparam U2.AUTO_REFRESH_COUNT = AUTO_REFRESH_COUNT;

    parameter NUM_CLK_LOAD_MODEREG_DELAY = LOAD_MODEREG_DELAY/CLK_PERIOD;
    parameter NUM_CLK_PRECHARGE_PERIOD    = PRECHARE_PERIOD/CLK_PERIOD;
    parameter NUM_CLK_AUTOREFRESH_PERIOD = AUTOREFRESH_PERIOD/CLK_PERIOD;
    parameter NUM_CLK_ACTIVE2RW_DELAY    = ACTIVE2RW_DELAY/CLK_PERIOD;
    parameter NUM_CLK_DATAIN2ACTIVE      = DATAIN2ACTIVE/CLK_PERIOD;
    parameter NUM_CLK_DATAIN2PRECHARGE   = DATAIN2PRECHARGE/CLK_PERIOD;
    parameter NUM_CLK_LDMODEREG2ACTIVE   = LDMODEREG2ACTIVE/CLK_PERIOD;
    parameter NUM_CLK_SELFREFRESH2ACTIVE = SELFREFRESH2ACTIVE_DELAY/CLK_PERIOD;
    parameter NUM_CLK_WRITE_RECOVERY_DELAY   = WRITE_RECOVERY_DELAY/CLK_PERIOD;

    parameter NUM_CLK_WAIT = (NUM_CLK_DATAIN2ACTIVE < 3) ? 0 : NUM_CLK_DATAIN2ACTIVE - 3;    
    defparam U0.NUM_CLK_WAIT = NUM_CLK_WAIT;

   
    /*AUTOINPUT*/
    // Beginning of automatic inputs (from unused autoinst inputs)
    input [26:0]                    i_addr; // To U0 of sdram_control_fsm.v
    input                           i_adv;             // To U0 of sdram_control_fsm.v
    input                           i_clk;              // To U0 of sdram_control_fsm.v
    input                           i_rst;              // To U0 of sdram_control_fsm.v
    input                           i_rwn;              // To U0 of sdram_control_fsm.v
    input                           i_selfrefresh_req;          // To U0 of sdram_control_fsm.v
    input                           i_loadmod_req;          // To U0 of sdram_control_fsm.v
    input                           i_burststop_req;          // To U0 of sdram_control_fsm.v
    input                           i_disable_active;
    input                           i_disable_precharge;
    input                           i_precharge_req;
    input                           i_power_down;
    input                           i_disable_autorefresh;
   
   
    
    /*AUTOOUTPUT*/
    // End of automatics
    output                          o_data_valid;       // From U0 of sdram_control_fsm.v
    output                          o_data_req;       // From U0 of sdram_control_fsm.v
    output                          o_busy;           // From U0 of sdram_control_fsm.v
    output                          o_init_done;            // From U0 of sdram_control_fsm.v
    output                          o_ack;          // From U0 of sdram_control_fsm.v
    output [12:0]                   o_sdram_addr; // From U0 of sdram_control_fsm.v
    output [1:0]                    o_sdram_blkaddr;// From U0 of sdram_control_fsm.v
    output                          o_sdram_casn;           // From U0 of sdram_control_fsm.v
    output                          o_sdram_cke;            // From U0 of sdram_control_fsm.v
    output                          o_sdram_csn;            // From U0 of sdram_control_fsm.v
    output [3:0]                    o_sdram_dqm;            // From U0 of sdram_control_fsm.v
    output                          o_sdram_rasn;           // From U0 of sdram_control_fsm.v
    output                          o_sdram_wen;            // From U0 of sdram_control_fsm.v
    output                          o_sdram_clk;            // From U0 of sdram_control_fsm.v

    output                          o_write_done;
    output                          o_read_done;
   
    
    /*AUTOINOUT*/
`ifdef DISABLE_CPU_IO_BUS
    input [31:0]                    i_data;            // To/From U0 of sdram_control_fsm.v
    output [31:0]                   o_data;            // To/From U0 of sdram_control_fsm.v
`else
    inout [31:0]                    io_data;            // To/From U0 of sdram_control_fsm.v
`endif
    //HUSK inout [31:0]                    io_sdram_dq;            // To/From U0 of sdram_control_fsm.v
    input [31:0]                    i_sdram_dq;
    output [31:0]                   o_sdram_dq;
    output                          o_sdram_busdir; //HUSK
    
    wire                            delay_done150us_i;     // To U0 of sdram_control_fsm.v
    wire                            refresh_count_done_i;   // From U2 of autorefresh_counter.v
    wire                            autoref_ack_i, init_done_i, sdrctl_busyn_i;
    
    reg                             latch_ref_req_i;
    reg                             refresh_req_i;
    reg                             autorefresh_enable_i;
    wire                            cpu_den_i;
    wire [CPU_DATA_WIDTH-1:0]       cpu_datain_i;            // To/From U0 of sdram_control_fsm.v
    wire [CPU_DATA_WIDTH-1:0]       cpu_dataout_i;            // To/From U0 of sdram_control_fsm.v
    
`ifdef DISABLE_CPU_IO_BUS
    assign #WIREDLY o_data = cpu_dataout_i;
    assign #WIREDLY cpu_datain_i = i_data;
`else 
    assign #WIREDLY io_data = (cpu_den_i) ? cpu_dataout_i : {`CPU_DBUS_LEN{1'bz}};
    assign #WIREDLY cpu_datain_i = io_data;
`endif 


    reg                              power_down_reg1_i;
    reg                              power_down_reg2_i;
    reg                              power_down_reg3_i;
   

    always @(posedge i_clk or posedge i_rst)  begin
        if (i_rst) begin
            power_down_reg1_i <= 1'b0; end
        else begin
            power_down_reg1_i <= i_power_down; end           
    end
           
       
    assign o_sdram_clk = i_clk ? ~(power_down_reg1_i) : 1'b0;
    assign o_init_done = init_done_i;
    assign sys_clk_i = i_clk;
    assign sys_rst_i = i_rst;
    assign o_busy = sdrctl_busyn_i;

    
    
    sdram_control_fsm U0 (/*AUTOINST*/
                          // Outputs
                          .o_ack            (o_ack),
                          .o_autoref_ack            (autoref_ack_i),
                          .o_busy       (sdrctl_busyn_i),
                          .o_init_done          (init_done_i),
                          .o_sdram_cke          (o_sdram_cke),
                          .o_sdram_csn          (o_sdram_csn),
                          .o_sdram_rasn         (o_sdram_rasn),
                          .o_sdram_casn         (o_sdram_casn),
                          .o_sdram_wen          (o_sdram_wen),
                          .o_sdram_blkaddr      (o_sdram_blkaddr[SDRAM_BLKADR_WIDTH-1:0]),
                          .o_sdram_addr         (o_sdram_addr[SDRAM_ADDR_WIDTH-1:0]),
                          .o_data_valid     (o_data_valid),
                          .o_data_req     (o_data_req),
                          .o_sdram_dqm          (o_sdram_dqm[SDRAM_DQM_WIDTH-1:0]),
                          .o_write_done         (o_write_done),
                          .o_read_done          (o_read_done),
                          // Inouts
                          .i_data          (i_data[CPU_DATA_WIDTH-1:0]),
                          .o_data          (cpu_dataout_i[CPU_DATA_WIDTH-1:0]),
                          .o_den           (cpu_den_i),
                          //HUSK .io_sdram_dq          (io_sdram_dq[SDRAM_DATA_WIDTH-1:0]),
                          .o_sdram_busdir     (o_sdram_busdir), //HUSK
                          .o_sdram_dq          (o_sdram_dq[SDRAM_DATA_WIDTH-1:0]),
                          .i_sdram_dq          (i_sdram_dq[SDRAM_DATA_WIDTH-1:0]), 
                          // Inputs
                          .i_clk            (i_clk),
                          .i_rst            (i_rst),
                          .i_rwn            (i_rwn),
                          .i_adv           (i_adv),
                          .i_delay_done_100us   (delay_done150us_i),
                          .i_refresh_req        (refresh_req_i),
                          .i_selfrefresh_req    (i_selfrefresh_req),
                          .i_loadmod_req        (i_loadmod_req),
                          .i_burststop_req      (i_burststop_req),
                          .i_disable_active     (i_disable_active),
                          .i_disable_precharge  (i_disable_precharge),
                          .i_precharge_req      (i_precharge_req),
                          .i_power_down         (i_power_down),
                          .i_addr           (i_addr[ROWADDR_MSB:COLADDR_LSB]));
    
    delay_gen150us U1 (/*AUTOINST*/
                       // Outputs
                       .o_lfsr_256_done (delay_done150us_i),
                       // Inputs
                       .i_sys_clk       (sys_clk_i),
                       .i_sys_rst       (sys_rst_i));

    autorefresh_counter U2(/*AUTOINST*/
                           // Outputs
                           .o_refresh_count_done(refresh_count_done_i),
                           // Inputs
                           .i_sys_clk           (sys_clk_i),
                           .i_sys_rst           (sys_rst_i),
                           .i_autorefresh_enable(autorefresh_enable_i));

    //Latch auto refresh request and clear it after ack 
    always @(posedge i_clk or posedge i_rst)
        if (i_rst)
            latch_ref_req_i <= #WIREDLY 0;
        else if (latch_ref_req_i && autoref_ack_i)  
            latch_ref_req_i <= #WIREDLY 0;
        else
            latch_ref_req_i <= #WIREDLY refresh_count_done_i;
    
    //Issue refresh request when SDRAM Controller initialization done and is not busy
    always @(posedge i_clk or posedge i_rst)
        if (i_rst)
            refresh_req_i <= #WIREDLY 0;
        else if (i_disable_autorefresh)
            refresh_req_i <= #WIREDLY 0;
        else if (init_done_i && ~sdrctl_busyn_i)  
            refresh_req_i <= #WIREDLY latch_ref_req_i;
        else
            refresh_req_i <= #WIREDLY 0;
    
    //Enable auto refresh counter after initialization and not under self refresh state
    always @(posedge i_clk or posedge i_rst)
        if (i_rst)
            autorefresh_enable_i <= #WIREDLY 0;
        else if (init_done_i && ~i_selfrefresh_req)  
            autorefresh_enable_i <= #WIREDLY 1;
        else
            autorefresh_enable_i <= #WIREDLY 0;
    
endmodule // sdram_controller
