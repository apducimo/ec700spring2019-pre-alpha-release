// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : bp_tournament_predictor.v
// Description    : Black Parrot Tournament Branch Predictor
// 
// ============================================================================

module bp_tournament_bht (
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

  /////////////////////////////////
  // Branch History Table Access //
  /////////////////////////////////
  //
  //bht_r_i,    // (I) Read enable
  bht_r_pc_i, // (I) Read address

  bht_w_i,    // (I) Write enable
  bht_w_pc_i, // (I) Write Address
    
    
  /////////////////////////////
  // Branch Outcome/Feedback //
  /////////////////////////////
  //
  predict_o, // (O) Prediction outcome

  correct_i  // (I) Prediction result
  
);

  // ---------------------------------------------------------------------------
  // Parameters / Localparams
  //
  ///////////
  // Misc. //
  ///////////
  //
  // Width of PC
  parameter PC_W = 32'd32;

  ////////////
  // PShare //
  ////////////
  //
  // PHT index width
  parameter PPHT_IDXW = 32'd5;

  // PHT depth
  localparam PPHT_D = 32'd2**PPHT_IDXW;

  // PHT width
  parameter PPHT_W = 32'd5;

  // BHT depth
  localparam PBHT_D = 32'd2**PPHT_W;
  
  ////////////
  // GShare //
  ////////////
  //
  // Global pattern regsiter width
  parameter GH_W = 32'd5;
  
  // BHT depth
  localparam GBHT_D = 32'd2**GH_W;
  
  ////////////////////
  // Meta Predictor //
  ////////////////////
  //
  // Counter table index width
  parameter META_IDXW = 32'd5;
  
  // Counter table depth
  localparam META_D = 32'd2**META_IDXW;

  // ---------------------------------------------------------------------------
  // Module Port Declarations
  //
  ///////////////////////
  // Clocks and Resets //
  ///////////////////////
  //
  input reset_i;

  input clk_i;

  /////////////////////////////////
  // Branch History Table Access //
  /////////////////////////////////
  //
  //input            bht_r_i;
  input [PC_W-1:0] bht_r_pc_i;

  input            bht_w_i;
  input [PC_W-1:0] bht_w_pc_i;
    
  /////////////////////////////
  // Branch Outcome/Feedback //
  /////////////////////////////
  //
  output predict_o;

  input  correct_i;

  //---------------------------------------------------------------------------
  // Internal Signals
  //
  ////////////
  // PShare //
  ////////////
  //
  // PHT
  wire [PPHT_IDXW-1:0] ppht_r_idx;
  wire [PPHT_IDXW-1:0] ppht_w_idx;

  reg     [PPHT_W-1:0] ppht     [PPHT_D-1:0];
  reg     [PPHT_W-1:0] nxt_ppht [PPHT_D-1:0];

//  reg     [PPHT_W-1:0] ppht_for_w;
//  wire    [PPHT_W-1:0] nxt_ppht_for_w;

  // BHT
  wire [PPHT_W-1:0] pbht_r_idx;
  wire [PPHT_W-1:0] pbht_w_idx;

  reg         [1:0] pbht     [PBHT_D-1:0];
  reg         [1:0] nxt_pbht [PBHT_D-1:0];

  // Result
  wire p_res_r;
  wire p_res_w;

//  reg  [1:0] pbht_for_w;
//  wire [1:0] nxt_pbht_for_w;

  ////////////
  // GShare //
  ////////////
  //
  // Global pattern register
  reg [GH_W-1:0] glbl_patt;
  reg [GH_W-1:0] nxt_glbl_patt;

//  reg  [GH_W-1:0] glbl_patt_for_w;
//  wire [GH_W-1:0] nxt_glbl_patt_for_w;

  // BHT
  wire [GH_W-1:0] gbht_r_idx;
  wire [GH_W-1:0] gbht_w_idx;

  reg       [1:0] gbht     [GBHT_D-1:0];
  reg       [1:0] nxt_gbht [GBHT_D-1:0];

  // Result
  wire g_res_r;
  wire g_res_w;

//  reg  [1:0] gbht_for_w;
//  wire [1:0] nxt_gbht_for_w;

  ////////////////////
  // Meta Predictor //
  ////////////////////
  //
  wire [META_IDXW-1:0] m2bc_r_idx;
  wire [META_IDXW-1:0] m2bc_w_idx;

  reg            [1:0] m2bc     [META_D-1:0];
  reg            [1:0] nxt_m2bc [META_D-1:0];

  // Result
  wire m_res_r;
  wire m_res_w;

