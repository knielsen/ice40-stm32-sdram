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
// Description : This is the control FSM for SDR SDRAM. This module consists of both initialization
// as well as data transfer, and refesh control fsms.  
// -------------------------------------------------------------------------------------------------


`timescale 1ns / 100ps

// Macro for SDRAM signals which generates various commands to SDRAM
`define SDR_CMD_SIGNALS  {o_sdram_csn, o_sdram_rasn, o_sdram_casn, o_sdram_wen, sdram_dqm_i}

module sdram_control_fsm (
                          i_clk,
                          i_rst,
                          i_rwn,
                          i_addr,
                          i_adv,
                          i_data,       // data bus
                          o_data,       // data bus
                          o_den,       // data bus
                          o_data_valid, // output data valid, may be used for FIFO writ eenable
                          o_data_req, // input data request, can be used for FIFO read enable 
                          i_delay_done_100us,
                          i_refresh_req,
                          i_selfrefresh_req, // User must meet the minimum requirement
                          i_burststop_req, // User must meet the minimum requirement
                          i_loadmod_req, // Load mode register request
                          i_disable_active, // Disable opening a row, if already opened
                          i_disable_precharge, // Disable precharge, keep open for next read/write
                          i_precharge_req,
                          i_power_down,
                          o_ack,
                          o_autoref_ack,
                          o_busy,
                          o_init_done,
                          o_sdram_cke,    // sdr clock enable
                          o_sdram_csn,    // sdr chip select
                          o_sdram_rasn,   // sdr row address
                          o_sdram_casn,   // sdr column select
                          o_sdram_wen,    // sdr write enable
                          o_sdram_blkaddr,     // sdr bank address
                          o_sdram_addr,       // sdr address
                          //HUSK io_sdram_dq,       // sdr data
                          o_sdram_busdir, //HUSK
                          o_sdram_dq,
                          i_sdram_dq,
                          o_sdram_dqm,       // sdr data
                          o_write_done,      // Write to SDRAM is completed
                          o_read_done        // Read from SDRAM is completed
                          );

`include "sdram_defines.v"

    parameter SDRAM_DATA_WIDTH = 16;
    parameter CPU_ADDR_WIDTH = 24;
    parameter SDRAM_ADDR_WIDTH = 13;
    parameter SDRAM_BLKADR_WIDTH = 2;
    parameter SDRAM_DQM_WIDTH = 2;
    parameter ROWADDR_MSB = 23;
    parameter ROWADDR_LSB = 11;
    parameter AUTO_REFRESH_COUNT = 1500;

    parameter NUM_CLK_WRITE = 4;
    parameter NUM_CLK_READ = 4;
    parameter NUM_CLK_PRECHARGE_PERIOD = 2;
    parameter NUM_CLK_AUTOREFRESH_PERIOD = 7;
    parameter NUM_CLK_LOAD_MODEREG_DELAY = 2;
    parameter NUM_CLK_ACTIVE2RW_DELAY = 2;
    parameter NUM_CLK_CL = 2;
    parameter NUM_CLK_WAIT = 1;
    parameter NUM_CLK_SELFREFRESH2ACTIVE = 5;
    parameter NUM_CLK_WRITE_RECOVERY_DELAY = 2;
    parameter MODEREG_BURST_LENGTH = 3'b010;
    parameter SDRAM_BURST_PAGE = 3'b111;
    parameter MODEREG_WRITE_BURST_MODE = 1'b0;
    parameter MODEREG_OPERATION_MODE = 2'b00;
    parameter MODEREG_CAS_LATENCY = 2;
    parameter MODEREG_BURST_TYPE = 1'b0;   
   
    
    
    /*******************************************************************************
     * Input Ports 
     ******************************************************************************/
    input        i_clk;
    input        i_rst;
    input        i_rwn;
    input        i_adv;
    input        i_delay_done_100us;
    input        i_refresh_req;
    input        i_selfrefresh_req;
    input        i_loadmod_req;
    input        i_burststop_req;
    input        i_disable_active;
    input        i_disable_precharge;
    input        i_precharge_req;
    input        i_power_down;   
    input [ROWADDR_MSB:COLADDR_LSB] i_addr;

    
    /*******************************************************************************
     * Output Ports 
     ******************************************************************************/
    output                          o_ack;
    output                          o_autoref_ack;
    output                          o_busy;
    output                          o_init_done;
    output                          o_sdram_cke;
    output                          o_sdram_csn;
    output                          o_sdram_rasn;
    output                          o_sdram_casn;
    output                          o_sdram_wen;
    output [SDRAM_BLKADR_WIDTH-1:0] o_sdram_blkaddr;
    output [SDRAM_ADDR_WIDTH-1:0]   o_sdram_addr;
    output                          o_data_valid;
    output [SDRAM_DQM_WIDTH-1:0]    o_sdram_dqm;
    output                          o_data_req;
    output                          o_sdram_busdir; //HUSK

    output                           o_write_done;
    output                           o_read_done;
   
   

    /*******************************************************************************
     * Inout Ports 
     ******************************************************************************/
    input [CPU_DATA_WIDTH-1:0]      i_data;
    output [CPU_DATA_WIDTH-1:0]     o_data;
    output                          o_den;
    //HUSK inout [SDRAM_DATA_WIDTH-1:0]    io_sdram_dq;
    input [SDRAM_DATA_WIDTH-1:0] i_sdram_dq;
    output [SDRAM_DATA_WIDTH-1:0] o_sdram_dq;
    
    /*******************************************************************************
     * Registers
     ******************************************************************************/
    reg                             o_init_done;  // indicates sdr initialization is done
    reg [3:0]                       init_fsm_states_i;        // INIT_FSM state variables
    reg [4:0]                       cmd_fsm_states_i;        // CMD_FSM state variables
    reg                             o_ack;
    reg                             o_autoref_ack;
    reg                             o_busy;
    reg                             o_sdram_cke;
    reg                             o_sdram_csn;
    reg                             o_sdram_rasn;
    reg                             o_sdram_casn;
    reg                             o_sdram_wen;
    reg [SDRAM_BLKADR_WIDTH-1:0]    o_sdram_blkaddr;
    reg [SDRAM_ADDR_WIDTH-1:0]      o_sdram_addr;
    reg [3:0]                       clk_count_i;
    reg                             reset_clk_counter_i; // reset clk_count_i to 0
    reg                             sdram_dqm_i;

    reg                             write_done_reg_i;
    reg                             read_done_reg_i;
    reg                             write_done_i;
    reg                             read_done_i;    
    

    assign o_sdram_dqm = {`SDRAM_DQM_LEN{sdram_dqm_i}};
    
    
    /*******************************************************************************
     * Local Definitions
     ******************************************************************************/
