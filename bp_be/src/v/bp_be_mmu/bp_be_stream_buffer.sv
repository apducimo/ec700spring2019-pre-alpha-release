// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : bp_be_stream_buffer.sv
// Description    : Black Parrot Stream Buffer ofr L1$
// 
// ============================================================================

// ---------------------------------------------------------------------------
// Out of Module Scope Includes
//

// ---------------------------------------------------------------------------
// Stream Buffer Package
//  
package bp_be_stream_buffer_pkg;
  
  typedef enum logic [1:0] {e_sb_idle = 2'd0,
                            e_sb_missed = 2'd1,
                            e_sb_ffill = 2'd2,
                            e_sb_mdff = 2'd3
                            } bp_sb_state_e;
endpackage
  
// ----------------------------------------------------------------------------
// Module
//  
module bp_be_stream_buffer (

  // --------------------------------------------------------------------------
  // Module Port Arguments
  //
  // Using Verilog 1995 style port declaration to utilize localparams instead
  // of parameters for IO declarations to prevent undesired parameter overrides
  //
  ///////////////////////
  // Clocks and Resets //
  ///////////////////////
  //
  reset_i, // (I) Reset, active high

  clk_i,   // (I) Clock

  //////////////////////
  // LCE-SB Interface //
  //////////////////////
  //
  lce_sb_req_i,       // (I)
  lce_sb_req_v_i,     // (I)
  lce_sb_req_ready_o, // (O)

  lce_sb_resp_i,       // (I)
  lce_sb_resp_v_i,     // (I)
  lce_sb_resp_ready_o, // (O)

  lce_sb_data_resp_i,       // (I)
  lce_sb_data_resp_v_i,     // (I)
  lce_sb_data_resp_ready_o, // (O)

  //////////////////////
  // SB-LCE Interface //
  //////////////////////
  //
  sb_lce_cmd_o,            // (O)
  sb_lce_cmd_v_o,          // (O)
  sb_lce_cmd_ready_i,      // (I)

  sb_lce_data_cmd_o,       // (O)
  sb_lce_data_cmd_v_o,     // (O)
  sb_lce_data_cmd_ready_i, // (I)

  //////////////////////
  // SB-CCE Interface //
  //////////////////////
  //
  sb_cce_req_o,             // (O)
  sb_cce_req_v_o,           // (O)
  sb_cce_req_ready_i,       // (I)

  sb_cce_resp_o,            // (O)
  sb_cce_resp_v_o,          // (O)
  sb_cce_resp_ready_i,      // (I)

  sb_cce_data_resp_o,       // (O)
  sb_cce_data_resp_v_o,     // (O)
  sb_cce_data_resp_ready_i, // (I)

  //////////////////////
  // CCE-SB Interface //
  //////////////////////
  //
  cce_sb_cmd_i,       // (I)
  cce_sb_cmd_v_i,     // (I)
  cce_sb_cmd_ready_o, // (O)

  cce_sb_data_cmd_i,       // (I)
  cce_sb_data_cmd_v_i,     // (I)
  cce_sb_data_cmd_ready_o  // (O)

);
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;

  // ---------------------------------------------------------------------------
  // Parameters / Localparams
  //
  parameter num_cce_p        = 32'd1;
  parameter num_lce_p        = 32'd2;
  parameter lce_addr_width_p = 32'd22;
  parameter lce_data_width_p = 32'd128;
  parameter ways_p           = 32'd2;

  localparam way_idx_width_lp = (ways_p    == 32'd1) ? 32'd1 : $clog2(ways_p);
  localparam lce_idx_width_lp = (num_lce_p == 32'd1) ? 32'd1 : $clog2(num_lce_p);
  localparam cce_idx_width_lp = (num_cce_p == 32'd1) ? 32'd1 : $clog2(num_cce_p);

  localparam lce_cce_req_width_lp       =`bp_lce_cce_req_width       (num_cce_p, num_lce_p, lce_addr_width_p,                    ways_p);
  localparam lce_cce_resp_width_lp      =`bp_lce_cce_resp_width      (num_cce_p, num_lce_p, lce_addr_width_p                           );
  localparam lce_cce_data_resp_width_lp =`bp_lce_cce_data_resp_width (num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);

  localparam cce_lce_cmd_width_lp      = `bp_cce_lce_cmd_width       (num_cce_p, num_lce_p, lce_addr_width_p,                    ways_p);
  localparam cce_lce_data_cmd_width_lp = `bp_cce_lce_data_cmd_width  (num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);

  parameter  sb_depth_p = 32'd4;
  localparam sb_depth_m1_lp = sb_depth_p - 32'd1;
  
  localparam sb_idx_width_lp = (sb_depth_p == 32'd1) ? 32'd1 : $clog2(sb_depth_p);

  localparam sb_addr_incr_lp = lce_data_width_p/32'd8;

  localparam sb_tag_width_lp = lce_addr_width_p - $clog2(sb_addr_incr_lp);

  // ---------------------------------------------------------------------------
  // Module Port Declarations
  //
  ///////////////////////
  // Clocks and Resets //
  ///////////////////////
  //
  input reset_i;

  input clk_i;

  //////////////////////
  // LCE-SB Interface //
  //////////////////////
  //
  input  [lce_cce_req_width_lp-1:0] lce_sb_req_i;
  input                             lce_sb_req_v_i;
  output                            lce_sb_req_ready_o;

  input  [lce_cce_resp_width_lp-1:0] lce_sb_resp_i;
  input                              lce_sb_resp_v_i;
  output                             lce_sb_resp_ready_o;

  input  [lce_cce_data_resp_width_lp-1:0] lce_sb_data_resp_i;
  input                                   lce_sb_data_resp_v_i;
  output                                  lce_sb_data_resp_ready_o;

  //////////////////////
  // SB-LCE Interface //
  //////////////////////
  //
  output logic [cce_lce_cmd_width_lp-1:0] sb_lce_cmd_o;
  output logic                            sb_lce_cmd_v_o;
  input                                   sb_lce_cmd_ready_i;

  output [cce_lce_data_cmd_width_lp-1:0] sb_lce_data_cmd_o;
  output                                 sb_lce_data_cmd_v_o;
  input                                  sb_lce_data_cmd_ready_i;

  //////////////////////
  // SB-CCE Interface //
  //////////////////////
  //
  output [lce_cce_req_width_lp-1:0] sb_cce_req_o;
  output                            sb_cce_req_v_o;
  input                             sb_cce_req_ready_i;

  output [lce_cce_resp_width_lp-1:0] sb_cce_resp_o;
  output                             sb_cce_resp_v_o;
  input                              sb_cce_resp_ready_i;

  output [lce_cce_data_resp_width_lp-1:0] sb_cce_data_resp_o;
  output                                  sb_cce_data_resp_v_o;
  input                                   sb_cce_data_resp_ready_i;

  //////////////////////
  // CCE-SB Interface //
  //////////////////////
  //
  input  [cce_lce_cmd_width_lp-1:0] cce_sb_cmd_i;
  input                             cce_sb_cmd_v_i;
  output                            cce_sb_cmd_ready_o;

  input  [cce_lce_data_cmd_width_lp-1:0] cce_sb_data_cmd_i;
  input                                  cce_sb_data_cmd_v_i;
  output                                 cce_sb_data_cmd_ready_o;

  // ---------------------------------------------------------------------------
  // Package Imports
  //
  import bp_be_stream_buffer_pkg::*;

  //---------------------------------------------------------------------------
  // Internal Signals
  //
  `declare_bp_lce_cce_req_s       (num_cce_p, num_lce_p, lce_addr_width_p,                   ways_p);
  `declare_bp_lce_cce_resp_s      (num_cce_p, num_lce_p, lce_addr_width_p);
  `declare_bp_cce_lce_cmd_s       (num_cce_p, num_lce_p, lce_addr_width_p,                   ways_p);
  `declare_bp_cce_lce_data_cmd_s  (num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);

  //////////////////////
  // LCE-SB Interface //
  //////////////////////
  //
  bp_lce_cce_req_s  lce_sb_req;
  bp_lce_cce_req_s  lce_sb_req_mhold;
  bp_lce_cce_req_s  nxt_lce_sb_req_mhold;

  bp_lce_cce_resp_s lce_sb_resp;

  //////////////////////
  // SB-LCE Interface //
  //////////////////////
  //
  bp_cce_lce_cmd_s      sb_lce_cmd;
  bp_cce_lce_cmd_s      nxt_sb_lce_cmd;

  logic                 sb_lce_cmd_v;
  logic                 nxt_sb_lce_cmd_v;

  bp_cce_lce_data_cmd_s sb_lce_data_cmd;
  bp_cce_lce_data_cmd_s nxt_sb_lce_data_cmd;

  logic                 sb_lce_data_cmd_v;
  logic                 nxt_sb_lce_data_cmd_v;

  //////////////////////
  // SB-CCE Interface //
  //////////////////////
  //
  bp_lce_cce_req_s  sb_cce_req;
  bp_lce_cce_req_s  nxt_sb_cce_req;

  logic             sb_cce_req_v;
  logic             nxt_sb_cce_req_v;

  bp_lce_cce_resp_s sb_cce_resp;
  bp_lce_cce_resp_s nxt_sb_cce_resp;

  logic             sb_cce_resp_v;
  logic             nxt_sb_cce_resp_v;

  //////////////////////
  // CCE-SB Interface //
  //////////////////////
  //
  bp_cce_lce_cmd_s      cce_sb_cmd;
  bp_cce_lce_data_cmd_s cce_sb_data_cmd;

  ////////////////////////
  // Hit/Miss Detection //
  ////////////////////////
  //
  logic [way_idx_width_lp-1:0] way;
  logic                        found_match;
  logic                        sb_hit;
  logic                        sb_hit_d1;
  logic                        sb_hit_sticky;
  logic                        nxt_sb_hit_sticky;
  logic                        sb_miss;
  
  /////////////////////////
  // Stream Buffer State //
  /////////////////////////
  //
  // FSM State Variables
  bp_sb_state_e sb_state;
  bp_sb_state_e nxt_sb_state;

  // Fill Transaction Counter
  logic [sb_idx_width_lp-1:0] fill_count;
  logic [sb_idx_width_lp-1:0] nxt_fill_count;

  //////////
  // FIFO //
  //////////
  //
  logic [ways_p-1:0][sb_depth_p-1:0][lce_data_width_p-1:0] data_fifo;
  logic [ways_p-1:0][sb_depth_p-1:0] [sb_tag_width_lp-1:0] tag_fifo;
  logic [ways_p-1:0][sb_depth_p-1:0]                       avail_fifo;

  logic [ways_p-1:0][sb_depth_p-1:0][lce_data_width_p-1:0] nxt_data_fifo;
  logic [ways_p-1:0][sb_depth_p-1:0] [sb_tag_width_lp-1:0] nxt_tag_fifo;
  logic [ways_p-1:0][sb_depth_p-1:0]                       nxt_avail_fifo;

  logic [ways_p-1:0][sb_idx_width_lp-1:0] rd_ptr;
  logic [ways_p-1:0][sb_idx_width_lp-1:0] nxt_rd_ptr;

  ///////////
  // Misc. //
  ///////////
  //
  genvar ii;
  genvar jj;

  //---------------------------------------------------------------------------
  // Casting
  //
  //////////////////////
  // LCE-SB Interface //
  //////////////////////
  //
  assign lce_sb_req  = lce_sb_req_i;
  assign lce_sb_resp = lce_sb_resp_i;

  //////////////////////
  // SB-LCE Interface //
  //////////////////////
  //
  assign sb_lce_cmd_o   = sb_lce_cmd;
  assign sb_lce_cmd_v_o = sb_lce_cmd_v;

  assign sb_lce_data_cmd_o   = sb_lce_data_cmd;
  assign sb_lce_data_cmd_v_o = sb_lce_data_cmd_v;

  //////////////////////
  // SB-CCE Interface //
  //////////////////////
  //
  assign sb_cce_req_o     = sb_cce_req;
  assign sb_cce_req_v_o   = sb_cce_req_v;

  assign sb_cce_resp_o   = sb_cce_resp;
  assign sb_cce_resp_v_o = sb_cce_resp_v;

  //////////////////////
  // CCE-SB Interface //
  //////////////////////
  //
  assign cce_sb_cmd      = cce_sb_cmd_i;
  assign cce_sb_data_cmd = cce_sb_data_cmd_i;

  //---------------------------------------------------------------------------
  // Readiness : Always ready
  //
  assign lce_sb_req_ready_o  = 1'd1;
  assign lce_sb_resp_ready_o = 1'd1;

  assign cce_sb_cmd_ready_o      = 1'd1;
  assign cce_sb_data_cmd_ready_o = 1'd1;
  
  //---------------------------------------------------------------------------
  // Hit/Miss Detection
  //
  assign way = lce_sb_req.lru_way_id;
  
  always @* begin : match_detect
    if (avail_fifo[way][rd_ptr[way]]) begin
      // FIFO entry for way available
      if (lce_sb_req.addr[lce_addr_width_p-1-:sb_tag_width_lp] == tag_fifo[way][rd_ptr[way]]) begin
        // FIFO entry's tag matches
        found_match = 1'b1;
      end else begin
        // FIFO entry's tag does not match
        found_match = 1'b0;
      end
    end else begin
      // FIFO entry for way unavailable
      found_match = 1'b0;
    end
  end

  assign sb_hit  = lce_sb_req_ready_o & lce_sb_req_v_i & found_match;
  assign sb_miss = lce_sb_req_ready_o & lce_sb_req_v_i & ~found_match;

  always @(posedge clk_i or posedge reset_i) begin : sticky_sb_hit_seq
    if (reset_i) begin
      sb_hit_d1     <= 1'd0;
      sb_hit_sticky <= 1'd0;
    end else begin
      sb_hit_d1     <= sb_hit;
      sb_hit_sticky <= nxt_sb_hit_sticky;
    end
  end

  always @* begin : sticky_sb_hit_comb
    if (!sb_hit_sticky) begin
      if (sb_hit) begin
        nxt_sb_hit_sticky = 1'b1;
      end else begin
        nxt_sb_hit_sticky = 1'b0;
      end
    end else begin
      if (lce_sb_data_resp_v_i && lce_sb_data_resp_ready_o) begin
        nxt_sb_hit_sticky = 1'b0;
      end else begin
        nxt_sb_hit_sticky = 1'b1;
      end
    end
  end

  //---------------------------------------------------------------------------
  // Stream Buffer State
  //
  /////////
  // FSM //
  /////////
  //
  always @(posedge clk_i or posedge reset_i) begin : sb_state_seq
    if (reset_i) begin
      sb_state    <= e_sb_idle;
    end else begin
      sb_state    <= nxt_sb_state;
    end
  end

  always @* begin : sb_state_comb
    case (sb_state)
      e_sb_idle : begin
        if (sb_miss) begin
          // Miss in stream buffer
          nxt_sb_state = e_sb_missed;
        end else begin
          // No miss in stream buffer
          nxt_sb_state = e_sb_idle;
        end
      end

      e_sb_missed : begin
        // Servicing miss in stream buffer
        if (sb_cce_resp_v_o && sb_cce_resp_ready_i) begin
          // SB transmitting response to CCE
          nxt_sb_state = e_sb_ffill;
        end else begin
          nxt_sb_state = e_sb_missed;
        end
      end
      
      e_sb_ffill : begin
        // Filling FIFO
        if (sb_miss) begin
          // Miss in stream buffer
          if (sb_cce_resp_v_o && sb_cce_resp_ready_i) begin
            // Response to current entry fill command detected
            if (sb_cce_req_v_o && sb_cce_req_ready_i) begin
              // SB requesting data transfer to CCE
              nxt_sb_state = e_sb_mdff;
            end else begin
              nxt_sb_state = e_sb_missed;
            end
          end else begin
            nxt_sb_state = e_sb_mdff;
          end
        end else begin
          // No miss in stream buffer
          if (fill_count == sb_depth_m1_lp[sb_idx_width_lp-1:0]) begin
            // Final FIFO entry
            if (sb_cce_resp_v_o && sb_cce_resp_ready_i) begin
              // Response to last final entry fill command detected
              nxt_sb_state = e_sb_idle;
            end else begin
              // Response to last final entry fill command NOT detected
              nxt_sb_state = e_sb_ffill;
            end
          end else begin
            // Not the final FIFO entry
            nxt_sb_state = e_sb_ffill;
          end
        end
      end

      e_sb_mdff : begin
        if (sb_cce_resp_v_o && sb_cce_resp_ready_i) begin
          // Response to current entry fill command detected
          nxt_sb_state = e_sb_missed;
        end else begin
          nxt_sb_state = e_sb_mdff;
        end
      end
    endcase
  end

  //////////////////////////////
  // Fill Transaction Counter //
  //////////////////////////////
  //
  always @(posedge clk_i or posedge reset_i) begin : fill_cnt_seq
    if (reset_i) begin
      fill_count <= {sb_idx_width_lp{1'd0}};
    end else begin
      fill_count <= nxt_fill_count;
    end
  end

  always @* begin : fill_cnt_comb
    case (sb_state)
      e_sb_idle   : nxt_fill_count = fill_count;

      e_sb_missed : nxt_fill_count = {sb_idx_width_lp{1'd0}};
      
      e_sb_ffill  : begin
        // FIFO being filled without a miss previously being detected
        if (sb_cce_resp_v_o && sb_cce_resp_ready_i) begin
          // SB Response to entry fill command detected
          if (fill_count == sb_depth_m1_lp[sb_idx_width_lp-1:0]) begin
            // Final entry fill
            nxt_fill_count = {sb_idx_width_lp{1'd0}};
          end else begin
            nxt_fill_count = fill_count - {sb_idx_width_lp{1'd1}}; // += 1
            end
        end else begin
          // CCE NOT returning command for current entry fill
          nxt_fill_count = fill_count;
        end
      end

      e_sb_mdff   : nxt_fill_count = fill_count;

    endcase
  end

  //---------------------------------------------------------------------------
  // SB-LCE Command Validation:
  //
  always @(posedge clk_i or posedge reset_i) begin : sb_lce_cmd_vld_seq
    if (reset_i) begin
      sb_lce_cmd_v <= 1'd0;
    end else begin
      sb_lce_cmd_v <= nxt_sb_lce_cmd_v;
    end
  end

  always @* begin : sb_lce_cmd_vld_comb
    if (sb_lce_cmd_v) begin
      // Valid SB-LCE request
      if (sb_lce_cmd_ready_i) begin
        // LCE ready
        nxt_sb_lce_cmd_v = 1'd0;
      end else begin
        // LCE not ready
        nxt_sb_lce_cmd_v = 1'd1;
      end
    end else begin
      case (sb_state)
        e_sb_missed : begin
          // Servicing miss in stream buffer
          if (cce_sb_cmd_v_i && cce_sb_cmd_ready_o) begin
            // Valid command from CCE detected
            nxt_sb_lce_cmd_v = 1'b1;
          end else begin
            // No valid command from CCE detected
            nxt_sb_lce_cmd_v = 1'b0;
          end
        end

        e_sb_idle : begin
          if (sb_hit_d1) begin
            // Hit in stream buffer
            nxt_sb_lce_cmd_v = 1'b1;
          end else begin
            // Either no SB access or SB miss
            if (cce_sb_cmd_v_i && cce_sb_cmd_ready_o) begin
              // Command sequence initiated by CCE detected
              nxt_sb_lce_cmd_v = 1'b1;
            end else begin
              // Command sequence initiated by CCE NOT detected
              nxt_sb_lce_cmd_v = 1'b0;
            end
          end
        end

        e_sb_mdff, e_sb_ffill : begin
          // Filling FIFOs
          if (sb_hit_d1) begin
            // Hit in stream buffer
            nxt_sb_lce_cmd_v = 1'b1;
          end else begin
            // Either no SB access or SB miss
            nxt_sb_lce_cmd_v = 1'b0;
          end
        end
      endcase
    end
  end

  //---------------------------------------------------------------------------
  // SB-LCE Command Content:
  //
  always @(posedge clk_i or posedge reset_i) begin : sb_lce_cmd_seq
    if (reset_i) begin
      sb_lce_cmd.dst_id        <= {lce_idx_width_lp{1'd0}};
      sb_lce_cmd.src_id        <= {cce_idx_width_lp{1'd0}};
      sb_lce_cmd.msg_type      <= e_lce_cmd_sync;
      sb_lce_cmd.addr          <= {lce_addr_width_p{1'd0}};
      sb_lce_cmd.way_id        <= {way_idx_width_lp{1'd0}};
      sb_lce_cmd.state         <= 2'd0;
      sb_lce_cmd.target        <= {lce_idx_width_lp{1'd0}};
      sb_lce_cmd.target_way_id <= {way_idx_width_lp{1'd0}};
    end else begin
      sb_lce_cmd <= nxt_sb_lce_cmd;
    end
  end

  always @* begin : sb_lce_cmd_comb
    case (sb_state)
      e_sb_missed : begin
        // Servicing miss in stream buffer
        if (cce_sb_cmd_v_i && cce_sb_cmd_ready_o) begin
          // Valid command from CCE detected
          nxt_sb_lce_cmd = cce_sb_cmd;
        end else begin
          // No valid command from CCE detected
          nxt_sb_lce_cmd = sb_lce_cmd;
        end
      end

      e_sb_idle : begin
        if (sb_hit_d1) begin
          // Hit in stream buffer
          nxt_sb_lce_cmd.dst_id        = lce_sb_req_mhold.src_id;
          nxt_sb_lce_cmd.src_id        = lce_sb_req_mhold.dst_id;
          nxt_sb_lce_cmd.msg_type      = e_lce_cmd_set_tag;
          nxt_sb_lce_cmd.addr          = lce_sb_req_mhold.addr;
          nxt_sb_lce_cmd.way_id        = lce_sb_req_mhold.lru_way_id;
          nxt_sb_lce_cmd.state         = 2'd2;
          nxt_sb_lce_cmd.target        = {lce_idx_width_lp{1'd0}};
          nxt_sb_lce_cmd.target_way_id = {way_idx_width_lp{1'd0}};
        end else begin
          // Either no SB access or SB miss
          if (cce_sb_cmd_v_i && cce_sb_cmd_ready_o) begin
            // Command sequence initiated by CCE detected
            nxt_sb_lce_cmd = cce_sb_cmd;
          end else begin
            // Command sequence initiated by CCE NOT detected
            nxt_sb_lce_cmd = sb_lce_cmd;
          end
        end
      end

      e_sb_mdff, e_sb_ffill : begin
        // Either idle or filling FIFOs
        if (sb_hit_d1) begin
          // Hit in stream buffer
          nxt_sb_lce_cmd.dst_id        = lce_sb_req_mhold.src_id;
          nxt_sb_lce_cmd.src_id        = lce_sb_req_mhold.dst_id;
          nxt_sb_lce_cmd.msg_type      = e_lce_cmd_set_tag;
          nxt_sb_lce_cmd.addr          = lce_sb_req_mhold.addr;
          nxt_sb_lce_cmd.way_id        = lce_sb_req_mhold.lru_way_id;
          nxt_sb_lce_cmd.state         = 2'd2;
          nxt_sb_lce_cmd.target        = {lce_idx_width_lp{1'd0}};
          nxt_sb_lce_cmd.target_way_id = {way_idx_width_lp{1'd0}};
        end else begin
          // Either no SB access or SB miss
          nxt_sb_lce_cmd = sb_lce_cmd;
        end
      end
    endcase
  end
  ////////////////////
  // Req Match Hold //
  ////////////////////
  //
  // Need to hold request when a match is found to stagger SB-LCE Command after
  // SB-LCE Data Command
  always @(posedge clk_i or posedge reset_i) begin : lce_sb_req_hold_seq
    if (reset_i) begin
      lce_sb_req_mhold.dst_id        <= {cce_idx_width_lp{1'd0}};
      lce_sb_req_mhold.src_id        <= {lce_idx_width_lp{1'd0}};
      lce_sb_req_mhold.msg_type      <= e_lce_req_type_rd;
      lce_sb_req_mhold.non_exclusive <= e_lce_req_excl;
      lce_sb_req_mhold.addr          <= {lce_addr_width_p{1'd0}};
      lce_sb_req_mhold.lru_way_id    <= {way_idx_width_lp{1'd0}};
      lce_sb_req_mhold.lru_dirty     <= e_lce_req_lru_clean;
    end else begin
      lce_sb_req_mhold <= nxt_lce_sb_req_mhold;
    end
  end

  assign nxt_lce_sb_req_mhold = sb_hit ? lce_sb_req : lce_sb_req_mhold;

  //---------------------------------------------------------------------------
  // SB-LCE Data Command Validation:
  //
  always @(posedge clk_i or posedge reset_i) begin : sb_lce_data_cmd_vld_seq
    if (reset_i) begin
      sb_lce_data_cmd_v <= 1'd0;
    end else begin
      sb_lce_data_cmd_v <= nxt_sb_lce_data_cmd_v;
    end
  end

  always @* begin : sb_lce_data_cmd_vld_comb
    if (sb_lce_data_cmd_v) begin
      // Valid SB-LCE request
      if (sb_lce_data_cmd_ready_i) begin
        // LCE ready
        nxt_sb_lce_data_cmd_v = 1'd0;
      end else begin
        // LCE not ready
        nxt_sb_lce_data_cmd_v = 1'd1;
      end
    end else begin
      if (sb_state == e_sb_missed) begin
        // Servicing miss in stream buffer
        if (cce_sb_data_cmd_v_i && cce_sb_data_cmd_ready_o) begin
          // Valid data command from CCE detected
          nxt_sb_lce_data_cmd_v = 1'b1;
        end else begin
          // No valid command from CCE detected
          nxt_sb_lce_data_cmd_v = 1'b0;
        end
      end else begin
        // Either idle or filling FIFOs
        if (sb_hit) begin
          // Hit in stream buffer
          nxt_sb_lce_data_cmd_v = 1'b1;
        end else begin
          // Either no SB access or SB miss
          nxt_sb_lce_data_cmd_v = 1'b0;
        end
      end
    end
  end

  //---------------------------------------------------------------------------
  // SB-LCE Data Command Content:
  //
  always @(posedge clk_i or posedge reset_i) begin : sb_lce_data_cmd_seq
    if (reset_i) begin
      sb_lce_data_cmd.dst_id   <= {lce_idx_width_lp{1'd0}};
      sb_lce_data_cmd.src_id   <= {cce_idx_width_lp{1'd0}};
      sb_lce_data_cmd.msg_type <= e_lce_req_type_rd;
      sb_lce_data_cmd.way_id   <= {way_idx_width_lp{1'd0}};
      sb_lce_data_cmd.addr     <= {lce_addr_width_p{1'd0}};
      sb_lce_data_cmd.data     <= {lce_data_width_p{1'd0}};
    end else begin
      sb_lce_data_cmd <= nxt_sb_lce_data_cmd;
    end
  end

  always @* begin : sb_lce_data_cmd_comb
    if (sb_state == e_sb_missed) begin
      // Servicing miss in stream buffer
      if (cce_sb_data_cmd_v_i && cce_sb_data_cmd_ready_o) begin
        // Valid data command from CCE detected
        nxt_sb_lce_data_cmd = cce_sb_data_cmd;
      end else begin
        // No valid command from CCE detected
        nxt_sb_lce_data_cmd = sb_lce_data_cmd;
      end
    end else begin
      // Either idle or filling FIFOs
      if (sb_hit) begin
        // Hit in stream buffer
        nxt_sb_lce_data_cmd.dst_id   = lce_sb_req.src_id;
        nxt_sb_lce_data_cmd.src_id   = lce_sb_req.dst_id;
        nxt_sb_lce_data_cmd.msg_type = lce_sb_req.msg_type;
        nxt_sb_lce_data_cmd.way_id   = lce_sb_req.lru_way_id;
        nxt_sb_lce_data_cmd.addr     = lce_sb_req.addr;
        nxt_sb_lce_data_cmd.data     = data_fifo[way][rd_ptr[way]];
      end else begin
        // Either no SB access or SB miss
        nxt_sb_lce_data_cmd = sb_lce_data_cmd;
      end
    end
  end

  //---------------------------------------------------------------------------
  // SB-CCE Request Validation:
  //
  always @(posedge clk_i or posedge reset_i) begin : sb_cce_rq_vld_seq
    if (reset_i) begin
      sb_cce_req_v <= 1'd0;
    end else begin
      sb_cce_req_v <= nxt_sb_cce_req_v;
    end
  end

  always @* begin : sb_cce_rq_vld_comb
    if (sb_cce_req_v) begin
      // Valid SB-CCE request
      if (sb_cce_req_ready_i) begin
        // CCE ready
        nxt_sb_cce_req_v = 1'd0;
      end else begin
        // CCE not ready
        nxt_sb_cce_req_v = 1'd1;
      end
    end else begin
      case (sb_state)
        e_sb_idle : begin
          if (sb_miss) begin
            // Miss in stream buffer
            nxt_sb_cce_req_v = 1'd1;
          end else begin
            nxt_sb_cce_req_v = 1'd0;
          end
        end

        e_sb_missed : begin
          // Servicing miss in stream buffer
          if (lce_sb_resp_v_i && lce_sb_resp_ready_o) begin
            // LCE responding to initial cache miss
            nxt_sb_cce_req_v = 1'd1;
          end else begin
            nxt_sb_cce_req_v = 1'd0;
          end
        end

        e_sb_ffill : begin
          // Filling FIFO
          if (sb_miss) begin
            // Miss in stream buffer
            if (cce_sb_cmd_ready_o && cce_sb_cmd_v_i) begin
              // CCE returning command for current entry fill
              nxt_sb_cce_req_v = 1'd1;
            end else begin
              nxt_sb_cce_req_v = 1'd0;
            end
          end else begin
            // No miss in stream buffer
            if (fill_count == sb_depth_m1_lp[sb_idx_width_lp-1:0]) begin
              // Final FIFO entry
              nxt_sb_cce_req_v = 1'd0;
            end else begin
              // Not the final FIFO entry
              if (cce_sb_cmd_ready_o && cce_sb_cmd_v_i) begin
                // CCE returning command for current FIFO entry      
                nxt_sb_cce_req_v = 1'd1;
              end else begin
                nxt_sb_cce_req_v = 1'd0;
              end
            end
          end
        end

        e_sb_mdff : begin
        if (sb_cce_resp_v_o && sb_cce_resp_ready_i) begin
          // Response to current entry fill command detected   
            nxt_sb_cce_req_v = 1'd1;
          end else begin
            nxt_sb_cce_req_v = 1'd0;
          end
        end
      endcase
    end
  end

  //---------------------------------------------------------------------------
  // SB-CCE Request Content:
  //
  always @(posedge clk_i or posedge reset_i) begin : sb_cce_rq_seq
    if (reset_i) begin
      sb_cce_req.dst_id        <= {cce_idx_width_lp{1'd0}};
      sb_cce_req.src_id        <= {lce_idx_width_lp{1'd0}};
      sb_cce_req.msg_type      <= e_lce_req_type_rd;
      sb_cce_req.non_exclusive <= e_lce_req_excl;
      sb_cce_req.addr          <= {lce_addr_width_p{1'd0}};
      sb_cce_req.lru_way_id    <= {way_idx_width_lp{1'd0}};
      sb_cce_req.lru_dirty     <= e_lce_req_lru_clean;
   end else begin
      sb_cce_req <= nxt_sb_cce_req;
    end
  end

  always @* begin : sb_cce_rq_comb
    case (sb_state)
      e_sb_idle : begin
        if (sb_miss) begin
          // Miss in stream buffer
          nxt_sb_cce_req = lce_sb_req;
        end else begin
          nxt_sb_cce_req = sb_cce_req;
        end
      end

      e_sb_missed : begin
        // Servicing miss in stream buffer
        if (lce_sb_resp_v_i && lce_sb_resp_ready_o) begin
          // LCE responding to initial cache miss
          nxt_sb_cce_req.dst_id        = sb_cce_req.dst_id;
          nxt_sb_cce_req.src_id        = sb_cce_req.src_id;
          nxt_sb_cce_req.msg_type      = sb_cce_req.msg_type;
          nxt_sb_cce_req.non_exclusive = sb_cce_req.non_exclusive;
          nxt_sb_cce_req.addr          = sb_cce_req.addr + 
                                         sb_addr_incr_lp[lce_addr_width_p-1:0];
          nxt_sb_cce_req.lru_way_id    = sb_cce_req.lru_way_id;
          nxt_sb_cce_req.lru_dirty     = sb_cce_req.lru_dirty;
        end else begin
          nxt_sb_cce_req = sb_cce_req;
        end
      end

      e_sb_ffill : begin
        // Filling FIFO
        if (sb_miss) begin
          // Miss in stream buffer
          nxt_sb_cce_req = lce_sb_req;           
        end else begin
          if (cce_sb_cmd_ready_o && cce_sb_cmd_v_i) begin
            // CCE returning command for current FIFO entry      
            if (fill_count == sb_depth_m1_lp[sb_idx_width_lp-1:0]) begin
              // Final FIFO entry
              nxt_sb_cce_req.dst_id        = {cce_idx_width_lp{1'd0}};
              nxt_sb_cce_req.src_id        = {lce_idx_width_lp{1'd0}};
              nxt_sb_cce_req.msg_type      = e_lce_req_type_rd;
              nxt_sb_cce_req.non_exclusive = e_lce_req_excl;
              nxt_sb_cce_req.addr          = {lce_addr_width_p{1'd0}};
              nxt_sb_cce_req.lru_way_id    = {way_idx_width_lp{1'd0}};
              nxt_sb_cce_req.lru_dirty     = e_lce_req_lru_clean;
            end else begin
              nxt_sb_cce_req.dst_id        = sb_cce_req.dst_id;
              nxt_sb_cce_req.src_id        = sb_cce_req.src_id;
              nxt_sb_cce_req.msg_type      = sb_cce_req.msg_type;
              nxt_sb_cce_req.non_exclusive = sb_cce_req.non_exclusive;
              nxt_sb_cce_req.addr          = sb_cce_req.addr + 
                                              sb_addr_incr_lp[lce_addr_width_p-1:0];
              nxt_sb_cce_req.lru_way_id    = sb_cce_req.lru_way_id;
              nxt_sb_cce_req.lru_dirty     = sb_cce_req.lru_dirty;
            end
          end else begin
            nxt_sb_cce_req = sb_cce_req;
          end
        end
      end

      e_sb_mdff : nxt_sb_cce_req = sb_cce_req;
    endcase
  end

  //---------------------------------------------------------------------------
  // SB-CCE Response Validation:
  //
  always @(posedge clk_i or posedge reset_i) begin : sb_cce_rsp_vld_seq
    if (reset_i) begin
      sb_cce_resp_v <= 1'd0;
    end else begin
      sb_cce_resp_v <= nxt_sb_cce_resp_v;
    end
  end

  always @* begin : sb_cce_rsp_vld_comb
    if (sb_cce_resp_v) begin
      // Valid SB-CCE response
      if (sb_cce_resp_ready_i) begin
        // CCE ready
        nxt_sb_cce_resp_v = 1'd0;
      end else begin
        // CCE not ready
        nxt_sb_cce_resp_v = 1'd1;
      end
    end else begin
      case (sb_state)
        e_sb_missed : begin
          // Servicing miss in stream buffer
          if (lce_sb_resp_v_i && lce_sb_resp_ready_o) begin
            // LCE responding to initial cache miss
            nxt_sb_cce_resp_v = 1'd1;
          end else begin
            nxt_sb_cce_resp_v = 1'd0;
          end
        end

        e_sb_idle : begin
          if (lce_sb_resp_v_i && lce_sb_resp_ready_o) begin
            // LCE response detected
            if (sb_hit_sticky) begin
              // Response was caused by a hit
              nxt_sb_cce_resp_v = 1'd0;
            end else begin
              // Response caused by CCE initiated command sequence
              nxt_sb_cce_resp_v = 1'd1;
            end
          end else begin
            // No LCE response detected
            nxt_sb_cce_resp_v = 1'd0;
          end
        end

        e_sb_mdff, e_sb_ffill : begin
          // Filling FIFOs
          if (cce_sb_cmd_ready_o && cce_sb_cmd_v_i) begin
            // CCE issued command to fill FIFO
            nxt_sb_cce_resp_v = 1'd1;
          end else begin
            nxt_sb_cce_resp_v = 1'd0;
          end
        end
      endcase
    end
  end

  //---------------------------------------------------------------------------
  // SB-CCE Response Content:
  //
  always @(posedge clk_i or posedge reset_i) begin : sb_cce_rsp_seq
    if (reset_i) begin
      sb_cce_resp.dst_id   <= {cce_idx_width_lp{1'd0}};
      sb_cce_resp.src_id   <= {lce_idx_width_lp{1'd0}};
      sb_cce_resp.msg_type <= e_lce_cce_sync_ack;
      sb_cce_resp.addr     <= {lce_addr_width_p{1'd0}};
    end else begin
      sb_cce_resp <= nxt_sb_cce_resp;
    end
  end

  always @* begin : sb_cce_rsp_comb
    case (sb_state)
      e_sb_missed : begin
        // Servicing miss in stream buffer
        nxt_sb_cce_resp = lce_sb_resp;
      end

      e_sb_idle : begin
        if (lce_sb_resp_v_i && lce_sb_resp_ready_o) begin
          // LCE response detected
          if (sb_hit_sticky) begin
            // Response was caused by a hit
            nxt_sb_cce_resp.dst_id   = {cce_idx_width_lp{1'd0}};
            nxt_sb_cce_resp.src_id   = {lce_idx_width_lp{1'd0}};
            nxt_sb_cce_resp.msg_type = e_lce_cce_sync_ack;
            nxt_sb_cce_resp.addr     = {lce_addr_width_p{1'd0}};
          end else begin
            // Response caused by CCE initiated command sequence
            nxt_sb_cce_resp = lce_sb_resp;
          end
        end else begin
          // No LCE response detected
          nxt_sb_cce_resp.dst_id   = {cce_idx_width_lp{1'd0}};
          nxt_sb_cce_resp.src_id   = {lce_idx_width_lp{1'd0}};
          nxt_sb_cce_resp.msg_type = e_lce_cce_sync_ack;
          nxt_sb_cce_resp.addr     = {lce_addr_width_p{1'd0}};
        end
      end

      e_sb_mdff, e_sb_ffill : begin
        // Filling FIFOs
        if (cce_sb_cmd_ready_o && cce_sb_cmd_v_i) begin
          // CCE issued command to fill FIFO
          nxt_sb_cce_resp.dst_id   = cce_sb_cmd.src_id;
          nxt_sb_cce_resp.src_id   = cce_sb_cmd.dst_id;
          nxt_sb_cce_resp.msg_type = e_lce_cce_coh_ack;
          nxt_sb_cce_resp.addr     = cce_sb_cmd.addr;
        end else begin
          nxt_sb_cce_resp.dst_id   = {cce_idx_width_lp{1'd0}};
          nxt_sb_cce_resp.src_id   = {lce_idx_width_lp{1'd0}};
          nxt_sb_cce_resp.msg_type = e_lce_cce_sync_ack;
          nxt_sb_cce_resp.addr     = {lce_addr_width_p{1'd0}};
        end
      end    
    endcase
  end

  //---------------------------------------------------------------------------
  // FIFO Management
  //
  ///////////////////
  // Read Pointers //
  ///////////////////
  //
  for (ii=0; ii<ways_p; ii=ii+1) begin : rd_ptr_way
    always @(posedge clk_i or posedge reset_i) begin : seq
      if (reset_i) begin
        rd_ptr[ii] <= {sb_idx_width_lp{1'd0}};
      end else begin
        rd_ptr[ii] <= nxt_rd_ptr[ii];
      end
    end

    always @* begin : comb
      if (sb_hit) begin
        // Hit in stream buffer
        if (ii[way_idx_width_lp-1:0] == way) begin
          // Match found in this way
          nxt_rd_ptr[ii] = rd_ptr[ii] - {sb_idx_width_lp{1'd1}}; // += 1
        end else begin
          // Match found in another way
          nxt_rd_ptr[ii] = rd_ptr[ii];
        end
      end else begin
        // No hit in stream buffer
        if (sb_miss) begin
          // Miss in stream buffer
          if (ii[way_idx_width_lp-1:0] == way) begin
          // Miss in this way
            nxt_rd_ptr[ii] = {sb_idx_width_lp{1'd0}};
          end else begin
            // Miss in another way
            nxt_rd_ptr[ii] = rd_ptr[ii];
          end
        end else begin
          // No hit or miss detected
          nxt_rd_ptr[ii] = rd_ptr[ii];
        end
      end
    end
  end

  for (ii=0; ii<ways_p; ii=ii+1) begin : fifo_way
    for (jj=0; jj<sb_depth_p; jj=jj+1) begin : fifo_entry
      always @(posedge clk_i or posedge reset_i) begin : seq
        if (reset_i) begin
          data_fifo[ii][jj]  <= {lce_data_width_p{1'd0}};
          tag_fifo[ii][jj]   <= {sb_tag_width_lp{1'd0}};
          avail_fifo[ii][jj] <= 1'd0;
        end else begin
          data_fifo[ii][jj]  <= nxt_data_fifo[ii][jj];
          tag_fifo[ii][jj]   <= nxt_tag_fifo[ii][jj];
          avail_fifo[ii][jj] <= nxt_avail_fifo[ii][jj];
        end
      end
  
      always @* begin : tag_data_comb
        if (sb_state == e_sb_ffill) begin
          // FIFO being filled without a miss previously being detected
          if (cce_sb_data_cmd_ready_o && cce_sb_data_cmd_v_i) begin
            // CCE returning data command for entry fill
            if (ii[way_idx_width_lp-1:0] == cce_sb_data_cmd.way_id) begin
              // This way is to be written
              if (jj[sb_idx_width_lp-1:0] == fill_count) begin
                // This entry is to be written
                nxt_data_fifo[ii][jj] = cce_sb_data_cmd.data;
                nxt_tag_fifo[ii][jj]  = cce_sb_data_cmd.addr[lce_addr_width_p-1-:sb_tag_width_lp];
              end else begin
                // This is not the entry to be written
                nxt_data_fifo[ii][jj] = data_fifo[ii][jj];
                nxt_tag_fifo[ii][jj]  = tag_fifo[ii][jj];
              end
            end else begin
              // This is not the way to be written
              nxt_data_fifo[ii][jj] = data_fifo[ii][jj];
              nxt_tag_fifo[ii][jj]  = tag_fifo[ii][jj];
            end
          end else begin
            // CCE has not returned data command for entry fill
            nxt_data_fifo[ii][jj] = data_fifo[ii][jj];
            nxt_tag_fifo[ii][jj]  = tag_fifo[ii][jj];
          end
        end else begin
          if (sb_state == e_sb_mdff) begin
            // A miss occurred in SB while SB-CCE transactions are outstanding
            if (cce_sb_data_cmd_ready_o && cce_sb_data_cmd_v_i) begin
              // CCE returning data command for entry fill
              if (ii[way_idx_width_lp-1:0] == cce_sb_data_cmd.way_id) begin
                // This way is to be written
                if (ii[way_idx_width_lp-1:0] != sb_cce_req.lru_way_id) begin
                  // Way of miss does NOT match this one
                  if (jj[sb_idx_width_lp-1:0] == fill_count) begin
                    // This entry is to be written
                    nxt_data_fifo[ii][jj] = cce_sb_data_cmd.data;
                    nxt_tag_fifo[ii][jj]  = cce_sb_data_cmd.addr[lce_addr_width_p-1-:sb_tag_width_lp];
                  end else begin
                    // This is not the entry to be written
                    nxt_data_fifo[ii][jj] = data_fifo[ii][jj];
                    nxt_tag_fifo[ii][jj]  = tag_fifo[ii][jj];
                  end
                end else begin
                  // Way of miss MATCHES this one
                  nxt_data_fifo[ii][jj] = data_fifo[ii][jj];
                  nxt_tag_fifo[ii][jj]  = tag_fifo[ii][jj];
                end
              end else begin
                // This is not the way to be written
                nxt_data_fifo[ii][jj] = data_fifo[ii][jj];
                nxt_tag_fifo[ii][jj]  = tag_fifo[ii][jj];
              end
            end else begin
              // CCE has not returned data command for entry fill
              nxt_data_fifo[ii][jj] = data_fifo[ii][jj];
              nxt_tag_fifo[ii][jj]  = tag_fifo[ii][jj];
            end
          end else begin
            // FIFO is not being filled
            nxt_data_fifo[ii][jj] = data_fifo[ii][jj];
            nxt_tag_fifo[ii][jj]  = tag_fifo[ii][jj];
          end
        end
      end

      always @* begin : avail_comb
        if (sb_miss) begin
          // Miss in stream buffer
          if (ii[way_idx_width_lp-1:0] == way) begin
            // Miss in this way
            nxt_avail_fifo[ii][jj] = 1'd0;
          end else begin
            // Miss in another way
            nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
          end
        end else begin
          // No miss in stream buffer
          if (sb_hit) begin
            // Hit in stream buffer
            if (ii[way_idx_width_lp-1:0] == way) begin
              // Hit in this way
              if (jj[sb_idx_width_lp-1:0] == rd_ptr[ii]) begin
                // Hit in this entry
                nxt_avail_fifo[ii][jj] = 1'd0;
              end else begin
                // Hit in another entry
                nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
              end
            end else begin
              // Hit in another way
              nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
            end
          end else begin
            // No hit in stream buffer
            if (cce_sb_data_cmd_ready_o && cce_sb_data_cmd_v_i) begin
              // CCE returning data command for entry fill
              if (sb_state == e_sb_ffill) begin
                // FIFO being filled without a miss previously being detected
                if (ii[way_idx_width_lp-1:0] == cce_sb_data_cmd.way_id) begin
                  // This way is to be written
                  if (jj[sb_idx_width_lp-1:0] == fill_count) begin
                    // This entry is to be written
                    nxt_avail_fifo[ii][jj] = 1'd1;
                  end else begin
                    // This is not the entry to be written
                    nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
                  end
                end else begin
                  // This is not the way to be written
                  nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
                end
              end else begin
                if (sb_state == e_sb_mdff) begin
                  // A miss occurred in SB while SB-CCE transactions are outstanding
                  if (ii[way_idx_width_lp-1:0] == cce_sb_data_cmd.way_id) begin
                    // This way is to be written
                    if (ii[way_idx_width_lp-1:0] != sb_cce_req.lru_way_id) begin
                      // Way of miss does NOT match this one
                      if (jj[sb_idx_width_lp-1:0] == fill_count) begin
                        // This entry is to be written
                        nxt_avail_fifo[ii][jj] = 1'd1;
                      end else begin
                        // This is not the entry to be written
                        nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
                      end
                    end else begin
                      // Way of miss MATCHES this one
                      nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
                    end
                  end else begin
                    // This is not the way to be written
                    nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
                  end                 
                end else begin
                  // In MISS or IDLE state
                  nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
                end
              end
            end else begin
              // CCE not returning data command for entry fill
              nxt_avail_fifo[ii][jj] = avail_fifo[ii][jj];
            end
          end
        end
      end
    end
  end

  //---------------------------------------------------------------------------
  // LCE-SB/SB-CCE Data:
  // LCE does not deposit data into stream buffer. Feed write data thru to CCE.
  //
  assign sb_cce_data_resp_o       = lce_sb_data_resp_i;
  assign sb_cce_data_resp_v_o     = lce_sb_data_resp_v_i;
  assign lce_sb_data_resp_ready_o = sb_cce_data_resp_ready_i;

  //---------------------------------------------------------------------------
  // Unused
  //
//  wire unused_ok = |{
//                     1'b1};
endmodule
