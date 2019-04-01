// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : bp_be_stream_buffer_tb.sv
// Description    : Unit testbench for bp_tournament_bht
// 
// ============================================================================

// ----------------------------------------------------------------------------
// Out of Module Scope Includes
//  
`include "bp_common_me_if.vh"

// ----------------------------------------------------------------------------
// TB
//  
module bp_be_stream_buffer_tb ();

  // --------------------------------------------------------------------------
  // Parameters / Localparams
  // Including parameters here of possile override at command line
  //
  ///////////////////////
  // DUT Configuration //
  ///////////////////////
  //
  parameter num_cce_p        = 32'd1;
  parameter num_lce_p        = 32'd2;
  parameter lce_addr_width_p = 32'd22;
  parameter lce_data_width_p = 32'd128;
  parameter ways_p           = 32'd2;
  parameter sb_depth_p       = 32'd4;

  localparam way_idx_width_lp = (ways_p    == 32'd1) ? 32'd1 : $clog2(ways_p);
  localparam lce_idx_width_lp = (num_lce_p == 32'd1) ? 32'd1 : $clog2(num_lce_p);
  localparam cce_idx_width_lp = (num_cce_p == 32'd1) ? 32'd1 : $clog2(num_cce_p);

  localparam lce_cce_req_width_lp       =`bp_lce_cce_req_width       (num_cce_p, num_lce_p, lce_addr_width_p,                    ways_p);
  localparam lce_cce_resp_width_lp      =`bp_lce_cce_resp_width      (num_cce_p, num_lce_p, lce_addr_width_p                           );
  localparam lce_cce_data_resp_width_lp =`bp_lce_cce_data_resp_width (num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);

  localparam cce_lce_cmd_width_lp      = `bp_cce_lce_cmd_width       (num_cce_p, num_lce_p, lce_addr_width_p,                    ways_p);
  localparam cce_lce_data_cmd_width_lp = `bp_cce_lce_data_cmd_width  (num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);

  localparam sb_idx_width_lp = (sb_depth_p == 32'd1) ? 32'd1 : $clog2(sb_depth_p);

  localparam sb_addr_incr_lp = lce_data_width_p/32'd8;

  localparam sb_data_mult = lce_data_width_p/32'd32;

  ////////////////////////
  // Simulation Control //
  ////////////////////////
  //
  parameter TIMEOUT = 32'd1000000;
  parameter SEED    = 32'd1;
  parameter WARMUP  = 32'd0;

  //---------------------------------------------------------------------------
  // Internal Signals
  //
  `declare_bp_lce_cce_req_s       (num_cce_p, num_lce_p, lce_addr_width_p,                   ways_p);
  `declare_bp_lce_cce_resp_s      (num_cce_p, num_lce_p, lce_addr_width_p);
  `declare_bp_lce_cce_data_resp_s (num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p);
  `declare_bp_cce_lce_cmd_s       (num_cce_p, num_lce_p, lce_addr_width_p,                   ways_p);
  `declare_bp_cce_lce_data_cmd_s  (num_cce_p, num_lce_p, lce_addr_width_p, lce_data_width_p, ways_p);

  ///////////////////////
  // Clocks and Resets //
  ///////////////////////
  //
  logic reset_i;

  logic clk_i;

  //////////////////////
  // LCE-SB Interface //
  //////////////////////
  //
  bp_lce_cce_req_s lce_sb_req_i;
  logic            lce_sb_req_v_i;
  logic            lce_sb_req_ready_o;

  bp_lce_cce_resp_s lce_sb_resp_i;
  logic             lce_sb_resp_v_i;
  logic             lce_sb_resp_ready_o;

  bp_lce_cce_data_resp_s lce_sb_data_resp_i;
  logic                  lce_sb_data_resp_v_i;
  logic                  lce_sb_data_resp_ready_o;

  //////////////////////
  // SB-LCE Interface //
  //////////////////////
  //
  bp_cce_lce_cmd_s sb_lce_cmd_o;
  logic            sb_lce_cmd_v_o;
  logic            sb_lce_cmd_ready_i;

  bp_cce_lce_data_cmd_s sb_lce_data_cmd_o;
  logic                 sb_lce_data_cmd_v_o;
  logic                 sb_lce_data_cmd_ready_i;

  //////////////////////
  // SB-CCE Interface //
  //////////////////////
  //
  bp_lce_cce_req_s sb_cce_req_o;
  logic            sb_cce_req_v_o;
  logic            sb_cce_req_ready_i;

  bp_lce_cce_resp_s sb_cce_resp_o;
  logic             sb_cce_resp_v_o;
  logic             sb_cce_resp_ready_i;

  bp_lce_cce_data_resp_s sb_cce_data_resp_o;
  logic                  sb_cce_data_resp_v_o;
  logic                  sb_cce_data_resp_ready_i;

  //////////////////////
  // CCE-SB Interface //
  //////////////////////
  //
  bp_cce_lce_cmd_s cce_sb_cmd_i;
  logic            cce_sb_cmd_v_i;
  logic            cce_sb_cmd_ready_o;

  bp_cce_lce_data_cmd_s cce_sb_data_cmd_i;
  logic                 cce_sb_data_cmd_v_i;
  logic                 cce_sb_data_cmd_ready_o;

  ///////////////////////////
  // Test Stimulus Control //
  ///////////////////////////
  //
  integer seed = SEED;

  logic [lce_addr_width_p-1:0] addr0;

  string test_phase = "";

  // ---------------------------------------------------------------------------
  // DUT Instance
  //
  bp_be_stream_buffer #(
    .num_cce_p        (num_cce_p),
    .num_lce_p        (num_lce_p),
    .lce_addr_width_p (lce_addr_width_p),
    .lce_data_width_p (lce_data_width_p),
    .ways_p           (ways_p),
    .sb_depth_p       (sb_depth_p)
  ) DUT (
    // Clocks and Resets
    .reset_i (reset_i), // (I) Reset, active high

    .clk_i   (clk_i),   // (I) Clock

    // LCE-SB Interface
    .lce_sb_req_i       (lce_sb_req_i),       // (I)
    .lce_sb_req_v_i     (lce_sb_req_v_i),     // (I)
    .lce_sb_req_ready_o (lce_sb_req_ready_o), // (O)

    .lce_sb_resp_i       (lce_sb_resp_i),       // (I)
    .lce_sb_resp_v_i     (lce_sb_resp_v_i),     // (I)
    .lce_sb_resp_ready_o (lce_sb_resp_ready_o), // (O)

    .lce_sb_data_resp_i       (lce_sb_data_resp_i),       // (I)
    .lce_sb_data_resp_v_i     (lce_sb_data_resp_v_i),     // (I)
    .lce_sb_data_resp_ready_o (lce_sb_data_resp_ready_o), // (O)

    // SB-LCE Interface
    .sb_lce_cmd_o       (sb_lce_cmd_o),            // (O)
    .sb_lce_cmd_v_o     (sb_lce_cmd_v_o),          // (O)
    .sb_lce_cmd_ready_i (sb_lce_cmd_ready_i),      // (I)

    .sb_lce_data_cmd_o       (sb_lce_data_cmd_o),       // (O)
    .sb_lce_data_cmd_v_o     (sb_lce_data_cmd_v_o),     // (O)
    .sb_lce_data_cmd_ready_i (sb_lce_data_cmd_ready_i), // (I)

    // SB-CCE Interface
    .sb_cce_req_o       (sb_cce_req_o),             // (O)
    .sb_cce_req_v_o     (sb_cce_req_v_o),           // (O)
    .sb_cce_req_ready_i (sb_cce_req_ready_i),       // (I)

    .sb_cce_resp_o       (sb_cce_resp_o),            // (O)
    .sb_cce_resp_v_o     (sb_cce_resp_v_o),          // (O)
    .sb_cce_resp_ready_i (sb_cce_resp_ready_i),      // (I)

    .sb_cce_data_resp_o       (sb_cce_data_resp_o),       // (O)
    .sb_cce_data_resp_v_o     (sb_cce_data_resp_v_o),     // (O)
    .sb_cce_data_resp_ready_i (sb_cce_data_resp_ready_i), // (I)

    // CCE-SB Interface
    .cce_sb_cmd_i       (cce_sb_cmd_i),       // (I)
    .cce_sb_cmd_v_i     (cce_sb_cmd_v_i),     // (I)
    .cce_sb_cmd_ready_o (cce_sb_cmd_ready_o), // (O)

    .cce_sb_data_cmd_i       (cce_sb_data_cmd_i),       // (I)
    .cce_sb_data_cmd_v_i     (cce_sb_data_cmd_v_i),     // (I)
    .cce_sb_data_cmd_ready_o (cce_sb_data_cmd_ready_o)  // (O)

);

  // ---------------------------------------------------------------------------
  // Reset Generation
  //
  initial begin : rst_gen
        reset_i <= 1'b0;  // initailize reset to inactive
    #10 reset_i <= 1'b1;  // Assert reset on negedge of clock
    #10 reset_i <= 1'b0;  // De-assert reset on negedge of clock
  end
    
  // ---------------------------------------------------------------------------
  // Clock Generation
  //
  initial begin : clk_gen
    clk_i <= 1'b0;
    forever begin
      #5 clk_i <= ~clk_i;
    end
  end

  // ---------------------------------------------------------------------------
  // Test Stimulus
  //
  initial begin
    test_phase = "Reset Phase";

    // For simplicity all ready inputs ready
    sb_lce_cmd_ready_i       <= 1'd1;
    sb_lce_data_cmd_ready_i  <= 1'd1;
    sb_cce_req_ready_i       <= 1'd1;
    sb_cce_resp_ready_i      <= 1'd1;
    sb_cce_data_resp_ready_i <= 1'd1;

    #21; // 1ns after reset

    // ---------------------------------------------------------------------------
    // Scenario 0:
    //   1) Request for data in stream buffer
    //   2) Request results in a miss
    //   3) Service miss
    //   4) Fill FIFO before next request from LCE
    //
    test_phase = "Scenario 0";

    ////////////////////
    // LCE-SB Request //
    ////////////////////
    //
    addr0 = $random(seed);
    
    lce_sb_req_v_i             <= 1'd1;
    
    lce_sb_req_i.dst_id        <= 1'd0;              // CCE 0
    lce_sb_req_i.src_id        <= 1'd1;              // Data $
    lce_sb_req_i.msg_type      <= e_lce_req_type_rd;
    lce_sb_req_i.non_exclusive <= e_lce_req_excl;
    lce_sb_req_i.addr          <= addr0;
    lce_sb_req_i.lru_way_id    <= 'd0;
    lce_sb_req_i.lru_dirty     <= e_lce_req_lru_clean;

    #10;
    lce_sb_req_v_i             <= 1'd0;

    #10;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;

    cce_sb_data_cmd_i.dst_id   <= 1'd1;
    cce_sb_data_cmd_i.src_id   <= 1'd0;
    cce_sb_data_cmd_i.msg_type <= sb_cce_req_o.msg_type;
    cce_sb_data_cmd_i.way_id   <= 'd0;
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
    
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;

    cce_sb_cmd_i.dst_id        <= 1'd1;
    cce_sb_cmd_i.src_id        <= 1'd0;
    cce_sb_cmd_i.msg_type      <= e_lce_cmd_set_tag;
    cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
    cce_sb_cmd_i.way_id        <= 'd0;
    cce_sb_cmd_i.state         <= 'd2;
    cce_sb_cmd_i.target        <= 'd0;
    cce_sb_cmd_i.target_way_id <= 'd0;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;
   
    #10;

    /////////////////////
    // LCE-SB Response //
    /////////////////////
    //
    lce_sb_resp_v_i        <= 1'd1;

    lce_sb_resp_i.dst_id   <= 1'd0;
    lce_sb_resp_i.src_id   <= 1'd1;
    lce_sb_resp_i.msg_type <= e_lce_cce_coh_ack;
    lce_sb_resp_i.addr     <= sb_lce_cmd_o.addr;
    
    #10;
    lce_sb_resp_v_i     <= 1'd0;

    ///////////////////////////////////////
    // SB-CCE Commands and Data Commands //
    ///////////////////////////////////////
    //
    repeat (4) begin
      #10;

      /////////////////////////
      // CCE-SB Data Command //
      /////////////////////////
      //
      cce_sb_data_cmd_v_i        <= 1'd1;
      
      cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
      cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
      
      #10;
      cce_sb_data_cmd_v_i        <= 1'd0;
      
      ////////////////////
      // CCE-SB Command //
      ////////////////////
      //
      cce_sb_cmd_v_i             <= 1'd1;
      
      cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
      
      #10;
      cce_sb_cmd_v_i             <= 1'd0;
    end

    // ---------------------------------------------------------------------------
    // Scenario 1:
    //   1) Request for all data in stream buffer sequentially
    //   2) Request results in a hit every time
    //
    test_phase = "Scenario 1";

    repeat (4) begin
      ////////////////////
      // LCE-SB Request //
      ////////////////////
      //
      addr0 = addr0 + sb_addr_incr_lp;
      
      lce_sb_req_v_i             <= 1'd1;
      
      lce_sb_req_i.dst_id        <= 1'd0;              // CCE 0
      lce_sb_req_i.src_id        <= 1'd1;              // Data $
      lce_sb_req_i.msg_type      <= e_lce_req_type_rd;
      lce_sb_req_i.non_exclusive <= e_lce_req_excl;
      lce_sb_req_i.addr          <= addr0;
      lce_sb_req_i.lru_way_id    <= 'd0;
      lce_sb_req_i.lru_dirty     <= e_lce_req_lru_clean;
      
      #10;
      lce_sb_req_v_i             <= 1'd0;
      
      #20;
      
      /////////////////////
      // LCE-SB Response //
      /////////////////////
      //
      lce_sb_resp_v_i        <= 1'd1;
      
      lce_sb_resp_i.dst_id   <= 1'd0;
      lce_sb_resp_i.src_id   <= 1'd1;
      lce_sb_resp_i.msg_type <= e_lce_cce_coh_ack;
      lce_sb_resp_i.addr     <= sb_lce_cmd_o.addr;
      
      #10;
      lce_sb_resp_v_i     <= 1'd0;
    end

    // ---------------------------------------------------------------------------
    // Scenario 2:
    //   1) Request for data in stream buffer
    //   2) Request results in a miss
    //   3) Service miss
    //   4) Start filling FIFO
    //   5) New request for data results in a miss during CCE-SB Command transfer
    //
    test_phase = "Scenario 2";

    ////////////////////
    // LCE-SB Request //
    ////////////////////
    //
    addr0 = $random(seed);
    
    lce_sb_req_v_i             <= 1'd1;
    
    lce_sb_req_i.dst_id        <= 1'd0;              // CCE 0
    lce_sb_req_i.src_id        <= 1'd1;              // Data $
    lce_sb_req_i.msg_type      <= e_lce_req_type_rd;
    lce_sb_req_i.non_exclusive <= e_lce_req_excl;
    lce_sb_req_i.addr          <= addr0;
    lce_sb_req_i.lru_way_id    <= 'd0;
    lce_sb_req_i.lru_dirty     <= e_lce_req_lru_clean;

    #10;
    lce_sb_req_v_i             <= 1'd0;

    #10;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;

    cce_sb_data_cmd_i.dst_id   <= 1'd1;
    cce_sb_data_cmd_i.src_id   <= 1'd0;
    cce_sb_data_cmd_i.msg_type <= sb_cce_req_o.msg_type;
    cce_sb_data_cmd_i.way_id   <= 'd0;
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
    
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;
    
    cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;

    #10;

    /////////////////////
    // LCE-SB Response //
    /////////////////////
    //
    lce_sb_resp_v_i        <= 1'd1;

    lce_sb_resp_i.dst_id   <= 1'd0;
    lce_sb_resp_i.src_id   <= 1'd1;
    lce_sb_resp_i.msg_type <= e_lce_cce_coh_ack;
    lce_sb_resp_i.addr     <= sb_lce_cmd_o.addr;
    
    #10;
    lce_sb_resp_v_i     <= 1'd0;

    #10;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;
    
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
      
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    addr0 = $random(seed);

    cce_sb_cmd_v_i             <= 1'd1;

    cce_sb_cmd_i.dst_id        <= 1'd1;
    cce_sb_cmd_i.src_id        <= 1'd0;
    cce_sb_cmd_i.msg_type      <= e_lce_cmd_set_tag;
    cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
    cce_sb_cmd_i.way_id        <= 'd0;
    cce_sb_cmd_i.state         <= 'd2;
    cce_sb_cmd_i.target        <= 'd0;
    cce_sb_cmd_i.target_way_id <= 'd0;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;
   
    #10;

    ////////////////////////////////////////////
    // CCE-SB Data Command and LCE-SB Request //
    ////////////////////////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;
    lce_sb_req_v_i             <= 1'd1;
    
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    lce_sb_req_i.dst_id        <= 1'd0;              // CCE 0
    lce_sb_req_i.src_id        <= 1'd1;              // Data $
    lce_sb_req_i.msg_type      <= e_lce_req_type_rd;
    lce_sb_req_i.non_exclusive <= e_lce_req_excl;
    lce_sb_req_i.addr          <= addr0;
    lce_sb_req_i.lru_way_id    <= 'd0;
    lce_sb_req_i.lru_dirty     <= e_lce_req_lru_clean;

    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
    lce_sb_req_v_i             <= 1'd0;
      
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;
    
    cce_sb_cmd_i.addr          <= cce_sb_data_cmd_i.addr;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;

    #20;
 
    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;

    cce_sb_data_cmd_i.dst_id   <= 1'd1;
    cce_sb_data_cmd_i.src_id   <= 1'd0;
    cce_sb_data_cmd_i.msg_type <= sb_cce_req_o.msg_type;
    cce_sb_data_cmd_i.way_id   <= 'd0;
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
    
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;

    cce_sb_cmd_i.dst_id        <= 1'd1;
    cce_sb_cmd_i.src_id        <= 1'd0;
    cce_sb_cmd_i.msg_type      <= e_lce_cmd_set_tag;
    cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
    cce_sb_cmd_i.way_id        <= 'd0;
    cce_sb_cmd_i.state         <= 'd2;
    cce_sb_cmd_i.target        <= 'd0;
    cce_sb_cmd_i.target_way_id <= 'd0;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;
   
    #10;

    /////////////////////
    // LCE-SB Response //
    /////////////////////
    //
    lce_sb_resp_v_i        <= 1'd1;

    lce_sb_resp_i.dst_id   <= 1'd0;
    lce_sb_resp_i.src_id   <= 1'd1;
    lce_sb_resp_i.msg_type <= e_lce_cce_coh_ack;
    lce_sb_resp_i.addr     <= sb_lce_cmd_o.addr;
    
    #10;
    lce_sb_resp_v_i     <= 1'd0;

    ///////////////////////////////////////
    // SB-CCE Commands and Data Commands //
    ///////////////////////////////////////
    //
    repeat (4) begin
      #10;

      /////////////////////////
      // CCE-SB Data Command //
      /////////////////////////
      //
      cce_sb_data_cmd_v_i        <= 1'd1;
      
      cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
      cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
      
      #10;
      cce_sb_data_cmd_v_i        <= 1'd0;
      
      ////////////////////
      // CCE-SB Command //
      ////////////////////
      //
      cce_sb_cmd_v_i             <= 1'd1;
      
      cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
      
      #10;
      cce_sb_cmd_v_i             <= 1'd0;
    end

    #10;

    // ---------------------------------------------------------------------------
    // Scenario 3:
    //   1) Request for data in stream buffer
    //   2) Request results in a miss
    //   3) Service miss
    //   4) Start filling FIFO
    //   5) New request for data results in a miss NOT during CCE-SB Command transfer
    //
    test_phase = "Scenario 3";

    ////////////////////
    // LCE-SB Request //
    ////////////////////
    //
    addr0 = $random(seed);
    
    lce_sb_req_v_i             <= 1'd1;
    
    lce_sb_req_i.dst_id        <= 1'd0;              // CCE 0
    lce_sb_req_i.src_id        <= 1'd1;              // Data $
    lce_sb_req_i.msg_type      <= e_lce_req_type_rd;
    lce_sb_req_i.non_exclusive <= e_lce_req_excl;
    lce_sb_req_i.addr          <= addr0;
    lce_sb_req_i.lru_way_id    <= 'd1;
    lce_sb_req_i.lru_dirty     <= e_lce_req_lru_clean;

    #10;
    lce_sb_req_v_i             <= 1'd0;

    #10;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;

    cce_sb_data_cmd_i.dst_id   <= 1'd1;
    cce_sb_data_cmd_i.src_id   <= 1'd0;
    cce_sb_data_cmd_i.msg_type <= sb_cce_req_o.msg_type;
    cce_sb_data_cmd_i.way_id   <= 'd1;
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
    
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;
    
    cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;

    #10;

    /////////////////////
    // LCE-SB Response //
    /////////////////////
    //
    lce_sb_resp_v_i        <= 1'd1;

    lce_sb_resp_i.dst_id   <= 1'd0;
    lce_sb_resp_i.src_id   <= 1'd1;
    lce_sb_resp_i.msg_type <= e_lce_cce_coh_ack;
    lce_sb_resp_i.addr     <= sb_lce_cmd_o.addr;
    
    #10;
    lce_sb_resp_v_i     <= 1'd0;

    #10;

    ////////////////////
    // LCE-SB Request //
    ////////////////////
    //
    addr0 = $random(seed);
    
    lce_sb_req_v_i             <= 1'd1;
    
    lce_sb_req_i.dst_id        <= 1'd0;              // CCE 0
    lce_sb_req_i.src_id        <= 1'd1;              // Data $
    lce_sb_req_i.msg_type      <= e_lce_req_type_rd;
    lce_sb_req_i.non_exclusive <= e_lce_req_excl;
    lce_sb_req_i.addr          <= addr0;
    lce_sb_req_i.lru_way_id    <= 'd1;
    lce_sb_req_i.lru_dirty     <= e_lce_req_lru_clean;

    #10;
    lce_sb_req_v_i             <= 1'd0;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;
    
    cce_sb_data_cmd_i.addr     <= sb_lce_cmd_o.addr + sb_addr_incr_lp;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
      
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;
    
    cce_sb_cmd_i.addr          <= cce_sb_data_cmd_i.addr;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;

    #20;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;
    
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
      
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;
    
    cce_sb_cmd_i.addr          <= cce_sb_data_cmd_i.addr;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;

    #10;

    /////////////////////
    // LCE-SB Response //
    /////////////////////
    //
    lce_sb_resp_v_i        <= 1'd1;

    lce_sb_resp_i.dst_id   <= 1'd0;
    lce_sb_resp_i.src_id   <= 1'd1;
    lce_sb_resp_i.msg_type <= e_lce_cce_coh_ack;
    lce_sb_resp_i.addr     <= sb_lce_cmd_o.addr;
    
    #10;
    lce_sb_resp_v_i     <= 1'd0;

    ///////////////////////////////////////
    // SB-CCE Commands and Data Commands //
    ///////////////////////////////////////
    //
    repeat (4) begin
      #10;

      /////////////////////////
      // CCE-SB Data Command //
      /////////////////////////
      //
      cce_sb_data_cmd_v_i        <= 1'd1;
      
      cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
      cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
      
      #10;
      cce_sb_data_cmd_v_i        <= 1'd0;
      
      ////////////////////
      // CCE-SB Command //
      ////////////////////
      //
      cce_sb_cmd_v_i             <= 1'd1;
      
      cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
      
      #10;
      cce_sb_cmd_v_i             <= 1'd0;
    end

    #10;

    // ---------------------------------------------------------------------------
    // Scenario 4:
    //   1) Request for data in stream buffer way 0
    //   2) Request results in a miss
    //   3) Service miss
    //   4) Start filling FIFO
    //   5) New request for data results in a miss in way 1
    //
    test_phase = "Scenario 4";

    ////////////////////
    // LCE-SB Request //
    ////////////////////
    //
    addr0 = $random(seed);
    
    lce_sb_req_v_i             <= 1'd1;
    
    lce_sb_req_i.dst_id        <= 1'd0;              // CCE 0
    lce_sb_req_i.src_id        <= 1'd1;              // Data $
    lce_sb_req_i.msg_type      <= e_lce_req_type_rd;
    lce_sb_req_i.non_exclusive <= e_lce_req_excl;
    lce_sb_req_i.addr          <= addr0;
    lce_sb_req_i.lru_way_id    <= 'd0;
    lce_sb_req_i.lru_dirty     <= e_lce_req_lru_clean;

    #10;
    lce_sb_req_v_i             <= 1'd0;

    #10;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;

    cce_sb_data_cmd_i.dst_id   <= 1'd1;
    cce_sb_data_cmd_i.src_id   <= 1'd0;
    cce_sb_data_cmd_i.msg_type <= sb_cce_req_o.msg_type;
    cce_sb_data_cmd_i.way_id   <= 'd0;
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
    
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;

    cce_sb_cmd_i.dst_id        <= 1'd1;
    cce_sb_cmd_i.src_id        <= 1'd0;
    cce_sb_cmd_i.msg_type      <= e_lce_cmd_set_tag;
    cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
    cce_sb_cmd_i.way_id        <= 'd0;
    cce_sb_cmd_i.state         <= 'd2;
    cce_sb_cmd_i.target        <= 'd0;
    cce_sb_cmd_i.target_way_id <= 'd0;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;
   
    #10;

    /////////////////////
    // LCE-SB Response //
    /////////////////////
    //
    lce_sb_resp_v_i        <= 1'd1;

    lce_sb_resp_i.dst_id   <= 1'd0;
    lce_sb_resp_i.src_id   <= 1'd1;
    lce_sb_resp_i.msg_type <= e_lce_cce_coh_ack;
    lce_sb_resp_i.addr     <= sb_lce_cmd_o.addr;
    
    #10;
    lce_sb_resp_v_i     <= 1'd0;

    #10;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;
    
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
      
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;
    
    cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;

    ////////////////////
    // LCE-SB Request //
    ////////////////////
    //
    addr0 = $random(seed);
    
    lce_sb_req_v_i             <= 1'd1;
    
    lce_sb_req_i.dst_id        <= 1'd0;              // CCE 0
    lce_sb_req_i.src_id        <= 1'd1;              // Data $
    lce_sb_req_i.msg_type      <= e_lce_req_type_rd;
    lce_sb_req_i.non_exclusive <= e_lce_req_excl;
    lce_sb_req_i.addr          <= addr0;
    lce_sb_req_i.lru_way_id    <= 'd1;
    lce_sb_req_i.lru_dirty     <= e_lce_req_lru_clean;

    #10;
    lce_sb_req_v_i             <= 1'd0;

    #10;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;
    
    cce_sb_data_cmd_i.addr     <= cce_sb_cmd_i.addr + sb_addr_incr_lp;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    cce_sb_data_cmd_i.way_id   <= 'd0;
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
      
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;
    
    cce_sb_cmd_i.addr          <= cce_sb_data_cmd_i.addr;
    cce_sb_cmd_i.way_id        <= 'd0;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;

    #30;

    /////////////////////////
    // CCE-SB Data Command //
    /////////////////////////
    //
    cce_sb_data_cmd_v_i        <= 1'd1;
    
    cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
    cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
    cce_sb_data_cmd_i.way_id   <= 'd1;
    
    #10;
    cce_sb_data_cmd_v_i        <= 1'd0;
      
    ////////////////////
    // CCE-SB Command //
    ////////////////////
    //
    cce_sb_cmd_v_i             <= 1'd1;
    
    cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
    cce_sb_cmd_i.way_id        <= 'd1;
    
    #10;
    cce_sb_cmd_v_i             <= 1'd0;

    #10;

    /////////////////////
    // LCE-SB Response //
    /////////////////////
    //
    lce_sb_resp_v_i        <= 1'd1;

    lce_sb_resp_i.dst_id   <= 1'd0;
    lce_sb_resp_i.src_id   <= 1'd1;
    lce_sb_resp_i.msg_type <= e_lce_cce_coh_ack;
    lce_sb_resp_i.addr     <= sb_lce_cmd_o.addr;
    
    #10;
    lce_sb_resp_v_i     <= 1'd0;

    ///////////////////////////////////////
    // SB-CCE Commands and Data Commands //
    ///////////////////////////////////////
    //
    repeat (4) begin
      #10;

      /////////////////////////
      // CCE-SB Data Command //
      /////////////////////////
      //
      cce_sb_data_cmd_v_i        <= 1'd1;
      
      cce_sb_data_cmd_i.addr     <= sb_cce_req_o.addr;
      cce_sb_data_cmd_i.data     <= {sb_data_mult{$random(seed)}};
      
      #10;
      cce_sb_data_cmd_v_i        <= 1'd0;
      
      ////////////////////
      // CCE-SB Command //
      ////////////////////
      //
      cce_sb_cmd_v_i             <= 1'd1;
      
      cce_sb_cmd_i.addr          <= sb_cce_req_o.addr;
      
      #10;
      cce_sb_cmd_v_i             <= 1'd0;
    end

    #10;
    $display("Simulation Finished after providing stimulus");
    $finish();
  end
  // ---------------------------------------------------------------------------
  // Simulation Control
  //
  initial begin
    #(TIMEOUT);
    $display("Simulation Finished via TIMEOUT");
    $finish;
  end

endmodule

