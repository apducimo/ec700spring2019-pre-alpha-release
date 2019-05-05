// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : be_be_rocc_adaptor.sv
// Description    : Black Parrot RoCC Interface Adaptor
// 
// ============================================================================

// ---------------------------------------------------------------------------
// Out of Module Scope Includes
//
`include "bp_common_me_if.vh"

// ---------------------------------------------------------------------------
// RoCC Adaptor Package
//  

// ----------------------------------------------------------------------------
// Module
//  
module bp_be_rocc_adaptor (
  // --------------------------------------------------------------------------
  // Module Port Arguments
  //
  ///////////////////////
  // Clocks and Resets //
  ///////////////////////
  //
  reset_i, // (I) Reset, active high

  clk_i,   // (I) Clock

  ////////////////////////
  // RoCC: Core Control //
  ////////////////////////
  //
  busy_i,      // (I) Busy signal
  interrupt_i, // (I) Interrupt
  exception_o, // (O) Exception

  cmd_status_debug_o,   // (O)
  cmd_status_cease_o,   // (O)
  cmd_status_isa_o,     // (O)
  cmd_status_dprv_o,    // (O)
  cmd_status_prv_o,     // (O)
  cmd_status_sd_o,      // (O)
  cmd_status_zero2_o,   // (O)
  cmd_status_sxl_o,     // (O)
  cmd_status_uxl_o,     // (O)
  cmd_status_sd_rv32_o, // (O)
  cmd_status_zero1_o,   // (O)
  cmd_status_tsr_o,     // (O)
  cmd_status_tw_o,      // (O)
  cmd_status_tvm_o,     // (O)
  cmd_status_mxr_o,     // (O)
  cmd_status_sum_o,     // (O)
  cmd_status_mprv_o,    // (O)
  cmd_status_xs_o,      // (O)
  cmd_status_fs_o,      // (O)
  cmd_status_mpp_o,     // (O)
  cmd_status_hpp_o,     // (O)
  cmd_status_spp_o,     // (O)
  cmd_status_mpie_o,    // (O)
  cmd_status_hpie_o,    // (O)
  cmd_status_spie_o,    // (O)
  cmd_status_upie_o,    // (O)
  cmd_status_mie_o,     // (O)
  cmd_status_hie_o,     // (O)
  cmd_status_sie_o,     // (O)
  cmd_status_uie_o,     // (O)

  /////////////////////////
  // RoCC: Register Mode //
  /////////////////////////
  //
  cmd_ready_i,       // (I) Control ready
  cmd_v_o,           // (O) Control valid
  cmd_inst_funct_o,  // (O) Accelerator function
  cmd_inst_rs2_o,    // (O) Source Register 2 ID
  cmd_inst_rs1_o,    // (O) Source Regsiter 1 ID
  cmd_inst_xd_o,     // (O) Destination Register use valid
  cmd_inst_xs1_o,    // (O) Source Register 1 use valid
  cmd_inst_xs2_o,    // (O) Source Register 2 use valid
  cmd_inst_rd_o,     // (O) Destination Register ID
  cmd_inst_opcode_o, // (O) Custom instruction opcode
  cmd_rs1_o,         // (O) Source Register 1 Data
  cmd_rs2_o,         // (O) Source Register 2 Data

  resp_ready_o, // (O) Response ready
  resp_v_i,     // (I) Response valid
  resp_rd_i,    // (I) Response Destination Register ID
  resp_data_i,  // (I) Response Destination Register data

  ///////////////////////
  // RoCC: Memory Mode //
  ///////////////////////
  //
  mem_req_ready_o, // (O) Request ready
  mem_req_v_i,     // (I) Request valid
  mem_req_addr_i,  // (I) Request address
  mem_req_tag_i,   // (I) Request tag
  mem_req_cmd_i,   // (I) Request command code
  mem_req_typ_i,   // (I) Response width request
  mem_req_phys_i,  // (I) Request address type
  mem_req_data_i,  // (I) Request write data

  mem_resp_v_o,                // (O) Response valid
  mem_resp_addr_o,             // (O) Response address
  mem_resp_tag_o,              // (O) Response tag
  mem_resp_cmd_o,              // (O) Response command code
  mem_resp_typ_o,              // (O) Response data width indicator
  mem_resp_data_o,             // (O) Response data
  mem_resp_has_data_o,         // (O) Response data valid indicator

  mem_resp_replay_o,           // (O) TBD
  mem_resp_data_word_bypass_o, // (O) Response store bypass indicator
  mem_resp_store_data_o,       // (O) Response store data

  //////////////////////////////////
  // LCE Command / Data Interface //
  //////////////////////////////////
  //
  lce_cmd_o,            // (O)
  lce_cmd_v_o,          // (O)
  lce_cmd_ready_i,      // (I)

  lce_data_cmd_o,       // (O)
  lce_data_cmd_v_o,     // (O)
  lce_data_cmd_ready_i, // (I)

  ////////////////////////////
  // LCE Response Interface //
  ////////////////////////////
  //
  lce_resp_i,       // (I)
  lce_resp_v_i,     // (I)
  lce_resp_ready_o, // (O)

  lce_data_resp_i,       // (I)
  lce_data_resp_v_i,     // (I)
  lce_data_resp_ready_o, // (O)

  ///////////////////////
  // Core-Side Command //
  ///////////////////////
  //
  instr_i,     // (I) Comitted instruction
  rs1_data_i,  // (I) Comitted RS1 contents
  rs2_data_i,  // (I) Comitted RS2 contents
  cmd_stall_o, // (O) Stall for command not ready 

  ////////////////////////
  // Core-Side Response //
  ////////////////////////
  //
  rf_wr_rdy_i,  // (I) Regfile write ready
  rf_wr_v_o,    // (O) Regfile write enable
  rf_rd_addr_o, // (O) Regfile write address
  rf_rd_data_o  // (O) Regfile write data


);

 import bp_common_pkg::*;

  // --------------------------------------------------------------------------
  // Parameters
  //
  parameter num_cce_p        = 32'd1;
  parameter num_lce_p        = 32'd2;
  parameter lce_addr_width_p = 32'd22;
  parameter lce_data_width_p = 32'd128;
  parameter ways_p           = 32'd2;

  localparam lce_cce_resp_width_lp      =`bp_lce_cce_resp_width      (num_cce_p, num_lce_p, lce_addr_width_p                           );
  localparam lce_cce_data_resp_width_lp =`bp_lce_cce_data_resp_width (num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);

  localparam cce_lce_cmd_width_lp      = `bp_cce_lce_cmd_width       (num_cce_p, num_lce_p, lce_addr_width_p,                    ways_p);
  localparam cce_lce_data_cmd_width_lp = `bp_cce_lce_data_cmd_width  (num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);

  ///////////////////////
  // Clocks and Resets //
  ///////////////////////
  //
  input reset_i;

  input clk_i;

  ////////////////////////
  // RoCC: Core Control //
  ////////////////////////
  //
  input  busy_i;
  input  interrupt_i;
  output exception_o;

  output        cmd_status_debug_o;
  output        cmd_status_cease_o;
  output [31:0] cmd_status_isa_o;
  output  [1:0] cmd_status_dprv_o;
  output  [1:0] cmd_status_prv_o;
  output        cmd_status_sd_o;
  output [26:0] cmd_status_zero2_o;
  output  [1:0] cmd_status_sxl_o;
  output  [1:0] cmd_status_uxl_o;
  output        cmd_status_sd_rv32_o;
  output  [7:0] cmd_status_zero1_o;
  output        cmd_status_tsr_o;
  output        cmd_status_tw_o;
  output        cmd_status_tvm_o;
  output        cmd_status_mxr_o;
  output        cmd_status_sum_o;
  output        cmd_status_mprv_o;
  output  [1:0] cmd_status_xs_o;
  output  [1:0] cmd_status_fs_o;
  output  [1:0] cmd_status_mpp_o;
  output  [1:0] cmd_status_hpp_o;
  output        cmd_status_spp_o;
  output        cmd_status_mpie_o;
  output        cmd_status_hpie_o;
  output        cmd_status_spie_o;
  output        cmd_status_upie_o;
  output        cmd_status_mie_o;
  output        cmd_status_hie_o;
  output        cmd_status_sie_o;
  output        cmd_status_uie_o;

  /////////////////////////
  // RoCC: Register Mode //
  /////////////////////////
  //
  input              cmd_ready_i;
  output reg         cmd_v_o;
  output reg   [6:0] cmd_inst_funct_o;
  output reg   [4:0] cmd_inst_rs2_o;
  output reg   [4:0] cmd_inst_rs1_o;
  output wire        cmd_inst_xd_o;
  output wire        cmd_inst_xs1_o;
  output wire        cmd_inst_xs2_o;
  output reg   [4:0] cmd_inst_rd_o;
  output reg   [6:0] cmd_inst_opcode_o;
  output reg  [63:0] cmd_rs1_o;
  output reg  [63:0] cmd_rs2_o;

  output reg      resp_ready_o;
  input           resp_v_i;
  input     [4:0] resp_rd_i;
  input    [63:0] resp_data_i;

  ///////////////////////
  // RoCC: Memory Mode //
  ///////////////////////
  //
  output        mem_req_ready_o;
  input         mem_req_v_i;
  input  [39:0] mem_req_addr_i;
  input   [7:0] mem_req_tag_i;
  input   [4:0] mem_req_cmd_i;
  input   [2:0] mem_req_typ_i;
  input         mem_req_phys_i;
  input  [63:0] mem_req_data_i;

  output        mem_resp_v_o;
  output [39:0] mem_resp_addr_o;
  output [7:0]  mem_resp_tag_o;
  output [4:0]  mem_resp_cmd_o;
  output [2:0]  mem_resp_typ_o;
  output [63:0] mem_resp_data_o;
  output        mem_resp_has_data_o;

  output        mem_resp_replay_o;
  output [63:0] mem_resp_data_word_bypass_o;
  output [63:0] mem_resp_store_data_o;

  //////////////////////////////////
  // LCE Command / Data Interface //
  //////////////////////////////////
  //
  output [cce_lce_cmd_width_lp-1:0] lce_cmd_o;
  output                            lce_cmd_v_o;
  input                             lce_cmd_ready_i;

  output [cce_lce_data_cmd_width_lp-1:0] lce_data_cmd_o;
  output                                 lce_data_cmd_v_o;
  input                                  lce_data_cmd_ready_i;

  ////////////////////////////
  // LCE Response Interface //
  ////////////////////////////
  //
  input  [lce_cce_resp_width_lp-1:0] lce_resp_i;
  input                              lce_resp_v_i;
  output                             lce_resp_ready_o;

  input  [lce_cce_data_resp_width_lp-1:0] lce_data_resp_i;
  input                                   lce_data_resp_v_i;
  output                                  lce_data_resp_ready_o;

  ///////////////////////
  // Core-Side Command //
  ///////////////////////
  //
  input [31:0] instr_i;
  input [63:0] rs1_data_i;
  input [63:0] rs2_data_i;
  output       cmd_stall_o;

  ////////////////////////
  // Core-Side Response //
  ////////////////////////
  //
  input             rf_wr_rdy_i;
  output reg        rf_wr_v_o;
  output reg  [4:0] rf_rd_addr_o;
  output reg [63:0] rf_rd_data_o;
  
  //---------------------------------------------------------------------------
  // Internal Signals
  //
  // RoCC: Register Mode: Command
  reg  nxt_cmd_v_o;

  reg   [6:0] nxt_cmd_inst_funct_o;
  reg   [4:0] nxt_cmd_inst_rs2_o;
  reg   [4:0] nxt_cmd_inst_rs1_o;
  reg   [4:0] nxt_cmd_inst_rd_o;
  reg   [6:0] nxt_cmd_inst_opcode_o;
  reg  [63:0] nxt_cmd_rs1_o;
  reg  [63:0] nxt_cmd_rs2_o;

  // RoCC: Register Mode: Response
  reg nxt_rf_wr_v_o;

  reg  [4:0] nxt_rf_rd_addr_o;
  reg [63:0] nxt_rf_rd_data_o;

  // --------------------------------------------------------------------------
  // RoCC: Register Mode: Command
  //
  ////////////////
  // Validation //
  ////////////////
  //
  always @(posedge clk_i or posedge reset_i) begin : rmc_vld_seq
    if (reset_i) begin
      cmd_v_o <= 1'd0;
    end else begin
      cmd_v_o <= nxt_cmd_v_o;
    end
  end

  always @* begin : rmc_vld_cmb
    if (!cmd_v_o) begin
      // No valid accelerator command trying to be transfered.
      if (instr_i[6:0] == 7'h2B) begin
        // New accelerator command has been detected
        nxt_cmd_v_o = 1'b1;
      end else begin
        // New accelerator command has NOT been detected
        nxt_cmd_v_o = 1'b0;
      end
    end else begin
      // Valid accelerator command trying to be transfered.
      if (cmd_ready_i) begin
        // Accelerator ready
        if (instr_i[6:0] == 7'h2B) begin
          // New accelerator command has been detected
          nxt_cmd_v_o = 1'b1;
        end else begin
          // New accelerator command has NOT been detected
          nxt_cmd_v_o = 1'b0;
        end
      end else begin
        // Accelerator NOT ready
        nxt_cmd_v_o = 1'b1;
      end
    end
  end

  // Stall core when command cannot be transfered to accelerator
  assign cmd_stall_o = cmd_v_o & ~cmd_ready_i & (instr_i[6:0] == 7'h2B);
  
  //////////
  // Data //
  //////////
  //
  always @(posedge clk_i or posedge reset_i) begin : rmc_dat_seq
    if (reset_i) begin
      cmd_inst_funct_o  <= 7'd0;
      cmd_inst_rs2_o    <= 5'd0;
      cmd_inst_rs1_o    <= 5'd0;
      cmd_inst_rd_o     <= 5'd0;
      cmd_inst_opcode_o <= 7'd0;
      cmd_rs1_o         <= 64'd0;
      cmd_rs2_o         <= 64'd0;
    end else begin
      cmd_inst_funct_o  <= nxt_cmd_inst_funct_o;
      cmd_inst_rs2_o    <= nxt_cmd_inst_rs2_o;
      cmd_inst_rs1_o    <= nxt_cmd_inst_rs1_o;
      cmd_inst_rd_o     <= nxt_cmd_inst_rd_o;
      cmd_inst_opcode_o <= nxt_cmd_inst_opcode_o;
      cmd_rs1_o         <= nxt_cmd_rs1_o;
      cmd_rs2_o         <= nxt_cmd_rs2_o;
    end
  end

  assign cmd_inst_xd_o = 1'd0;
  assign cmd_inst_xs1_o = 1'd0;
  assign cmd_inst_xs2_o = 1'd0;

  always @* begin : rmc_dat_cmb
    if (!cmd_stall_o) begin
      nxt_cmd_inst_funct_o  = instr_i[31:25];
      nxt_cmd_inst_rs2_o    = instr_i[24:20];
      nxt_cmd_inst_rs1_o    = instr_i[19:15];
      nxt_cmd_inst_rd_o     = instr_i[11:7];
      nxt_cmd_inst_opcode_o = instr_i[6:0];
      nxt_cmd_rs1_o         = rs1_data_i;
      nxt_cmd_rs2_o         = rs2_data_i;
    end else begin
      nxt_cmd_inst_funct_o  = cmd_inst_funct_o;
      nxt_cmd_inst_rs2_o    = cmd_inst_rs2_o;
      nxt_cmd_inst_rs1_o    = cmd_inst_rs1_o;
      nxt_cmd_inst_rd_o     = cmd_inst_rd_o;
      nxt_cmd_inst_opcode_o = cmd_inst_opcode_o;
      nxt_cmd_rs1_o         = cmd_rs1_o;
      nxt_cmd_rs2_o         = cmd_rs2_o;
    end
  end

  // --------------------------------------------------------------------------
  // RoCC: Register Mode: Respond
  //
  ////////////////
  // Validation //
  ////////////////
  //
  always @(posedge clk_i or posedge reset_i) begin : rmr_vld_seq
    if (reset_i) begin
      rf_wr_v_o <= 1'd0;
    end else begin
      rf_wr_v_o <= nxt_rf_wr_v_o;
    end
  end

  always @* begin : rmr_vld_cmb
    if (!rf_wr_v_o) begin
      // No valid accelerator write to register file attempted.
      if (resp_v_i && resp_ready_o) begin
        // Response to be transfered
        nxt_rf_wr_v_o = 1'd1;
      end else begin
        // No response to transfer
        nxt_rf_wr_v_o = 1'd0;
      end
    end else begin
      // Valid accelerator write to register file attempted.
      if (rf_wr_rdy_i) begin
        // No register file write conflict
        if (resp_v_i && resp_ready_o) begin
          // Response to be transfered
          nxt_rf_wr_v_o = 1'd1;
        end else begin
          // No response to transfer
          nxt_rf_wr_v_o = 1'd0;
        end
      end else begin
        // Register file write conflict
        nxt_rf_wr_v_o = 1'd1;
      end
    end
  end

  // Not ready for new response if atttempt to write register file results
  // in a conflict
  assign resp_ready_o = ~(rf_wr_v_o & ~rf_wr_rdy_i);
  
  ////////////////////
  // Address / Data //
  ////////////////////
  //
  always @(posedge clk_i or posedge reset_i) begin : rmr_dat_seq
    if (reset_i) begin
      rf_rd_addr_o <= 5'd0;
      rf_rd_data_o <= 64'd0;
    end else begin
      rf_rd_addr_o <= nxt_rf_rd_addr_o;
      rf_rd_data_o <= nxt_rf_rd_data_o;
    end
  end

  always @* begin : rmr_dat_cmb
    if (resp_v_i && resp_ready_o) begin
      nxt_rf_rd_addr_o = resp_rd_i;
      nxt_rf_rd_data_o = resp_data_i;
    end else begin
      nxt_rf_rd_addr_o = rf_rd_addr_o;
      nxt_rf_rd_data_o = rf_rd_data_o;
    end
  end

  // --------------------------------------------------------------------------
  // RoCC: Core Control
  //
  ////////////
  // Status //
  ////////////
  //
  // Unused
  assign cmd_status_debug_o   = 1'd0;
  assign cmd_status_cease_o   = 1'd0;
  assign cmd_status_isa_o     = 32'd0;
  assign cmd_status_dprv_o    = 2'd0;
  assign cmd_status_prv_o     = 2'd0;
  assign cmd_status_sd_o      = 1'd0;
  assign cmd_status_zero2_o   = 27'd0;
  assign cmd_status_sxl_o     = 2'd0;
  assign cmd_status_uxl_o     = 2'd0;
  assign cmd_status_sd_rv32_o = 1'd0;
  assign cmd_status_zero1_o   = 8'd0;
  assign cmd_status_tsr_o     = 1'd0;
  assign cmd_status_tw_o      = 1'd0;
  assign cmd_status_tvm_o     = 1'd0;
  assign cmd_status_mxr_o     = 1'd0;
  assign cmd_status_sum_o     = 1'd0;
  assign cmd_status_mprv_o    = 1'd0;
  assign cmd_status_xs_o      = 2'd0;
  assign cmd_status_fs_o      = 2'd0;
  assign cmd_status_mpp_o     = 2'd0;
  assign cmd_status_hpp_o     = 2'd0;
  assign cmd_status_spp_o     = 1'd0;
  assign cmd_status_mpie_o    = 1'd0;
  assign cmd_status_hpie_o    = 1'd0;
  assign cmd_status_spie_o    = 1'd0;
  assign cmd_status_upie_o    = 1'd0;
  assign cmd_status_mie_o     = 1'd0;
  assign cmd_status_hie_o     = 1'd0;
  assign cmd_status_sie_o     = 1'd0;
  assign cmd_status_uie_o     = 1'd0;

  // --------------------------------------------------------------------------
  // RoCC: Memory Mode
  //
  assign mem_req_ready_o =  1'b0;

  assign mem_resp_v_o = 1'b0;
  assign mem_resp_addr_o = 40'd0;
  assign mem_resp_tag_o = 8'd0;
  assign mem_resp_cmd_o = 5'd0;
  assign mem_resp_typ_o = 3'd0;
  assign mem_resp_data_o = 64'd0;
  assign mem_resp_has_data_o = 1'd0;

  assign lce_cmd_o = {cce_lce_cmd_width_lp{1'd0}};
  assign lce_cmd_v_o = 1'd0;

  assign lce_data_cmd_o = {cce_lce_data_cmd_width_lp{1'd0}};
  assign lce_data_cmd_v_o = 1'd0;

  assign lce_resp_ready_o = 1'd0;
  assign lce_data_resp_ready_o = 1'd0;

  wire temp_mem_unused_ok = |{
                              mem_req_v_i,
                              mem_req_addr_i,
                              mem_req_tag_i,
                              mem_req_cmd_i,
                              mem_req_typ_i,
                              mem_req_phys_i,
                              mem_req_data_i,
                              lce_cmd_ready_i,
                              lce_data_cmd_ready_i,
                              lce_resp_i,
                              lce_resp_v_i,
                              lce_data_resp_i,
                              lce_data_resp_v_i,
                              1'b1};
  
  ////////////
  // Unused //
  ////////////
  //
  assign mem_resp_replay_o           = 1'd0;
  assign mem_resp_data_word_bypass_o = 64'd0;
  assign mem_resp_store_data_o       = 64'd0;

  // --------------------------------------------------------------------------
  // Unused
  //
  wire unused_ok = |{
                     // Instruction funct3 unused
                     instr_i[14:12],

                     temp_mem_unused_ok,

                     busy_i,

                     interrupt_i,

                     1'b1};

  assign exception_o = 1'b0;
  
endmodule
