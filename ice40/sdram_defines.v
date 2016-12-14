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
// Description :This file defines the parameters used in SDRAM Controller.  
// -------------------------------------------------------------------------------------------------


/*******************************************************************************
 * SDRAM Mode Register parameters 
 *******************************************************************************/
// Write Burst Mode
parameter WRITE_BURST_PROGRAMED_LENGTH = 1'b0;
parameter WRITE_BURST_SINGLE_ACCESS    = 1'b1;

// SDRAM Operation Mode
parameter SDRAM_STANDARD_MODE          = 2'b00;

// CAS Latency
//parameter SDRAM_CAS_LATENCY_2          = 3'b010;
//parameter SDRAM_CAS_LATENCY_3          = 3'b011;

// Burst Type, Note: Interleaved mode doesn't support SDRAM_BURST_PAGE
parameter SDRAM_BURST_SEQUENTIAL       = 1'b0;
parameter SDRAM_BURST_INTERLEAVE       = 1'b1;

// Burst Length
//parameter SDRAM_BURST_LEN_1            = 3'b000;
//parameter SDRAM_BURST_LEN_2            = 3'b001;
//parameter SDRAM_BURST_LEN_4            = 3'b010;
//parameter SDRAM_BURST_LEN_8            = 3'b011;
//parameter SDRAM_BURST_PAGE             = 3'b111;


/*******************************************************************************
 * User configurable SDRAM controller parameters.
 * Mode Register configuration can be done here to set the operating mode.
 *******************************************************************************/
// ModeReg[2:0]
//parameter MODEREG_BURST_LENGTH         =  //SDRAM_BURST_LEN_1;
                                         // SDRAM_BURST_LEN_2;
                                        // SDRAM_BURST_LEN_8;
                                         // SDRAM_BURST_PAGE;
//                                         SDRAM_BURST_LEN_4;

// ModeReg[3]
//parameter MODEREG_BURST_TYPE           = // SDRAM_BURST_INTERLEAVE;
//                                         SDRAM_BURST_SEQUENTIAL;

// ModeReg[6:4]
//parameter MODEREG_CAS_LATENCY          = SDRAM_CAS_LATENCY_2;
                                         //SDRAM_CAS_LATENCY_3;
// ModeReg[8:7]
// Only Standard mode defined now.
//parameter MODEREG_OPERATION_MODE       = SDRAM_STANDARD_MODE;

// ModeReg[9]
//parameter MODEREG_WRITE_BURST_MODE     = // WRITE_BURST_SINGLE_ACCESS;
//                                         WRITE_BURST_PROGRAMED_LENGTH;

/*******************************************************************************
 * SDRAM Commands and relationship with csn, rasn, casn, wen, dqm.
 *******************************************************************************/
parameter SDRAM_CMD_INHIBIT            = 5'b11111; //On Reset 
parameter SDRAM_CMD_NOP                = 5'b01110;
parameter SDRAM_CMD_ACTIVE             = 5'b00111;
parameter SDRAM_CMD_READ               = 5'b01010;
parameter SDRAM_CMD_WRITE              = 5'b01000;
parameter SDRAM_CMD_BURSTSTOP          = 5'b01100;
parameter SDRAM_CMD_PRECHARGE          = 5'b00101;
parameter SDRAM_CMD_AUTOREFRESH        = 5'b00011;
parameter SDRAM_CMD_LOAD_MODEREG       = 5'b00001;
parameter SDRAM_CMD_SELFREFRESH        = 5'b00011; // CKE Low:Self, High: Auto refresh

/*******************************************************************************
 * Command FSM States defined as Gray encoding 
 * Note: SELFREFRESH command must be held HIGH for minimum period specified in the 
 * data sheet. Controller stays in this state as long as self refresh request is high
 *******************************************************************************/
