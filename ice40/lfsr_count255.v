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
// Description : This module generates 255 cycle counter and generates a high when count == 255.
//               It is used in 150us delay generator module.
// -------------------------------------------------------------------------------------------------


`timescale 1 ns / 1 ps

module lfsr_count255(
                     input i_sys_clk,
                     input i_sys_rst,
                     output reg o_lfsr_256_done);

    reg [7:0]                   lfsr_reg_i;
    wire                        lfsr_d0_i,lfsr_256_equal_i;

    xnor(lfsr_d0_i,lfsr_reg_i[7],lfsr_reg_i[5],lfsr_reg_i[4],lfsr_reg_i[3]);
    assign lfsr_256_equal_i = (lfsr_reg_i == 8'h80);
    //2D for 100us, 8'h05 for 125us, 8'h10 for 150us, 8'h80 gives 160us

    always @(posedge i_sys_clk,posedge i_sys_rst) begin
        if(i_sys_rst) begin
            lfsr_reg_i <= 0;
            o_lfsr_256_done <= 0;
        end
        else begin
            lfsr_reg_i <= lfsr_256_equal_i ? 8'h0 : {lfsr_reg_i[6:0],lfsr_d0_i};
            o_lfsr_256_done <= lfsr_256_equal_i;
        end
    end
endmodule