`define DONE_PRECHARGE_PERIOD         clk_count_i == NUM_CLK_PRECHARGE_PERIOD
`define DONE_AUTOREFRESH_PERIOD       clk_count_i == NUM_CLK_AUTOREFRESH_PERIOD
`define DONE_LOAD_MODEREG_DELAY       clk_count_i == NUM_CLK_LOAD_MODEREG_DELAY
`define DONE_ACTIVE2RW_DELAY          clk_count_i == NUM_CLK_ACTIVE2RW_DELAY
`define DONE_CAS_LATENCY              clk_count_i == NUM_CLK_CL
`define DONE_READ_BURST               clk_count_i == NUM_CLK_READ - 1
`define DONE_WRITE_BURST              clk_count_i == NUM_CLK_WRITE
`define DONE_DATAIN2ACTIVE            clk_count_i == NUM_CLK_WAIT
`define DONE_SELFREFRESH2ACTIVE_DELAY clk_count_i == NUM_CLK_SELFREFRESH2ACTIVE
`define DONE_WRITE_RECOVERY_DELAY     clk_count_i == NUM_CLK_WRITE_RECOVERY_DELAY


    /*******************************************************************************
     * Write Done and Read Done signals generations
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            write_done_i <= 1'b0;
            read_done_i <= 1'b0; end
        else begin
            if ((`DONE_WRITE_BURST && cmd_fsm_states_i == CMD_STATE_WRITE_DATA) || (i_burststop_req && cmd_fsm_states_i == CMD_STATE_WRITE_DATA)) begin
                write_done_i <= 1'b1;
                read_done_i <= 1'b0;  end
            else if ((`DONE_READ_BURST && cmd_fsm_states_i == CMD_STATE_READ_DATA)|| (i_burststop_req && cmd_fsm_states_i == CMD_STATE_READ_DATA)) begin
                write_done_i <= 1'b0;
                read_done_i <= 1'b1;  end
        end
    end    
           
    always @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            write_done_reg_i <= 1'b0;
            read_done_reg_i <= 1'b0; end
        else begin
            write_done_reg_i <= write_done_i;
            read_done_reg_i <= read_done_i; end
    end
     
    assign o_write_done = write_done_i && (!write_done_reg_i);
    assign o_read_done = read_done_i && (!read_done_reg_i);
   
    /*******************************************************************************
     * Initialization FSM
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if (i_rst) begin
            init_fsm_states_i <= #WIREDLY INIT_STATE_IDLE;
        end else
            case (init_fsm_states_i)
                
                INIT_STATE_IDLE:   // wait for 100 us delay by checking i_delay_done_100us
                    if (i_delay_done_100us) 
                        init_fsm_states_i <= #WIREDLY INIT_STATE_PRECHARGEALL;
                
                INIT_STATE_PRECHARGEALL:   // precharge all
                    init_fsm_states_i <= #WIREDLY (NUM_CLK_PRECHARGE_PERIOD == 0) ? 
                                         INIT_STATE_AUTOREFRESH_1 : INIT_STATE_PRECHARGE_DELAY;
                
                INIT_STATE_PRECHARGE_DELAY:   // wait until PRECHARGE_PERIOD satisfied
                    if (`DONE_PRECHARGE_PERIOD) 
                        init_fsm_states_i <= #WIREDLY INIT_STATE_AUTOREFRESH_1;
                
                INIT_STATE_AUTOREFRESH_1:   // auto referesh
                    init_fsm_states_i <= #WIREDLY (NUM_CLK_AUTOREFRESH_PERIOD == 0) ? 
                                         INIT_STATE_AUTOREFRESH_2 : INIT_STATE_AUTOREFRESH_DELAY_1;
                
                INIT_STATE_AUTOREFRESH_DELAY_1: // wait until AUTOREFRESH_PERIOD satisfied
                    if (`DONE_AUTOREFRESH_PERIOD) 
                        init_fsm_states_i <= #WIREDLY INIT_STATE_AUTOREFRESH_2;
                
                INIT_STATE_AUTOREFRESH_2:   // auto referesh
                    init_fsm_states_i <= #WIREDLY (NUM_CLK_AUTOREFRESH_PERIOD == 0) ? 
                                         INIT_STATE_LOAD_MODEREG : INIT_STATE_AUTOREFRESH_DELAY_2;
                
                INIT_STATE_AUTOREFRESH_DELAY_2: // wait until AUTOREFRESH_PERIOD satisfied
                    if (`DONE_AUTOREFRESH_PERIOD) 
                        init_fsm_states_i <= #WIREDLY INIT_STATE_LOAD_MODEREG;
                
                INIT_STATE_LOAD_MODEREG:   // load mode register
                    init_fsm_states_i <= #WIREDLY (NUM_CLK_LOAD_MODEREG_DELAY == 0) ? 
                                         INIT_STATE_INIT_DONE : INIT_STATE_LOAD_MODEREG_DELAY;
                
                INIT_STATE_LOAD_MODEREG_DELAY:  // wait until LOAD_MODEREG_DELAY satisfied
                    if (`DONE_LOAD_MODEREG_DELAY) 
                        init_fsm_states_i <= #WIREDLY INIT_STATE_INIT_DONE;
                
                INIT_STATE_INIT_DONE: // stay at this state for normal operation
                    init_fsm_states_i <= #WIREDLY INIT_STATE_INIT_DONE;
                
                default:
                    init_fsm_states_i <= #WIREDLY INIT_STATE_IDLE;
                
            endcase
    /*******************************************************************************
     * o_init_done generation
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if (i_rst) begin
            o_init_done <= #WIREDLY 0;
        end else
            case (init_fsm_states_i)
                INIT_STATE_INIT_DONE: o_init_done <= #WIREDLY 1;
                default: o_init_done <= #WIREDLY 0;
            endcase
    
    /*******************************************************************************
     * Command generation FSM
     *******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if (i_rst) begin
            cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
        end else
            case (cmd_fsm_states_i)
                
                CMD_STATE_IDLE:   // wait until refresh, load mode, read/write strobe asserted
                    if (i_selfrefresh_req && o_init_done) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_SELFREFRESH;
                    else if (i_refresh_req && o_init_done) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_AUTOREFRESH;
                    else if (i_loadmod_req && o_init_done && i_adv) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_LOAD_MODEREG;
                    else if (i_precharge_req && o_init_done && i_adv) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_PRECHARGE;
                    else if (i_power_down && o_init_done)
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_POWER_DOWN_MODE;
                    else if (i_adv && o_init_done)
                        if (i_disable_active)
                            cmd_fsm_states_i <= #WIREDLY (i_rwn)?CMD_STATE_READ_AUTOPRECHARGE :
                                                CMD_STATE_WRITE_AUTOPRECHARGE;
                        else
                            cmd_fsm_states_i <= #WIREDLY CMD_STATE_ACTIVE;
                
                CMD_STATE_ACTIVE: // activate row/bank addr
                    if (NUM_CLK_ACTIVE2RW_DELAY == 0)
                        cmd_fsm_states_i <= #WIREDLY (i_rwn) ? CMD_STATE_READ_AUTOPRECHARGE :
                                            CMD_STATE_WRITE_AUTOPRECHARGE;
                    else 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_ACTIVE2RW_DELAY;
                
                CMD_STATE_ACTIVE2RW_DELAY:   // wait until ACTIVE2RW_DELAY satisfied
                    if (`DONE_ACTIVE2RW_DELAY)
                        cmd_fsm_states_i <= #WIREDLY (i_rwn) ? CMD_STATE_READ_AUTOPRECHARGE :
                                            CMD_STATE_WRITE_AUTOPRECHARGE;
                
                CMD_STATE_READ_AUTOPRECHARGE:  // Enable col/bank addr for read with auto-precharge
                    cmd_fsm_states_i <= #WIREDLY CMD_STATE_CAS_LATENCY;
                
                CMD_STATE_CAS_LATENCY:     // Wait for CASn latency
                    if (`DONE_CAS_LATENCY) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_READ_DATA;
                
                CMD_STATE_READ_DATA:  // read data phase
                    if (i_burststop_req) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_BURSTSTOP_READ;
                    else if (`DONE_READ_BURST) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
                
                CMD_STATE_WRITE_AUTOPRECHARGE: // Enable col/bank addr for write with auto-precharge
                    cmd_fsm_states_i <= #WIREDLY CMD_STATE_WRITE_DATA;
                
                CMD_STATE_WRITE_DATA:  // write data phase
                    if (i_burststop_req) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_BURSTSTOP_WRITE;
                    else if (`DONE_WRITE_BURST) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_DATAIN2ACTIVE;
                
                CMD_STATE_DATAIN2ACTIVE:   // Waiit for Data write to Active Delay
                    if (`DONE_DATAIN2ACTIVE) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
                
                CMD_STATE_AUTOREFRESH:     // auto-refresh
                    cmd_fsm_states_i <= #WIREDLY (NUM_CLK_AUTOREFRESH_PERIOD == 0)?CMD_STATE_IDLE : 
                                        CMD_STATE_AUTOREFRESH_DELAY;
                
                CMD_STATE_AUTOREFRESH_DELAY:   // wait until auto refresh period satisfied
                    if (`DONE_AUTOREFRESH_PERIOD) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
                
                CMD_STATE_SELFREFRESH:     // self-refresh
                    if (~i_selfrefresh_req) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_SELFREFRESH_DELAY;
                
                CMD_STATE_SELFREFRESH_DELAY:   // wait until SELFREFRESH to ACTIVE satisfied
                    if (`DONE_SELFREFRESH2ACTIVE_DELAY) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
                
                CMD_STATE_LOAD_MODEREG:   // load mode register
                    cmd_fsm_states_i <= #WIREDLY (NUM_CLK_LOAD_MODEREG_DELAY == 0) ? 
                                        CMD_STATE_IDLE : CMD_STATE_LOAD_MODEREG_DELAY;
                
                CMD_STATE_LOAD_MODEREG_DELAY:  // wait until LOAD_MODEREG_DELAY satisfied
                    if (`DONE_LOAD_MODEREG_DELAY) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
                
                CMD_STATE_BURSTSTOP_WRITE: //Issue Burst Terminate for write
                    cmd_fsm_states_i <= #WIREDLY CMD_STATE_BURSTSTOP_WRITE_DELAY;
                
                CMD_STATE_BURSTSTOP_WRITE_DELAY: //Wait for write recovery time to satisfy
                    if (`DONE_WRITE_RECOVERY_DELAY)
                        if (!i_disable_precharge)
                            cmd_fsm_states_i <= #WIREDLY CMD_STATE_PRECHARGE;
                        else
                            cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
                
                CMD_STATE_BURSTSTOP_READ: // Issue Burst terminate for read
                    cmd_fsm_states_i <= #WIREDLY CMD_STATE_BURSTSTOP_READ_DELAY;
                
                CMD_STATE_BURSTSTOP_READ_DELAY: //Wait for CAS cycles to flush remaining data
                    if (`DONE_CAS_LATENCY) 
                        if (!i_disable_precharge)
                            cmd_fsm_states_i <= #WIREDLY CMD_STATE_PRECHARGE;
                        else
                            cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
                
                CMD_STATE_PRECHARGE: //Precharge - Only used in conjunction with page read/write
                    cmd_fsm_states_i <= #WIREDLY CMD_STATE_PRECHARGE_DELAY;
                
                CMD_STATE_PRECHARGE_DELAY: //Satisfy precharge period
                    if (`DONE_PRECHARGE_PERIOD) 
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
              
                CMD_STATE_POWER_DOWN_MODE : // Power down mode
                    if (!i_power_down)
                        cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;  
                
                default:
                    cmd_fsm_states_i <= #WIREDLY CMD_STATE_IDLE;
                
            endcase
    
    /*******************************************************************************
     * o_autoref_ack logic
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if (i_rst) begin
            o_autoref_ack <= #WIREDLY 0;
        end else
            case (cmd_fsm_states_i)
                CMD_STATE_AUTOREFRESH:
                    o_autoref_ack      <= #WIREDLY 1;
                default:
                    o_autoref_ack <= #WIREDLY 0;
                
            endcase
    
    /*******************************************************************************
     * o_ack logic
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if (i_rst) begin
            o_ack <= #WIREDLY 0;
        end else
            case (cmd_fsm_states_i)
                CMD_STATE_IDLE:
                    if (i_precharge_req) 
                        o_ack      <= #WIREDLY 1;

                CMD_STATE_BURSTSTOP_WRITE,
                CMD_STATE_BURSTSTOP_READ,
                CMD_STATE_SELFREFRESH,
                CMD_STATE_READ_AUTOPRECHARGE,
                CMD_STATE_WRITE_AUTOPRECHARGE,
                CMD_STATE_POWER_DOWN_MODE,
                CMD_STATE_LOAD_MODEREG:
                    o_ack      <= #WIREDLY 1;
                
                default:
                    o_ack <= #WIREDLY 0;
                
            endcase
    
    /*******************************************************************************
     * o_busy logic
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if (i_rst) begin
            o_busy <= #WIREDLY 0;
        end else
            case (cmd_fsm_states_i)
                
                CMD_STATE_IDLE:
                    if (o_init_done) begin
                        if (i_refresh_req || i_loadmod_req || i_precharge_req || i_adv) 
                            o_busy <= #WIREDLY 1;
                        else 
                            o_busy <= #WIREDLY 0;
                    end

                
                CMD_STATE_ACTIVE,
                    CMD_STATE_ACTIVE2RW_DELAY,
                    CMD_STATE_READ_AUTOPRECHARGE,
                    CMD_STATE_CAS_LATENCY,
                    CMD_STATE_WRITE_AUTOPRECHARGE,
                    CMD_STATE_WRITE_DATA,
                    CMD_STATE_AUTOREFRESH,
                    CMD_STATE_SELFREFRESH,
                    CMD_STATE_BURSTSTOP_WRITE,
                    CMD_STATE_PRECHARGE,
                    CMD_STATE_LOAD_MODEREG,
                    CMD_STATE_BURSTSTOP_READ_DELAY,
                    CMD_STATE_BURSTSTOP_WRITE_DELAY,
                    CMD_STATE_BURSTSTOP_READ,
                    CMD_STATE_READ_DATA,
                    CMD_STATE_DATAIN2ACTIVE,
                    CMD_STATE_LOAD_MODEREG_DELAY,
                    CMD_STATE_AUTOREFRESH_DELAY,
                    CMD_STATE_PRECHARGE_DELAY,
                    CMD_STATE_POWER_DOWN_MODE,
                    CMD_STATE_SELFREFRESH_DELAY:
                        o_busy <= #WIREDLY 1;
                
                default:
                    o_busy <= #WIREDLY 0;
                
            endcase
    /*******************************************************************************
     * Clock Counter for generating various delays
     ******************************************************************************/
    always @(posedge i_clk)
        if (reset_clk_counter_i) 
            clk_count_i <= #WIREDLY 0;
        else 
            clk_count_i <= #WIREDLY clk_count_i + 1;

    /*******************************************************************************
     * Reset Clock Counter generating logic
     ******************************************************************************/
    always @(init_fsm_states_i or cmd_fsm_states_i or clk_count_i or i_burststop_req)
        case (init_fsm_states_i)
            
            INIT_STATE_PRECHARGEALL:
                reset_clk_counter_i <= #WIREDLY (NUM_CLK_PRECHARGE_PERIOD == 0) ? 1 : 0;
            
            INIT_STATE_AUTOREFRESH_1,
                INIT_STATE_AUTOREFRESH_2:
                    reset_clk_counter_i <= #WIREDLY (NUM_CLK_AUTOREFRESH_PERIOD == 0) ? 1 : 0;
            
            INIT_STATE_IDLE:
                reset_clk_counter_i <= #WIREDLY 1;
            
            INIT_STATE_PRECHARGE_DELAY:
                reset_clk_counter_i <= #WIREDLY (`DONE_PRECHARGE_PERIOD) ? 1 : 0;
            
            INIT_STATE_LOAD_MODEREG_DELAY:
                reset_clk_counter_i <= #WIREDLY (`DONE_LOAD_MODEREG_DELAY) ? 1 : 0;
            
            INIT_STATE_AUTOREFRESH_DELAY_1,
                INIT_STATE_AUTOREFRESH_DELAY_2:
                    reset_clk_counter_i <= #WIREDLY (`DONE_AUTOREFRESH_PERIOD) ? 1 : 0;
            
            INIT_STATE_INIT_DONE:
                case (cmd_fsm_states_i)
                    
                    CMD_STATE_ACTIVE:
                        reset_clk_counter_i <= #WIREDLY (NUM_CLK_ACTIVE2RW_DELAY == 0) ? 1 : 0;
                    
                    CMD_STATE_IDLE:
                        reset_clk_counter_i <= #WIREDLY 1;
                    
                    CMD_STATE_ACTIVE2RW_DELAY:
                        reset_clk_counter_i <= #WIREDLY (`DONE_ACTIVE2RW_DELAY) ? 1 : 0;
                    
                    CMD_STATE_AUTOREFRESH_DELAY:
                        reset_clk_counter_i <= #WIREDLY (`DONE_AUTOREFRESH_PERIOD) ? 1 : 0;
                    
                    CMD_STATE_SELFREFRESH:
                        reset_clk_counter_i <= #WIREDLY 1;
                    
                    CMD_STATE_SELFREFRESH_DELAY:
                        reset_clk_counter_i <= #WIREDLY (`DONE_SELFREFRESH2ACTIVE_DELAY) ? 1 : 0;
                    
                    CMD_STATE_CAS_LATENCY:
                        reset_clk_counter_i <= #WIREDLY (`DONE_CAS_LATENCY) ? 1 : 0;
                    
                    CMD_STATE_READ_DATA:
                        reset_clk_counter_i <= #WIREDLY (clk_count_i == NUM_CLK_READ) ? 1 : 0;
                    
                    CMD_STATE_WRITE_DATA:
                        reset_clk_counter_i <= #WIREDLY ((`DONE_WRITE_BURST) || (i_burststop_req)) ?
                                               1 : 0;

                    CMD_STATE_LOAD_MODEREG_DELAY:
                        reset_clk_counter_i <= #WIREDLY (`DONE_LOAD_MODEREG_DELAY) ? 1 : 0;
                    
                    CMD_STATE_BURSTSTOP_WRITE:
                        reset_clk_counter_i <= #WIREDLY 1;

                    CMD_STATE_BURSTSTOP_WRITE_DELAY:
                        reset_clk_counter_i <= #WIREDLY (`DONE_WRITE_RECOVERY_DELAY) ? 1 : 0;

                    CMD_STATE_BURSTSTOP_READ:
                        reset_clk_counter_i <= #WIREDLY 1;

                    CMD_STATE_BURSTSTOP_READ_DELAY:
                        reset_clk_counter_i <= #WIREDLY (`DONE_CAS_LATENCY) ? 1 : 0;

                    CMD_STATE_PRECHARGE:
                        reset_clk_counter_i <= #WIREDLY (`DONE_PRECHARGE_PERIOD) ? 1 : 0;

                    default:
                        reset_clk_counter_i <= #WIREDLY 0;
                    
                endcase
            
            default:
                reset_clk_counter_i <= #WIREDLY 0;
            
        endcase
    /*******************************************************************************
     *  Data path specific statements - responsible for generating output enable
     *  pushing data to SDRAM bus and to CPU bus, as well serial to parallel conversion 
     *  for x4 and x8 SDRAMs. CPU bus width remains at x16 even for SDRAM DQ width 
     * x4 and x8. 
     ******************************************************************************/
    reg [CPU_DATA_WIDTH-1:0]   sdram_dq_reg_i;
    reg                        cpu_den_i;
    reg [CPU_DATA_WIDTH-1:0]   cpu_data_reg_i;
    reg [SDRAM_DATA_WIDTH-1:0] cpu2sdram_reg_i;
    reg                        sdram_dq_en_i;


    wire [SDRAM_DATA_WIDTH-1:0] sdram_dq_reg0_i ;
    wire [SDRAM_DATA_WIDTH-1:0] sdram_dq_reg1_i ;
    wire [SDRAM_DATA_WIDTH-1:0] sdram_dq_reg2_i ;
    wire [SDRAM_DATA_WIDTH-1:0] sdram_dq_reg3_i ;
    
    /*******************************************************************************
     * READ DATA PATH LOGIC STARTS HERE
     ******************************************************************************/
    /*******************************************************************************
     * o_data_valid generation for CPU. CPU can use it as a WEN for its buffer
     ******************************************************************************/
    assign #WIREDLY o_data_valid = cpu_den_i;

    /*******************************************************************************
     * Tristate output under idle conditions 
     ******************************************************************************/
    assign #WIREDLY o_data = sdram_dq_reg_i;
    assign #WIREDLY o_den  = cpu_den_i;

    /*******************************************************************************
     * registering sdram data bus output to cpu
     ******************************************************************************/
    always @(posedge i_clk )//or posedge i_rst)
        //if (i_rst)
        //    sdram_dq_reg_i <= #WIREDLY {`CPU_DBUS_LEN{1'b0}};
        //else
            sdram_dq_reg_i <= #WIREDLY i_sdram_dq; //HUSK io_sdram_dq;


    /*******************************************************************************
     * Tristate Control/output enable logic for CPU data bus
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if (i_rst)
            cpu_den_i <= #WIREDLY 0;
        else if ((cmd_fsm_states_i == CMD_STATE_READ_DATA) || 
                 (cmd_fsm_states_i == CMD_STATE_BURSTSTOP_READ) || 
                 (cmd_fsm_states_i == CMD_STATE_BURSTSTOP_READ_DELAY))
            cpu_den_i <= #WIREDLY 1;
        else    
            cpu_den_i <= #WIREDLY 0;
    

    /*******************************************************************************
     * READ DATA PATH LOGIC STARTS HERE
     ******************************************************************************/
    /*******************************************************************************
     * Tristate/Enabling of SDRAM Data bus based on read/write operation
     ******************************************************************************/
    assign #WIREDLY o_sdram_dq = i_data; //HUSK (sdram_dq_en_i) ? i_data/*cpu_data_reg_i*/  : {`SDRAM_DBUS_LEN{1'bz}};//cpu2sdram_reg_i : {`SDRAM_DBUS_LEN{1'bz}};
    assign o_sdram_busdir = sdram_dq_en_i;

    /*******************************************************************************
     * Registering input data and then fed to SDRAM bus for write
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if (i_rst)
            cpu2sdram_reg_i <= #WIREDLY {`SDRAM_DBUS_LEN{1'b0}};
        else 
            cpu2sdram_reg_i <= #WIREDLY cpu_data_reg_i;

    /*******************************************************************************
     * Control Logic to tristate SDRAM DQ bus
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if  (i_rst)
            sdram_dq_en_i <= #WIREDLY 0;
        else if (cmd_fsm_states_i == CMD_STATE_WRITE_AUTOPRECHARGE)
            sdram_dq_en_i <= #WIREDLY 1;
        else if (cmd_fsm_states_i == CMD_STATE_READ_AUTOPRECHARGE)
            sdram_dq_en_i <= #WIREDLY 0;

    /*******************************************************************************
     * Register data from CPU bus
     ******************************************************************************/
    always @(posedge i_clk or posedge i_rst)
        if (i_rst)
            cpu_data_reg_i <= #WIREDLY {`CPU_DBUS_LEN{1'b0}};
        else    
            cpu_data_reg_i <= #WIREDLY i_data;

    /*******************************************************************************
     * External data read request for SDRAM write, generated in ACTIVE2RW Delay state 
     * and continues till WRITE state
     * This is bit messy as we are not sure how much time in advance we need to 
     * issue a data request to external world as the data availability depends upon 
     * external memory system supplying this data. This module generates the read request 
     * and specifies when excatly it requires the data so that external users of this 
     * design and the control signal must delay the read request apppropriately. 
     ******************************************************************************/
    reg [READ_REQ_CNT_WIDTH -1:0] read_req_cnt_i;
    reg                           read_req_cnt_rst_i;
    reg                           read_data_req_i;
    
    always @(posedge i_clk or posedge i_rst)
        if (i_rst)
            read_req_cnt_rst_i <= #WIREDLY 0;
        else  if ((cmd_fsm_states_i == CMD_STATE_DATAIN2ACTIVE) ||
                  (cmd_fsm_states_i == CMD_STATE_BURSTSTOP_WRITE) ||
                  (cmd_fsm_states_i == CMD_STATE_IDLE))
            read_req_cnt_rst_i <= #WIREDLY 1;
        else
            read_req_cnt_rst_i <= #WIREDLY 0;
    
    always @(posedge i_clk or posedge i_rst)
        if (i_rst)
            read_data_req_i <= #WIREDLY 0;
        else  
            case (cmd_fsm_states_i)
                CMD_STATE_ACTIVE,
                CMD_STATE_ACTIVE2RW_DELAY: 
                    if (!i_rwn) 
                        read_data_req_i      <= #WIREDLY 1;
                CMD_STATE_WRITE_DATA,
                    CMD_STATE_WRITE_AUTOPRECHARGE:
                        read_data_req_i      <= #WIREDLY 1;
                
                default:
                    read_data_req_i <= #WIREDLY 0;
            endcase
    
    always @(posedge i_clk or posedge i_rst)
        if (i_rst)
            read_req_cnt_i <= #WIREDLY {READ_REQ_CNT_WIDTH{1'b1}};
        else if (read_req_cnt_rst_i || i_burststop_req) 
            read_req_cnt_i <= #WIREDLY {READ_REQ_CNT_WIDTH{1'b1}};
        else if (read_data_req_i) 
            read_req_cnt_i <= #WIREDLY read_req_cnt_i + 1;
    
    assign o_data_req =  (read_req_cnt_i < NUM_CLK_WRITE) ? 1 : 0;


    /*******************************************************************************
     * Packing columm address to SDRAM address bus based on sdram column width
     ******************************************************************************/
    wire [12:0]                   col_addr_i;
    
    assign col_addr_i[10] = ((i_disable_precharge) || 
                             (MODEREG_BURST_LENGTH == SDRAM_BURST_PAGE)) ? 1'b0 : 1'b1;
    generate
        if (SDRAM_COL_WIDTH == 8) begin
            assign col_addr_i[9:0] = {2'b00, i_addr[COLADDR_MSB:COLADDR_LSB]};
        end
        else if (SDRAM_COL_WIDTH == 9) begin
            assign col_addr_i[9:0] = {1'b0, i_addr[COLADDR_MSB:COLADDR_LSB]};
        end
        else if (SDRAM_COL_WIDTH == 10) begin
            assign col_addr_i[9:0] = i_addr[COLADDR_MSB:COLADDR_LSB];
        end
        else if (SDRAM_COL_WIDTH == 11) begin
            assign col_addr_i[11] = i_addr[COLADDR_MSB];
            assign col_addr_i[9:0] = i_addr[COLADDR_MSB-1:COLADDR_LSB];
        end
        else if (SDRAM_COL_WIDTH == 12) begin
            assign col_addr_i[12:11] = i_addr[COLADDR_MSB:COLADDR_MSB-1];
            assign col_addr_i[9:0] = i_addr[COLADDR_MSB-2:COLADDR_LSB];
        end
    endgenerate
    
    

    /*******************************************************************************
     * CONTROL SIGNAL Generation to SDRAM based on commands/operation 
     * Also, places right values on SDRAM address bus for these commands. 
     ******************************************************************************/
    always @(posedge i_clk )//or posedge i_rst)
        if (i_rst) begin
        end else
            
            case (init_fsm_states_i)
                INIT_STATE_PRECHARGE_DELAY,
                INIT_STATE_AUTOREFRESH_DELAY_1,
                INIT_STATE_AUTOREFRESH_DELAY_2,
                INIT_STATE_LOAD_MODEREG_DELAY,
                INIT_STATE_IDLE: begin
                    `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_NOP;
                    o_sdram_cke <= #WIREDLY 1;
                    o_sdram_blkaddr  <= #WIREDLY 2'b11;
                    o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};
                end
                
                INIT_STATE_PRECHARGEALL: begin
                    `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_PRECHARGE;
                    o_sdram_cke <= #WIREDLY 1;
                    o_sdram_blkaddr  <= #WIREDLY 2'b11;
                    o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};
                end
                
                INIT_STATE_AUTOREFRESH_1,
                    INIT_STATE_AUTOREFRESH_2: begin
                        `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_AUTOREFRESH;
                        o_sdram_cke <= #WIREDLY 1;
                        o_sdram_blkaddr  <= #WIREDLY 2'b11;
                        o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};
                    end
                
                INIT_STATE_LOAD_MODEREG: begin
                    `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_LOAD_MODEREG;
                    o_sdram_cke <= #WIREDLY 1;
                    o_sdram_blkaddr  <= #WIREDLY 2'b00;
                    o_sdram_addr   <= #WIREDLY {
                                                2'b00,
                                                MODEREG_WRITE_BURST_MODE,
                                                MODEREG_OPERATION_MODE,
                                                MODEREG_CAS_LATENCY,
                                                MODEREG_BURST_TYPE,
                                                MODEREG_BURST_LENGTH
                                                };
                end
                
                INIT_STATE_INIT_DONE:
                    case (cmd_fsm_states_i)
                        
                        CMD_STATE_IDLE,
                        CMD_STATE_ACTIVE2RW_DELAY,
                        CMD_STATE_AUTOREFRESH_DELAY,
                        CMD_STATE_SELFREFRESH_DELAY,
                        CMD_STATE_CAS_LATENCY,
                        CMD_STATE_READ_DATA,
                        CMD_STATE_BURSTSTOP_WRITE_DELAY,
                        CMD_STATE_BURSTSTOP_READ_DELAY,
                        CMD_STATE_WRITE_DATA:  begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_NOP;
                            o_sdram_cke <= #WIREDLY 1;
                            o_sdram_blkaddr  <= #WIREDLY 2'b11;
                            o_sdram_addr   <= #WIREDLY  {`SDRAM_ABUS_LEN{1'b1}};
                        end
                        
                        CMD_STATE_ACTIVE: begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_ACTIVE;
                            o_sdram_cke <= #WIREDLY 1;
                            o_sdram_blkaddr  <= #WIREDLY i_addr[BLKADDR_MSB:BLKADDR_LSB];//bank
                            o_sdram_addr   <= #WIREDLY i_addr[ROWADDR_MSB:ROWADDR_LSB];//row
                        end
                        
                        CMD_STATE_READ_AUTOPRECHARGE:  begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_READ;
                            o_sdram_cke <= #WIREDLY 1;
                            o_sdram_blkaddr  <= #WIREDLY i_addr[BLKADDR_MSB:BLKADDR_LSB];//bank
                            o_sdram_addr[`SDRAM_ABUS_LEN - 1:0]   <= #WIREDLY col_addr_i;
                        end
                        
                        CMD_STATE_WRITE_AUTOPRECHARGE: begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_WRITE;
                            o_sdram_cke <= #WIREDLY 1;
                            o_sdram_blkaddr  <= #WIREDLY i_addr[BLKADDR_MSB:BLKADDR_LSB];//bank
                            o_sdram_addr[`SDRAM_ABUS_LEN - 1:0]   <= #WIREDLY col_addr_i;
                        end
                        
                        CMD_STATE_AUTOREFRESH:     begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_AUTOREFRESH;
                            o_sdram_cke <= #WIREDLY 1;
                            o_sdram_blkaddr  <= #WIREDLY 2'b11;
                            o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};
                        end

                        CMD_STATE_SELFREFRESH:     begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_SELFREFRESH;
                            o_sdram_cke <= #WIREDLY 0;
                            o_sdram_blkaddr  <= #WIREDLY 2'b11;
                            o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};
                        end

                        //Takes the MODE REG values from cpu address bus
                        //It is user's responsibility to fill in right values for the
                        //Mode Reg configuration while requesting i_modreg_req
                        CMD_STATE_LOAD_MODEREG: begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_LOAD_MODEREG;
                            o_sdram_cke <= #WIREDLY 1;
                            o_sdram_blkaddr  <= #WIREDLY 2'b00;
                            o_sdram_addr   <= #WIREDLY i_addr[`SDRAM_ABUS_LEN - 1 : 0];
                        end
                        
                        CMD_STATE_PRECHARGE: begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_PRECHARGE;
                            o_sdram_cke <= #WIREDLY 1;
                            o_sdram_blkaddr  <= #WIREDLY  2'b11;
                            o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};
                        end
                        
                        CMD_STATE_BURSTSTOP_READ,
                            CMD_STATE_BURSTSTOP_WRITE: begin
                                `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_BURSTSTOP;
                                o_sdram_cke <= #WIREDLY 1;
                                o_sdram_blkaddr  <= #WIREDLY  2'b11;
                                o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};
                            end
                        
                        CMD_STATE_BURSTSTOP_READ_DELAY,
                            CMD_STATE_BURSTSTOP_WRITE_DELAY: begin
                                `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_NOP;
                                o_sdram_cke <= #WIREDLY 1;
                                o_sdram_blkaddr  <= #WIREDLY  2'b11;
                                o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};
                            end

                        CMD_STATE_POWER_DOWN_MODE: begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_NOP;
                            o_sdram_cke <= #WIREDLY 0;
                            o_sdram_blkaddr  <= #WIREDLY 2'b11;
                            o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};      
                            end
                     
                        default:  begin
                            `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_NOP;
                            o_sdram_cke <= #WIREDLY 1;
                            o_sdram_blkaddr  <= #WIREDLY 2'b11;
                            o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}}; 
                        end
                        
                    endcase
                
                default:
                    begin
                        `SDR_CMD_SIGNALS <= #WIREDLY SDRAM_CMD_NOP;
                        o_sdram_cke <= #WIREDLY 1;
                        o_sdram_blkaddr  <= #WIREDLY 2'b11;
                        o_sdram_addr   <= #WIREDLY {`SDRAM_ABUS_LEN{1'b1}};
                    end
                
            endcase

    /*AUTOASCIIENUM("cmd_fsm_states_i" "state_ASCII")*/
    // Beginning of automatic ASCII enum decoding
    reg [275:0]         state_ASCII;            // Decode of cmd_fsm_states_i
    always @(cmd_fsm_states_i) begin
       case ({cmd_fsm_states_i})
         CMD_STATE_IDLE                  :  state_ASCII = "CMD_STATE_IDLE                    ";
         CMD_STATE_ACTIVE2RW_DELAY       :  state_ASCII = "CMD_STATE_ACTIVE2RW_DELAY         ";
         CMD_STATE_CAS_LATENCY           :  state_ASCII = "CMD_STATE_CAS_LATENCY             ";
         CMD_STATE_READ_DATA             :  state_ASCII = "CMD_STATE_READ_DATA               ";
         CMD_STATE_WRITE_DATA            :  state_ASCII = "CMD_STATE_WRITE_DATA              ";
         CMD_STATE_AUTOREFRESH_DELAY     :  state_ASCII = "CMD_STATE_AUTOREFRESH_DELAY       ";
         CMD_STATE_DATAIN2ACTIVE         :  state_ASCII = "CMD_STATE_DATAIN2ACTIVE           ";
         CMD_STATE_ACTIVE                :  state_ASCII = "CMD_STATE_ACTIVE                  ";
         CMD_STATE_READ_AUTOPRECHARGE    :  state_ASCII = "CMD_STATE_READ_AUTOPRECHARGE      ";      
         CMD_STATE_WRITE_AUTOPRECHARGE   :  state_ASCII = "CMD_STATE_WRITE_AUTOPRECHARGE     ";   
         CMD_STATE_AUTOREFRESH           :  state_ASCII = "CMD_STATE_AUTOREFRESH             ";    
         CMD_STATE_LOAD_MODEREG          :  state_ASCII = "CMD_STATE_LOAD_MODEREG            ";   
         CMD_STATE_LOAD_MODEREG_DELAY    :  state_ASCII = "CMD_STATE_LOAD_MODEREG_DELAY      ";   
         CMD_STATE_SELFREFRESH           :  state_ASCII = "CMD_STATE_SELFREFRESH             ";   
         CMD_STATE_SELFREFRESH_DELAY     :  state_ASCII = "CMD_STATE_SELFREFRESH_DELAY       ";   
         CMD_STATE_BURSTSTOP_WRITE       :  state_ASCII = "CMD_STATE_BURSTSTOP_WRITE         ";   
         CMD_STATE_BURSTSTOP_WRITE_DELAY :  state_ASCII = "CMD_STATE_BURSTSTOP_WRITE_DELAY   ";   
         CMD_STATE_BURSTSTOP_READ        :  state_ASCII = "CMD_STATE_BURSTSTOP_READ          ";   
         CMD_STATE_BURSTSTOP_READ_DELAY  :  state_ASCII = "CMD_STATE_BURSTSTOP_READ_DELAY    ";   
         CMD_STATE_PRECHARGE             :  state_ASCII = "CMD_STATE_PRECHARGE               ";    
         CMD_STATE_PRECHARGE_DELAY       :  state_ASCII = "CMD_STATE_PRECHARGE_DELAY         ";
         CMD_STATE_POWER_DOWN_MODE       :  state_ASCII = "CMD_STATE_POWER_DOWN_MODE         ";
         
         
         default:                  state_ASCII = "%Error                ";
       endcase
    end
    // End of automatics   
endmodule

