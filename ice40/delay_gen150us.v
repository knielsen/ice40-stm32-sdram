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
// Description : This module generates 150us delay, normally required before issuing any commmands
//               SDR SDRAM after power ON. It divides the system clock by 64 and then uses 255 
//               length counter to generate 165us delay(not 150).
// -------------------------------------------------------------------------------------------------


`timescale 1 ns / 1 ps

module delay_gen150us (/*AUTOARG*/
    // Outputs
    o_lfsr_256_done,
    // Inputs
    i_sys_rst, i_sys_clk
    );

    input               i_sys_clk;              // To U1 of lfsr_count64.v, ...
    input               i_sys_rst;              // To U1 of lfsr_count64.v, ...
    output              o_lfsr_256_done;        // From U5 of lfsr_count256.v
    wire              lfsr_64_done_i;         // From U1 of lfsr_count64.v
  
    lfsr_count64 U1(/*AUTOINST*/
                    // Outputs
                    .o_lfsr_64_done     (lfsr_64_done_i),
                    // Inputs
                    .i_sys_clk          (i_sys_clk),
                    .i_sys_rst          (i_sys_rst));
    lfsr_count255 U5(/*AUTOINST*/
                     // Outputs
                     .o_lfsr_256_done   (o_lfsr_256_done),
                     // Inputs
                     .i_sys_clk         (lfsr_64_done_i),
                     .i_sys_rst         (i_sys_rst));
        
endmodule // delay_gen150us