parameter CMD_STATE_IDLE                       = 5'b00000;
parameter CMD_STATE_ACTIVE2RW_DELAY            = 5'b10000;
parameter CMD_STATE_CAS_LATENCY                = 5'b11000;
parameter CMD_STATE_READ_DATA                  = 5'b11100;
parameter CMD_STATE_WRITE_DATA                 = 5'b11110;
parameter CMD_STATE_AUTOREFRESH_DELAY          = 5'b11111;
parameter CMD_STATE_DATAIN2ACTIVE              = 5'b01111;
parameter CMD_STATE_ACTIVE                     = 5'b01110;
parameter CMD_STATE_READ_AUTOPRECHARGE         = 5'b00110;
parameter CMD_STATE_WRITE_AUTOPRECHARGE        = 5'b00010;
parameter CMD_STATE_AUTOREFRESH                = 5'b00011;
parameter CMD_STATE_LOAD_MODEREG               = 5'b01011;
parameter CMD_STATE_LOAD_MODEREG_DELAY         = 5'b01001;
parameter CMD_STATE_SELFREFRESH                = 5'b00001;
parameter CMD_STATE_SELFREFRESH_DELAY          = 5'b00101;
parameter CMD_STATE_BURSTSTOP_WRITE            = 5'b00111;
parameter CMD_STATE_BURSTSTOP_WRITE_DELAY      = 5'b10111;
parameter CMD_STATE_BURSTSTOP_READ             = 5'b10101;
parameter CMD_STATE_BURSTSTOP_READ_DELAY       = 5'b10001;
parameter CMD_STATE_PRECHARGE                  = 5'b11001;
parameter CMD_STATE_PRECHARGE_DELAY            = 5'b11101;
parameter CMD_STATE_POWER_DOWN_MODE            = 5'b01101;

//-- 01101 01100 01000 01010 11010 11011 10011 10010 10110 10100 00100

/*******************************************************************************
 * Initialization FSM States defined as Gray encoding 
 * Note: SELFREFRESH command must be held HIGH for minimum period specified in the 
 * data sheet. Controller stays in this state as long as self refresh request is high
 *******************************************************************************/
parameter INIT_STATE_IDLE                = 4'b0000;
parameter INIT_STATE_PRECHARGEALL        = 4'b0001;
parameter INIT_STATE_PRECHARGE_DELAY     = 4'b0010;
parameter INIT_STATE_AUTOREFRESH_1       = 4'b0011;
parameter INIT_STATE_AUTOREFRESH_DELAY_1 = 4'b0100;
parameter INIT_STATE_AUTOREFRESH_2       = 4'b0101;
parameter INIT_STATE_AUTOREFRESH_DELAY_2 = 4'b0110;
parameter INIT_STATE_LOAD_MODEREG        = 4'b0111;
parameter INIT_STATE_LOAD_MODEREG_DELAY  = 4'b1000;
parameter INIT_STATE_INIT_DONE           = 4'b1001;

/*******************************************************************************
 * SDR SDRAM Bus configuration for various sizes of SDRAMs
 *******************************************************************************
 * Sizexwidth Config     * Refresh *    Row   *   Bank    *   Column    *  DQs
 *******************************************************************************
 64Mbx32 : 512K x 32 x 4 * 4K      * A10 - A0 * BA1 - BA0 * A7 - A0     * DQM0-3
 128Mbx32: 1M x 32 x 4   * 4K      * A11 - A0 * BA1 - BA0 * A7 - A0     * DQM0-3
 256Mbx16: 4M x 16 x 4   * 8K      * A12 - A0 * BA1 - BA0 * A9-A0       * DQML-H
 512Mbx16: 8M x 16 x 4   * 8K      * A12 - A0 * BA0 - BA0 * A9-A0       * DQML-H
 64Mbx4  : 4M x 4 x 4    * 4K      * A11 - A0 * BA0 - BA0 * A9-A0       * DQM
 64Mbx8  : 2M x 8 x 4    * 4K      * A11 - A0 * BA0 - BA0 * A8-A0       * DQM
 64Mbx16 : 1M x 16 x 4   * 4K      * A11 - A0 * BA0 - BA0 * A7-A0       * DQML-H
 *******************************************************************************/

