// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : bp_tournament_bht_tb.v
// Description    : Unit testbench for bp_tournament_bht
// 
// ============================================================================

module bp_tournament_bht_tb ();

  // ---------------------------------------------------------------------------
  // Parameters / Localparams
  // Including parameters here of possile override at command line
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
  parameter PPHT_IDXW = 32'd4;

  // PHT depth
  localparam PPHT_D = 32'd2**PPHT_IDXW;

  // PHT width
  parameter PPHT_W = 32'd4;

  // BHT depth
  localparam PBHT_D = 32'd2**PPHT_W;
  
  ////////////
  // GShare //
  ////////////
  //
  // Global pattern regsiter width
  parameter GH_W = 32'd4;
  
  // BHT depth
  localparam GBHT_D = 32'd2**GH_W;
  
  ////////////////////
  // Meta Predictor //
  ////////////////////
  //
  // Counter table index width
  parameter META_IDXW = 32'd4;
  
  // Counter table depth
  localparam META_D = 32'd2**META_IDXW;

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
  ///////////////////////
  // Clocks and Resets //
  ///////////////////////
  //
  reg reset_i;

  reg clk_i;

  /////////////////////////////////
  // Branch History Table Access //
  /////////////////////////////////
  //
  reg            bht_r_i;
  reg [PC_W-1:0] bht_r_pc_i;
  reg [PC_W-1:0] bht_r_pc_i_d1;

  reg            bht_w_i;
  reg [PC_W-1:0] bht_w_pc_i;
    
  /////////////////////////////
  // Branch Outcome/Feedback //
  /////////////////////////////
  //
  wire predict_o;
  reg  predict_o_d1;
  reg  predict_at_w;
  

  reg  correct_i;
  wire branch_dir_i;

  ///////////////////////////////
  // Shadow Registers / Tables //
  ///////////////////////////////
  //
  reg   [GH_W-1:0] shadow_glbl_patt;
  reg   [GH_W-1:0] shadow_gpatt_w;

  reg   [GH_W-1:0] rand_glbl_patt;

  reg [PPHT_W-1:0] shadow_ppht        [PPHT_D-1:0];
  reg [PPHT_W-1:0] shadow_ppht_w;

  reg [PPHT_W-1:0] rand_ppht          [PPHT_D-1:0];

  reg        [1:0] shadow_pbht        [PBHT_D-1:0];
  reg [PPHT_W-1:0] shadow_pbht_w_idx;

  reg        [1:0] rand_pbht          [PBHT_D-1:0];

  reg        [1:0] shadow_gbht        [GBHT_D-1:0];
  reg   [GH_W-1:0] shadow_gbht_w_idx;

  reg        [1:0] rand_gbht          [GBHT_D-1:0];

  reg        [1:0] shadow_meta        [META_D-1:0];

  reg        [1:0] rand_meta          [META_D-1:0];

  reg        [1:0] shadow_p_res_w;
  reg        [1:0] shadow_g_res_w;
  reg        [1:0] shadow_m_res_w;

  ///////////
  // Misc. //
  ///////////
  //
  genvar ii;

  // ---------------------------------------------------------------------------
  // DUT Instance
  //
  bp_tournament_bht #(
    .PC_W      (PC_W),      // Width of PC
    .PPHT_IDXW (PPHT_IDXW), // Pshare PHT index width
    .PPHT_W    (PPHT_W),    // Pshare PHT width
    .GH_W      (GH_W),      // Global pattern regsiter width
    .META_IDXW (META_IDXW)  // Meta Predictor Counter table index width
  ) DUT (
    // Clocks and Resets
    .reset_i      (reset_i), // (I) Reset, active high

    .clk_i        (clk_i),   // (I) Clock

    // Branch History Table Access
    .bht_r_i      (bht_r_i),    // (I) Read enable
    .bht_r_pc_i   (bht_r_pc_i), // (I) Read address

    .bht_w_i      (bht_w_i),    // (I) Write enable
    .bht_w_pc_i   (bht_w_pc_i), // (I) Write Address
    
    // Branch Outcome/Feedback 
    .predict_o    (predict_o), // (O) Prediction outcome

    .correct_i    (correct_i)  // (I) Prediction feedback

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
  // Branch Predition Control / Status
  //
  integer seed = SEED;
  
  /////////////////////////
  // PCs / Table Indexes //
  /////////////////////////
  //
  initial begin : init_pcs
    // Zero out all PCs at the start
    bht_r_pc_i    <= {PC_W{1'b0}};
    bht_r_pc_i_d1 <= {PC_W{1'b0}};
    bht_w_pc_i    <= {PC_W{1'b0}};
  end
  
  always @(posedge clk_i) begin : drive_pcs
    // Randomly assign PC for prediction
    bht_r_pc_i <= $random(seed);

    // Delay PC used for predcition by two cycles and use it as the PC for
    // updating prediction tables
    bht_r_pc_i_d1 <= bht_r_pc_i;
    bht_w_pc_i    <= bht_r_pc_i_d1;
  end
    
  //////////////////
  // Write Enable //
  //////////////////
  //
  // Assert write enable with de-assertion of reset and then every other clock cycle
  initial begin : drive_wr_enable
        bht_w_i <= 1'b0;
    #40 bht_w_i <= 1'b1;

    forever begin
      #10 bht_w_i <= ~bht_w_i;
    end
  end

  /////////////////
  // Read Enable //
  /////////////////
  //
  // Start read enable 2 clock cycles before write enable but stay synchronized
  // with it
  initial begin : drive_r_renable
        bht_r_i <= 1'b0;
    #20 bht_r_i <= 1'b1;
    
    forever begin
      #10 bht_r_i <= ~bht_r_i;
    end
  end

  ///////////////////////////
  // Prediction Monitoring //
  ///////////////////////////
  //
  initial begin : init_predict_pipe
    predict_o_d1 <= 1'b0;
    predict_at_w <= 1'b0;
  end

  always @(posedge clk_i) begin : pipe_prediction
    predict_o_d1 <= predict_o;
    predict_at_w <= predict_o_d1;
  end
  
  /////////////////////////
  // Prediction Feedback //
  /////////////////////////
  //
  // Assert write enable with de-assertion of reset and then every other clock cycle
  initial begin : drive_correct
        correct_i <= 1'b0;
    #40 correct_i <= $random(seed);

    forever begin
      #20 correct_i <= $random(seed);
    end
  end
  
  assign branch_dir_i = correct_i ? predict_at_w : ~predict_at_w;

  // ---------------------------------------------------------------------------
  // Randomized Warmup
  //  
  generate
    if (WARMUP) begin : warmup
      initial begin : glbl
        #21; // Await de-assertion of reset
        rand_glbl_patt <= $random(seed);
        #1;
        shadow_glbl_patt <= rand_glbl_patt;
        DUT.glbl_patt    <= rand_glbl_patt;
        #1;
      end
      for (ii=0; ii<PPHT_D; ii=ii+1) begin : ppht
        initial begin : entry
          #21; // Await de-assertion of reset
          rand_ppht[ii] <= $random(seed);
          #1;
          shadow_ppht[ii] <= rand_ppht[ii];
          DUT.ppht[ii]    <= rand_ppht[ii];
          #1;
        end
      end
  
      for (ii=0; ii<PBHT_D; ii=ii+1) begin : pbht
        initial begin : entry
          #21; // Await de-assertion of reset
          rand_pbht[ii] <= $random(seed);
          #1;
          shadow_pbht[ii] <= rand_pbht[ii];
          DUT.pbht[ii]    <= rand_pbht[ii];
          #1;
        end
      end

      for (ii=0; ii<GBHT_D; ii=ii+1) begin : gbht
        initial begin : entry
          #21; // Await de-assertion of reset
          rand_gbht[ii] <= $random(seed);
          #1;
          shadow_gbht[ii] <= rand_gbht[ii];
          DUT.gbht[ii]    <= rand_gbht[ii];
          #1;
        end
     end

      for (ii=0; ii<META_D; ii=ii+1) begin : meta
        initial begin : entry
          #21; // Await de-assertion of reset
          rand_meta[ii] <= $random(seed);
          #1;
          shadow_meta[ii] <= rand_meta[ii];
          DUT.m2bc[ii]    <= rand_meta[ii];
          #1;
        end
      end        
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // Shadow Registers
  //
  always @(posedge clk_i or posedge reset_i) begin : glbl_patt_shadow
    if (reset_i) begin
      shadow_glbl_patt       <= {GH_W{1'd0}};
    end else begin
      if (bht_w_i) begin
        shadow_glbl_patt[GH_W-1:1] <= shadow_gpatt_w[GH_W-2:0];
        if (correct_i) begin
          shadow_glbl_patt[0] <= predict_at_w;
        end else begin
          shadow_glbl_patt[0] <= ~predict_at_w;
        end
      end
    end
  end

  for (ii=0; ii<PPHT_D; ii=ii+1) begin : ppht_entry
    always @(posedge clk_i or posedge reset_i) begin : shadow
      if (reset_i) begin
        shadow_ppht[ii] <= {PPHT_W{1'd0}};
      end else begin
        if (bht_w_i) begin
          if (ii[PPHT_IDXW-1:0] == bht_w_pc_i[PPHT_IDXW+1:2]) begin
            shadow_ppht[ii][PPHT_IDXW-1:1] <= shadow_ppht_w[PPHT_IDXW-2:0];
            if (correct_i) begin
              shadow_ppht[ii][0] <= predict_at_w;
            end else begin
              shadow_ppht[ii][0] <= ~predict_at_w;
            end
          end
        end
      end
    end
  end

  always @(posedge clk_i or negedge reset_i) begin
    if (reset_i) begin
      shadow_pbht_w_idx <= {PPHT_IDXW{1'd0}};
      shadow_gbht_w_idx <= {GH_W{1'd0}};
      shadow_ppht_w     <= {PPHT_IDXW{1'd0}};
      shadow_gpatt_w    <= {PPHT_IDXW{1'd0}};
      shadow_p_res_w    <= 2'b0;
      shadow_g_res_w    <= 2'b0;   
      shadow_m_res_w    <= 2'b0;   
    end else begin
      if (bht_r_i) begin
        shadow_pbht_w_idx <= shadow_ppht[bht_r_pc_i[PPHT_IDXW+1:2]] ^ bht_r_pc_i[PPHT_IDXW+1:2];
        shadow_gbht_w_idx <= shadow_glbl_patt ^ bht_r_pc_i[GH_W+1:2];
        shadow_p_res_w <= shadow_pbht[shadow_ppht[bht_r_pc_i[PPHT_IDXW+1:2]] ^ bht_r_pc_i[PPHT_IDXW+1:2]];
        shadow_ppht_w     <= shadow_ppht[bht_r_pc_i[PPHT_IDXW+1:2]];
        shadow_gpatt_w    <= shadow_glbl_patt;
        shadow_g_res_w <= shadow_gbht[shadow_glbl_patt ^ bht_r_pc_i[GH_W+1:2]];
        shadow_m_res_w <= shadow_meta[bht_r_pc_i[META_IDXW+1:2]];
      end
    end
  end

  for (ii=0; ii<PBHT_D; ii=ii+1) begin : pbht_entry
    always @(posedge clk_i or posedge reset_i) begin : shadow
      if (reset_i) begin
        shadow_pbht[ii] <= 2'd0;
      end else begin
        if (bht_w_i) begin
          if (ii[PPHT_W-1:0] == shadow_pbht_w_idx) begin
            case ({correct_i, shadow_p_res_w})
              3'b000 : shadow_pbht[ii] <= 2'b01;
              3'b001 : shadow_pbht[ii] <= 2'b10;
              3'b010 : shadow_pbht[ii] <= 2'b01;
              3'b011 : shadow_pbht[ii] <= 2'b10;
              3'b100 : shadow_pbht[ii] <= 2'b00;
              3'b101 : shadow_pbht[ii] <= 2'b00;
              3'b110 : shadow_pbht[ii] <= 2'b11;
              3'b111 : shadow_pbht[ii] <= 2'b11;
            endcase
          end
        end
      end
    end
  end

  for (ii=0; ii<GBHT_D; ii=ii+1) begin : gbht_entry
    always @(posedge clk_i or posedge reset_i) begin : shadow
      if (reset_i) begin
        shadow_gbht[ii] <= 2'd0;
      end else begin
        if (bht_w_i) begin
          if (ii[GH_W-1:0] == shadow_gbht_w_idx) begin
            case ({correct_i, shadow_g_res_w})
              3'b000 : shadow_gbht[ii] <= 2'b01;
              3'b001 : shadow_gbht[ii] <= 2'b10;
              3'b010 : shadow_gbht[ii] <= 2'b01;
              3'b011 : shadow_gbht[ii] <= 2'b10;
              3'b100 : shadow_gbht[ii] <= 2'b00;
              3'b101 : shadow_gbht[ii] <= 2'b00;
              3'b110 : shadow_gbht[ii] <= 2'b11;
              3'b111 : shadow_gbht[ii] <= 2'b11;
            endcase
          end
        end
      end
    end
  end

  for (ii=0; ii<META_D; ii=ii+1) begin : meta_entry
    always @(posedge clk_i or posedge reset_i) begin : shadow
      if (reset_i) begin
        shadow_meta[ii] <= 2'd0;
      end else begin
        if (bht_w_i) begin
          if (ii[META_IDXW-1:0] == bht_w_pc_i[META_IDXW+1:2]) begin
            if(shadow_p_res_w[1] ^ shadow_g_res_w[1]) begin
              case({correct_i, shadow_m_res_w})
                3'b000 : shadow_meta[ii] <= 2'b01;
                3'b001 : shadow_meta[ii] <= 2'b10;
                3'b010 : shadow_meta[ii] <= 2'b01;
                3'b011 : shadow_meta[ii] <= 2'b10;
                3'b100 : shadow_meta[ii] <= 2'b00;
                3'b101 : shadow_meta[ii] <= 2'b00;
                3'b110 : shadow_meta[ii] <= 2'b11;
                3'b111 : shadow_meta[ii] <= 2'b11;
              endcase
            end
          end
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Self-Checking
  //
  initial begin : glbl_patt_check
    #31;
    forever begin
      #20;
      if (shadow_glbl_patt != DUT.glbl_patt) begin
        $display("ERROR at %0t: Global Pattern Register Miscompare", $time);
        $display("Expected: %0h, Actual: %0h", shadow_glbl_patt, DUT.glbl_patt);
        $finish;
      end
    end
  end

  for (ii=0; ii<PPHT_D; ii=ii+1) begin : check_ppht_entry
    initial begin
      #31;
      forever begin
        #20;
        if (shadow_ppht[ii] != DUT.ppht[ii]) begin
          $display("ERROR at %0t: PShare PHT entry %0d miscompare", $time, ii);
          $display("Expected: %0h, Actual: %0h", shadow_ppht[ii], DUT.ppht[ii]);
          $finish;
        end
      end
    end
  end

  for (ii=0; ii<PBHT_D; ii=ii+1) begin : check_pbht_entry
    initial begin
      #31;
      forever begin
        #20;
        if (shadow_pbht[ii] != DUT.pbht[ii]) begin
          $display("ERROR at %0t: PShare BHT entry %0d miscompare", $time, ii);
          $display("Expected: %0h, Actual: %0h", shadow_pbht[ii], DUT.pbht[ii]);
          $finish;
        end
      end
    end
  end

  for (ii=0; ii<GBHT_D; ii=ii+1) begin : check_gbht_entry
    initial begin
      #31;
      forever begin
        #20;
        if (shadow_gbht[ii] != DUT.gbht[ii]) begin
          $display("ERROR at %0t: GShare BHT entry %0d miscompare", $time, ii);
          $display("Expected: %0h, Actual: %0h", shadow_gbht[ii], DUT.gbht[ii]);
          $finish;
        end
      end
    end
  end

  for (ii=0; ii<META_D; ii=ii+1) begin : check_meta_entry
    initial begin
      #31;
      forever begin
        #20;
        if (shadow_meta[ii] != DUT.m2bc[ii]) begin
          $display("ERROR at %0t: Meta 2BC entry %0d miscompare", $time, ii);
          $display("Expected: %0h, Actual: %0h", shadow_meta[ii], DUT.m2bc[ii]);
          $finish;
        end
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Simulation Control
  //
  initial begin
    #(TIMEOUT);
    $display("Simulation Finished Without Error");
    $finish;
  end

endmodule
