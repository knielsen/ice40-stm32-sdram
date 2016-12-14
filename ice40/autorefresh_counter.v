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
// Description : LFSR Based auto refresh counter. It provided 5 counters for counts:
//               500, 750, 1000, 1500 and 2000 cycles. Users of this counter must appropriately
//               select the AUTO_REFRESH_COUNT in the package based on the freq and refresh
//               cycle requirements of SDRAM under consideration. 
// -------------------------------------------------------------------------------------------------


`timescale 1 ns / 1 ps
module autorefresh_counter(
                           input i_sys_clk,
                           input i_sys_rst,
                           input i_autorefresh_enable,
                           output reg o_refresh_count_done);

    `include "sdram_defines.v"

    parameter AUTO_REFRESH_COUNT = 1500;
   
    generate
        if (AUTO_REFRESH_COUNT == 2000) begin
            reg [10:0] lfsr_reg_i;
            wire       lfsr_lsb_i,lfsr_count_match_i;

            xnor(lfsr_lsb_i,lfsr_reg_i[10],lfsr_reg_i[8]);
            assign lfsr_count_match_i = (lfsr_reg_i == 11'h5D3);

            always @(posedge i_sys_clk,posedge i_sys_rst) begin
                if(i_sys_rst) begin
                    lfsr_reg_i <= 0;
                    o_refresh_count_done <= 0;
                end
                else begin
                    if(i_autorefresh_enable)
                        lfsr_reg_i <= lfsr_count_match_i ? 11'h0 : {lfsr_reg_i[9:0],lfsr_lsb_i};
                    o_refresh_count_done <= lfsr_count_match_i;
                end
            end
        end
        else if (AUTO_REFRESH_COUNT == 1500) begin
            reg [10:0] lfsr_reg_i;
            wire       lfsr_lsb_i,lfsr_count_match_i;

            xnor(lfsr_lsb_i,lfsr_reg_i[10],lfsr_reg_i[8]);
            assign lfsr_count_match_i = (lfsr_reg_i == 11'h17);

            always @(posedge i_sys_clk,posedge i_sys_rst) begin
                if(i_sys_rst) begin
                    lfsr_reg_i <= 0;
                    o_refresh_count_done <= 0;
                end
                else begin
                    if(i_autorefresh_enable)
                        lfsr_reg_i <= lfsr_count_match_i ? 11'h0 : {lfsr_reg_i[9:0],lfsr_lsb_i};
                    o_refresh_count_done <= lfsr_count_match_i;
                end
            end
        end
        else if (AUTO_REFRESH_COUNT == 1000) begin
            reg [9:0] lfsr_reg_i;
            wire      lfsr_lsb_i,lfsr_count_match_i;

            xnor(lfsr_lsb_i,lfsr_reg_i[9],lfsr_reg_i[6]);
            assign lfsr_count_match_i = (lfsr_reg_i == 10'h2B2);

            always @(posedge i_sys_clk,posedge i_sys_rst) begin
                if(i_sys_rst) begin
                    lfsr_reg_i <= 0;
                    o_refresh_count_done <= 0;
                end
                else begin
                    if(i_autorefresh_enable)
                        lfsr_reg_i <= lfsr_count_match_i ? 10'h0 : {lfsr_reg_i[8:0],lfsr_lsb_i};
                    o_refresh_count_done <= lfsr_count_match_i;
                end
            end
        end
        else if (AUTO_REFRESH_COUNT == 750) begin
            reg [9:0] lfsr_reg_i;
            wire      lfsr_lsb_i,lfsr_count_match_i;

            xnor(lfsr_lsb_i,lfsr_reg_i[9],lfsr_reg_i[6]);
            assign lfsr_count_match_i = (lfsr_reg_i == 10'h373);

            always @(posedge i_sys_clk,posedge i_sys_rst) begin
                if(i_sys_rst) begin
                    lfsr_reg_i <= 0;
                    o_refresh_count_done <= 0;
                end
                else begin
                    if(i_autorefresh_enable)
                        lfsr_reg_i <= lfsr_count_match_i ? 10'h0 : {lfsr_reg_i[8:0],lfsr_lsb_i};
                    o_refresh_count_done <= lfsr_count_match_i;
                end
            end  
        end
        else if (AUTO_REFRESH_COUNT == 500) begin
            
            reg [8:0] lfsr_reg_i;
            wire      lfsr_lsb_i,lfsr_count_match_i;

            xnor(lfsr_lsb_i,lfsr_reg_i[8],lfsr_reg_i[4]);
            assign lfsr_count_match_i = (lfsr_reg_i == 9'h21);

            always @(posedge i_sys_clk,posedge i_sys_rst) begin
                if(i_sys_rst) begin
                    lfsr_reg_i <= 0;
                    o_refresh_count_done <= 0;
                end
                else begin
                    if(i_autorefresh_enable)
                        lfsr_reg_i <= lfsr_count_match_i ? 9'h0 : {lfsr_reg_i[7:0],lfsr_lsb_i};
                    o_refresh_count_done <= lfsr_count_match_i;
                end
            end
        end
    endgenerate

endmodule