/*******************************************************************************
 * System and SDRAM Bus width mapping and configuration
 * User configurable parameters for SDRAM Controller 
 * 1. Enable `define SDRAM_ADDR_WIDTH_13 when SDRAM Address bus width is 13(A12:A0)
 * This also changes the CPU address bus length to 25
 * 2. Enable `define SDRAM_DATA_WIDTH_32 when SDRAM data bus width is 32
 * This also changes the CPU data bus length to 32, default it is 16.
 * 3. Other parameters user may need to change based on SDRAM configuration are:
 *   a. SDRAM_NUM_DQM : Any of 1, 2 and 4 
 *   b. SDRAM_ADDR_WIDTH : Any of 12 or 13
 *   c. ROWADDR_MSB, ROWADDR_LSB, BLKADDR_MSB, BLKADDR_LSB, COLADDR_MSB, COLADDR_LSB
 *   
 ******************************************************************************/
// Enable/Define appropriate defines here based on SDRAM usage
// Enable/Define this variable only if data width is 32 for SDRAM
// CUP Data bus width also changes to 32 then
//`define SDRAM_DATA_WIDTH_32
`define SDRAM_DATA_WIDTH_16
//`define SDRAM_DATA_WIDTH_8
//`define SDRAM_DATA_WIDTH_4
`ifdef SDRAM_DATA_WIDTH_32
 `define CPU_DBUS_LEN 32
 `define SDRAM_DBUS_LEN 32
`else
   `define CPU_DBUS_LEN 16
 `ifdef SDRAM_DATA_WIDTH_16
   `define SDRAM_DBUS_LEN 16
 `elsif SDRAM_DATA_WIDTH_8
   `define SDRAM_DBUS_LEN 8
   `define CPU_OE_THRESHOLD 1
 `else
   `define SDRAM_DBUS_LEN 4
   `define CPU_OE_THRESHOLD 3 
 `endif
`endif
  //parameter SDRAM_DATA_WIDTH = `SDRAM_DBUS_LEN;
  parameter CPU_DATA_WIDTH = `CPU_DBUS_LEN;


// NOTE: These parametyers are not used by controller. Expected the users of page mode burst
// to issue burst stop at appropriate time
// These defines the page length, which depends upon column width
/* -----\/----- EXCLUDED -----\/-----
`define SDRAM_PAGE_LEN_256
//`define SDRAM_PAGE_LEN_512
//`define SDRAM_PAGE_LEN_1024
`ifdef SDRAM_PAGE_LEN_256
parameter SDRAM_PAGE_LEN = 256;
`else
 `ifdef SDRAM_PAGE_LEN_512
parameter SDRAM_PAGE_LEN = 512;
 `else // !`ifdef SDRAM_PAGE_LEN_512
parameter SDRAM_PAGE_LEN = 1024;
 `endif
`endif
 -----/\----- EXCLUDED -----/\----- */

//`define SDRAM_DQM_WIDTH_1
`define SDRAM_DQM_WIDTH_2
//`define SDRAM_DQM_WIDTH_4
`ifdef SDRAM_DQM_WIDTH_1
 `define SDRAM_DQM_LEN 1
`else
 `ifdef SDRAM_DQM_WIDTH_2
  `define SDRAM_DQM_LEN 2
 `else
  `define SDRAM_DQM_LEN 4
 `endif
`endif
//parameter SDRAM_DQM_WIDTH      = `SDRAM_DQM_LEN;


//parameter SDRAM_ADDR_WIDTH   = 13; // A0-A11
//parameter SDRAM_BLKADR_WIDTH = 2; // BA0,BA1
parameter SDRAM_ROW_WIDTH    = 13; //Can be 13 as well for > 256Mb SDRAMs
parameter SDRAM_COL_WIDTH    = 9; //Can be 7, 10 as well

//parameter ROWADDR_MSB        = SDRAM_COL_WIDTH + SDRAM_BLKADR_WIDTH + SDRAM_ROW_WIDTH - 1; // System address bit 22
//parameter ROWADDR_LSB        = SDRAM_COL_WIDTH + SDRAM_BLKADR_WIDTH; // System address bit 11