//  reg  [1:0] m2bc_for_w;
//  wire [1:0] nxt_m2bc_for_w;

  ///////////
  // Misc. //
  ///////////
  //
  genvar ii;

//  reg  predict_for_w;
//  wire nxt_predict_for_w;

//  wire branch_dir_for_w;

  wire assumed_branch_dir_for_w;
  wire assumed_predict_for_w;

  //---------------------------------------------------------------------------
  // PShare
  //
  ////////////////////////////
  // Generate Table Indexes //
  ////////////////////////////
  //
  // PHT indexes
  assign ppht_r_idx = bht_r_pc_i[PPHT_IDXW+1:2];
  assign ppht_w_idx = bht_w_pc_i[PPHT_IDXW+1:2];
 
  // BHT indexes
  assign pbht_r_idx = ppht[ppht_r_idx] ^ bht_r_pc_i[PPHT_W+1:2];
//  assign pbht_w_idx = ppht_for_w       ^ bht_w_pc_i[PPHT_W+1:2];
  assign pbht_w_idx = ppht[ppht_w_idx] ^ bht_w_pc_i[PPHT_W+1:2];

  /////////////
  // Predict //
  /////////////
  //
  assign p_res_r = pbht[pbht_r_idx][1];
  assign p_res_w = pbht[pbht_w_idx][1];

  ////////////////////////
  // Prediction Storage //
  ////////////////////////
  //
  // Store Pshare pattern and prediction result to prevent having to re-read
  // prediction result when updating
//  always @(posedge clk_i or posedge reset_i) begin : pshare_hold_seq
//    if (reset_i) begin
//      ppht_for_w <= {PPHT_W{1'd0}};
//      pbht_for_w <= 2'd0;
//    end else begin
//      ppht_for_w <= nxt_ppht_for_w;
//      pbht_for_w <= nxt_pbht_for_w;
//    end
//  end