parameter BLKADDR_MSB        = SDRAM_COL_WIDTH + 1; // System address bit 10
parameter BLKADDR_LSB        =  SDRAM_COL_WIDTH; // System address bit 9

parameter COLADDR_MSB        =  SDRAM_COL_WIDTH - 1; // System address bit 8
parameter COLADDR_LSB        =  0; // System address bit 0


// Enable/Define this variable only if address width is 13 for SDRAM
// CUP Data bus width also changes to 32 then
//`define SDRAM_ADDR_WIDTH_13
`ifdef SDRAM_ADDR_WIDTH_13
 `define SDRAM_ABUS_LEN 13
`else
 `define SDRAM_ABUS_LEN 12
`endif

//parameter CPU_ADDR_WIDTH   = SDRAM_COL_WIDTH + SDRAM_ROW_WIDTH + SDRAM_BLKADR_WIDTH;
`define CPU_ABUS_LEN CPU_ADDR_WIDTH

/*******************************************************************************
 * SDRAM AC Timing at 100MHz 
 ******************************************************************************/
//parameter CLK_PERIOD            = 10; //tCK
//parameter LOAD_MODEREG_DELAY    = 2*CLK_PERIOD;//8*CLK_PERIOD; // tMRD LOAD MODE REG to ACTIVE or REFRESH
//parameter PRECHARE_PERIOD       = CLK_PERIOD + 14;//CLK_PERIOD/2 + 20; //tRP Precharge Period 
//parameter AUTOREFRESH_PERIOD    = CLK_PERIOD + 65;//CLK_PERIOD/2 + 70; //tRFC Auto Refresh Period
//parameter ACTIVE2RW_DELAY       = CLK_PERIOD + 14;//CLK_PERIOD/2 + 40; //tRCD Active to Read/Write Delay
//parameter WRITE_RECOVERY_DELAY  = CLK_PERIOD + 6;//CLK_PERIOD/2 + CLK_PERIOD + 8; //tWR Write recovery time
//parameter DATAIN2ACTIVE         = 4 * CLK_PERIOD;//5 * CLK_PERIOD; //tDAL DataIn to Active 
//parameter DATAIN2PRECHARGE      = 2 * CLK_PERIOD; //tDPL DataIn to Precharge
//parameter LDMODEREG2ACTIVE      = 2 * CLK_PERIOD; //tMRD Load Mode register to Active/Precharge 
//parameter SELFREFRESH2ACTIVE_DELAY       = CLK_PERIOD + 36;//CLK_PERIOD/2 + 70; //tRAS SelfRefresh to Active delay

/*******************************************************************************
 * SDRAM AC Timing in terms of Clock Cycles 
 ******************************************************************************/
//parameter NUM_CLK_LOAD_MODEREG_DELAY = LOAD_MODEREG_DELAY/CLK_PERIOD;
//parameter NUM_CLK_PRECHARGE_PERIOD    = PRECHARE_PERIOD/CLK_PERIOD;
//parameter NUM_CLK_AUTOREFRESH_PERIOD = AUTOREFRESH_PERIOD/CLK_PERIOD;
//parameter NUM_CLK_ACTIVE2RW_DELAY    = ACTIVE2RW_DELAY/CLK_PERIOD;
//parameter NUM_CLK_DATAIN2ACTIVE      = DATAIN2ACTIVE/CLK_PERIOD;
//parameter NUM_CLK_DATAIN2PRECHARGE   = DATAIN2PRECHARGE/CLK_PERIOD;
//parameter NUM_CLK_LDMODEREG2ACTIVE   = LDMODEREG2ACTIVE/CLK_PERIOD;
//parameter NUM_CLK_SELFREFRESH2ACTIVE = SELFREFRESH2ACTIVE_DELAY/CLK_PERIOD;
//parameter NUM_CLK_WRITE_RECOVERY_DELAY   = WRITE_RECOVERY_DELAY/CLK_PERIOD;

// Number of clock cycles of wait after a DATAIN before issuing SDRAM_CMD_ACTIVE command. 
// This wait is only necessary when SDRAM_CMD_ACTIVE issued after DATAIN 
//parameter NUM_CLK_WAIT = (NUM_CLK_DATAIN2ACTIVE < 3) ? 0 : NUM_CLK_DATAIN2ACTIVE - 3;

// Number of clocks for CAS Latency 
// 2 CAS Latency are supported now : 2 and 3. 
// NOTE: Modify these lines to add any additional CAS Latencies
//parameter NUM_CLK_CL    = (MODEREG_CAS_LATENCY == SDRAM_CAS_LATENCY_2) ? 2 :
//                          (MODEREG_CAS_LATENCY == SDRAM_CAS_LATENCY_3) ? 3 :
//                          3;  // default, for CAS_LATENCY_3

// Number of clocks for burst read based on Burst length
// 4 Burst lengths are supported now : 1, 2, 4, 8 and PAGE
// NOTE: Modify these lines when any more burst lengths need to be supported
//parameter NUM_CLK_READ  = (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_1) ? 1 :
//                          (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_2) ? 2 :
//                          (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_4) ? 4 :
//                          (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_8) ? 8 :
//                          (MODEREG_BURST_LENGTH == SDRAM_BURST_PAGE) ? SDRAM_PAGE_LEN :
//                          4; // default, for SDRAM_BURST_LEN_4

// Number of clocks for burst write based on Burst length
// 4 Burst lengths are supported now : 1, 2, 4, 8 and PAGE
// NOTE: Modify these lines when any more burst lengths need to be supported
//parameter NUM_CLK_WRITE  = (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_1) ? 1 :
//                           (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_2) ? 2 :
//                           (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_4) ? 4 :
//                           (MODEREG_BURST_LENGTH == SDRAM_BURST_LEN_8) ? 8 :
//                           (MODEREG_BURST_LENGTH == SDRAM_BURST_PAGE) ? SDRAM_PAGE_LEN :
//                           4; // default, for SDRAM_BURST_LEN_4

// Used for read request counter
parameter READ_REQ_CNT_WIDTH = 10;

// On Auto-Refresh: From Micron datasheet
// Regardless of device width, the 256Mb SDRAM requires 8,192 AUTO REFRESH cycles 
// every 64ms (commercial and industrial) or 16ms (automotive). Providing a distributed 
// AUTO REFRESH command every 7.813µs (commercial and industrial) or 1.953µs (automotive) 
// will meet the refresh requirement and ensure that each row is refreshed. 
// Alternatively, 8,192 AUTO REFRESH commands can be issued in a burst at the minimum 
// cycle rate (tRFC), once every 64ms (commercial and industrial) or 16ms (automotive).
// It holds good for 512Mbit SDRAM as well. Refer to data sheet of the SDRAM for more details.
// For 128Mbit part Refresh interval @66MHz = 66x10^6 X 15.625X10^-6 = 1031.25
// For > 256Mbit parts, Refresh interval @66MHz = 66x10^6 X 7.8125X10^-6 = 515.625
// For 128Mbit part Refresh interval @100MHz = 100x10^6 X 15.625X10^-6 = 1562.5
// For > 256Mbit parts, Refresh interval @100MHz = 100x10^6 X 7.8125X10^-6 = 781.25
// For 128Mbit part Refresh interval @133MHz = 133x10^6 X 15.625X10^-6 = 2078
// For > 256Mbit parts, Refresh interval @133MHz = 133x10^6 X 7.8125X10^-6 = 1039
// Set the refresh count interval slightly less than the values computed above. 
//parameter AUTO_REFRESH_COUNT = 500;
//parameter AUTO_REFRESH_COUNT = 750;
//parameter AUTO_REFRESH_COUNT = 1000;
//parameter AUTO_REFRESH_COUNT = 1500;
//parameter AUTO_REFRESH_COUNT = 2000;


// This is used only for simulation purpose. It is kind of hold time/wire delay so that
// RTL and post P&R simulation has the exact same behaviour. 
parameter WIREDLY = 1; 