//  // Only update holding resgiters when prediction is made.
//  assign nxt_ppht_for_w = (bht_r_i) ? ppht[ppht_r_idx] : ppht_for_w;
//  assign nxt_pbht_for_w = (bht_r_i) ? pbht[pbht_r_idx] : pbht_for_w;
  
  ////////////////
  // PHT Update //
  ////////////////
  //
  for (ii=0; ii<PPHT_D; ii=ii+1) begin : ppht_entry

    always @ (posedge clk_i or posedge reset_i) begin : seq
      if (reset_i) begin
        ppht[ii] <= {PPHT_W{1'd0}};
      end else begin
        ppht[ii] <= nxt_ppht[ii];
      end
    end
  
    always @* begin : comb
      if (bht_w_i) begin
        // Update required
        if (ii[PPHT_IDXW-1:0] == ppht_w_idx) begin
          // Index match!

          // Left shift pattern entry
//          nxt_ppht[ii][PPHT_W-1:1] = ppht_for_w[PPHT_W-2:0];
          nxt_ppht[ii][PPHT_W-1:1] = ppht[ppht_w_idx][PPHT_W-2:0];

          // Set pattern entry's LSB based on actual branch result
//          nxt_ppht[ii][0] = branch_dir_for_w;
          nxt_ppht[ii][0] = assumed_branch_dir_for_w;
        end else begin
          // Indeces do not match
          nxt_ppht[ii] = ppht[ii];
        end
      end else begin
        // No update required
        nxt_ppht[ii] = ppht[ii];
      end
    end
  end
  
  ////////////////
  // BHT Update //
  ////////////////
  //
  for (ii=0; ii<PBHT_D; ii=ii+1) begin : pbht_entry

    always @ (posedge clk_i or posedge reset_i) begin : seq
      if (reset_i) begin
        pbht[ii] <= 2'd0; // Strong not taken
      end else begin
        pbht[ii] <= nxt_pbht[ii];
      end
    end

    always @* begin : comb
      if (bht_w_i) begin
        // Update required
        if (ii[PPHT_W-1:0] == pbht_w_idx) begin
          // Index match!

          // Update 2BC entry
//          case ({correct_i, pbht_for_w[1:0]})
          case ({correct_i, pbht[pbht_w_idx][1:0]})
            3'b000: nxt_pbht[ii] = 2'b01;
            3'b001: nxt_pbht[ii] = 2'b10;
            3'b010: nxt_pbht[ii] = 2'b01;
            3'b011: nxt_pbht[ii] = 2'b10;
            3'b100: nxt_pbht[ii] = 2'b00;
            3'b101: nxt_pbht[ii] = 2'b00;
            3'b110: nxt_pbht[ii] = 2'b11;
            3'b111: nxt_pbht[ii] = 2'b11;
          endcase
        end else begin
          // Indeces do not match
          nxt_pbht[ii] = pbht[ii];
        end 
      end else begin
        // No update required
        nxt_pbht[ii] = pbht[ii];
      end
    end
  end

  //---------------------------------------------------------------------------
  // GShare
  //
  //////////////////////////
  // Generate Table Index //
  //////////////////////////
  //
  // BHT indexes
  assign gbht_r_idx = glbl_patt       ^ bht_r_pc_i[GH_W+1:2];
//  assign gbht_w_idx = glbl_patt_for_w ^ bht_w_pc_i[GH_W+1:2];
  assign gbht_w_idx = glbl_patt       ^ bht_w_pc_i[GH_W+1:2];

  /////////////
  // Predict //
  /////////////
  //
  assign g_res_r = gbht[gbht_r_idx][1];
  assign g_res_w = gbht[gbht_w_idx][1];

  ////////////////////////
  // Prediction Storage //
  ////////////////////////
  //
  // Store Gshare pattern and prediction result to prevent having to re-read
  // prediction result when updating
//  always @(posedge clk_i or posedge reset_i) begin : gshare_hold_seq
//    if (reset_i) begin
//      glbl_patt_for_w <= {GH_W{1'd0}};
//      gbht_for_w      <= 2'd0;
//    end else begin
//      glbl_patt_for_w <= nxt_glbl_patt_for_w;
//      gbht_for_w      <= nxt_gbht_for_w;
//    end
//  end

//  // Only update holding resgiters when prediction is made.
//  assign nxt_glbl_patt_for_w = (bht_r_i) ? glbl_patt        : glbl_patt_for_w;
//  assign nxt_gbht_for_w      = (bht_r_i) ? gbht[gbht_r_idx] : gbht_for_w;
  
  ///////////////////////////
  // Global History Update //
  ///////////////////////////
  //
  always @ (posedge clk_i or posedge reset_i) begin : gh_seq
    if (reset_i) begin
      glbl_patt <= {GH_W{1'd0}};
    end else begin
      glbl_patt <= nxt_glbl_patt;
    end
  end

  always @* begin : gh_comb
    if (bht_w_i) begin
      // Update required

      // Left shift global pattern
//      nxt_glbl_patt[GH_W-1:1] = glbl_patt_for_w[GH_W-2:0];
      nxt_glbl_patt[GH_W-1:1] = glbl_patt[GH_W-2:0];

      // Set pattern LSB based on actual branch result
//      nxt_glbl_patt[0] = branch_dir_for_w;
      nxt_glbl_patt[0] = assumed_branch_dir_for_w;

    end else begin
      // No update required
      nxt_glbl_patt = glbl_patt;
    end
  end

  ////////////////
  // BHT Update //
  ////////////////
  //
  for (ii=0; ii<GBHT_D; ii=ii+1) begin : gbht_entry

    always @ (posedge clk_i or posedge reset_i) begin : seq
      if (reset_i) begin
        gbht[ii] <= 2'd0; // Strong not taken
      end else begin
        gbht[ii] <= nxt_gbht[ii];
      end
    end

    always @* begin : comb
      if (bht_w_i) begin
        // Update required
        if (ii[GH_W-1:0] == gbht_w_idx) begin
          // Index match!

          // Update 2BC entry
//          case ({correct_i, gbht_for_w})
          case ({correct_i, gbht[gbht_w_idx]})
            3'b000: nxt_gbht[ii] = 2'b01;
            3'b001: nxt_gbht[ii] = 2'b10;
            3'b010: nxt_gbht[ii] = 2'b01;
            3'b011: nxt_gbht[ii] = 2'b10;
            3'b100: nxt_gbht[ii] = 2'b00;
            3'b101: nxt_gbht[ii] = 2'b00;
            3'b110: nxt_gbht[ii] = 2'b11;
            3'b111: nxt_gbht[ii] = 2'b11;
          endcase
        end else begin
          // Indeces do not match
          nxt_gbht[ii] = gbht[ii];
        end 
      end else begin
        // No update required
        nxt_gbht[ii] = gbht[ii];
      end
    end
  end
  
  //---------------------------------------------------------------------------
  // Meta Predictor
  //
  ////////////////////////////
  // Generate Table Indexes //
  ////////////////////////////
  //
  assign m2bc_r_idx = bht_r_pc_i[META_IDXW+1:2];
  assign m2bc_w_idx = bht_w_pc_i[META_IDXW+1:2];

  /////////////
  // Predict //
  /////////////
  //
  assign m_res_r = m2bc[m2bc_r_idx][1];
  assign m_res_w = m2bc[m2bc_w_idx][1];

  ////////////////////////
  // Prediction Storage //
  ////////////////////////
  //
  // Store Pshare pattern and prediction result to prevent having to re-read
  // prediction result when updating
//  always @(posedge clk_i or posedge reset_i) begin : meta_hold_seq
//    if (reset_i) begin
//      m2bc_for_w <= 2'b00;
//    end else begin
//      m2bc_for_w <= nxt_m2bc_for_w;
//    end
//  end

//  // Only update holding resgiters when prediction is made.
//  assign nxt_m2bc_for_w = (bht_r_i) ? m2bc[m2bc_r_idx] : m2bc_for_w;
  
  /////////////////////////////
  // Prediction Select Table //
  /////////////////////////////
  //
  for (ii=0; ii<META_D; ii=ii+1) begin : meta_entry

    always @ (posedge clk_i or posedge reset_i) begin : meta_seq
      if (reset_i) begin
        m2bc[ii] <= 2'd0; // Strong not taken
      end else begin
        m2bc[ii] <= nxt_m2bc[ii];
      end
    end

    always @* begin : comb
      if (bht_w_i) begin
        // Update required
        if (ii[META_IDXW-1:0] == m2bc_w_idx) begin
          // Index match!
//          if (pbht_for_w[1] ^ gbht_for_w[1]) begin
          if (p_res_w ^ g_res_w) begin
            // PShare and GShare predictions differed
//            case ({correct_i, m2bc_for_w})
            case ({correct_i, m2bc[m2bc_w_idx]})
              3'b000 : nxt_m2bc[ii] = 2'b01;
              3'b001 : nxt_m2bc[ii] = 2'b10;
              3'b010 : nxt_m2bc[ii] = 2'b01;
              3'b011 : nxt_m2bc[ii] = 2'b10;
              3'b100 : nxt_m2bc[ii] = 2'b00;
              3'b101 : nxt_m2bc[ii] = 2'b00;
              3'b110 : nxt_m2bc[ii] = 2'b11;
              3'b111 : nxt_m2bc[ii] = 2'b11;
            endcase
          end else begin
            // PShare and GShare predictions matched
            nxt_m2bc[ii] = m2bc[ii];
          end
        end else begin
          // Indeces do not match
          nxt_m2bc[ii] = m2bc[ii];
        end
      end else begin
        // No update required
        nxt_m2bc[ii] = m2bc[ii];
      end
    end
  end

  //---------------------------------------------------------------------------
  // Hierarchical Prediction
  //
  assign predict_o = p_res_r;
//  assign predict_o                = m_res_r   ? g_res_r               : p_res_r;

//  assign assumed_predict_for_w    = m_res_w   ? g_res_w               : p_res_w;
  assign assumed_predict_for_w    = p_res_w;

  assign assumed_branch_dir_for_w = correct_i ? assumed_predict_for_w : ~assumed_predict_for_w;

  ////////////////////////
  // Prediction Storage //
  ////////////////////////
  //
  // Store Meta prediction result to prevent having to re-read
  // prediction result when updating
//  always @(posedge clk_i or posedge reset_i) begin : predict_hold_seq
//    if (reset_i) begin
//      predict_for_w <= 1'b0;      
//    end else begin
//      predict_for_w <= nxt_predict_for_w;
//    end
//  end

//  assign nxt_predict_for_w = (bht_r_i) ? predict_o : predict_for_w;
//  assign branch_dir_for_w = correct_i ? predict_for_w : ~predict_for_w;

  //---------------------------------------------------------------------------
  // Unused
  //
  wire unused_ok = |{
                     // Not all bits of PCs are used. Rather than determine
                     // which bits are unused just read the whole signal here.
                     bht_r_pc_i,
                     bht_w_pc_i,

                     1'b1};
endmodule
