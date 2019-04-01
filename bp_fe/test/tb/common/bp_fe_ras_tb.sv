// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : bp_fe_ras_tb.sv
// Description    : Unit testbench for RAS
// 
// ============================================================================

module bp_fe_ras_tb ();
  // ---------------------------------------------------------------------------
  // Parameters / Localparams
  // Including parameters here of possile override at command line
  //
  /////////
  // RAS //
  /////////
  //
  parameter eaddr_width_p  = 32'd32;

  parameter instr_width_p  = 32'd32;

  parameter ras_idx_width_p = 32'd2;

  ////////////////////////
  // Simulation Control //
  ////////////////////////
  //
  parameter TIMEOUT = 32'd1000000;
  parameter SEED    = 32'd1;

  //---------------------------------------------------------------------------
  // Internal Signals
  //
  /////////
  // RAS //
  /////////
  //
  reg                      reset_i;

  reg                      clk_i;

  reg  [instr_width_p-1:0] instr_i;

  reg  [eaddr_width_p-1:0] pc_i;

  wire [eaddr_width_p-1:0] pc_o;

  wire                     pc_v_o;

  ///////////////////////////
  // Test Stimulus Control //
  ///////////////////////////
  //
  integer seed = SEED;

  string test_phase = "";

  // ---------------------------------------------------------------------------
  // DUT Instance
  //
  bp_fe_ras #(
    .eaddr_width_p   (eaddr_width_p),
    .instr_width_p   (instr_width_p),
    .ras_idx_width_p (ras_idx_width_p)
  ) DUT (
    .reset_i (reset_i), // (I) Reset, active high

    .clk_i   (clk_i),   // (I) Clock

    .instr_i (instr_i), // (I) Opcode

    .pc_i    (pc_i),    // (O) Opcode PC

    .pc_o    (pc_o),    // (O) PC prediction

    .pc_v_o  (pc_v_o)   // (O) PC prediction valid
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
  // RAS Control / Status
  //

  // ---------------------------------------------------------------------------
  // Test Stimulus
  //
  initial begin
    test_phase = "Reset Phase";

    instr_i <= {instr_width_p{1'd0}};

    #21; // 1ns after reset

    // ---------------------------------------------------------------------------
    // Scenario 0:
    // Fill RAS
    //
    test_phase = "Fill RAS";

    repeat (4) begin
      pc_i <= $random(seed);

      instr_i[31:20] <= 'd0;
      instr_i[19:15] <= 'd0;
      instr_i[14:12] <= 'd0;
      instr_i[11:7]  <= 'd0;
      instr_i[6:0]   <= 7'b1110011;
      #10;
    end

    // ---------------------------------------------------------------------------
    // Scenario 1:
    // Empty RAS
    //
    test_phase = "Empty RAS";

    repeat (4) begin
      pc_i <= $random(seed);

      instr_i[31:20] <= 'd0;
      instr_i[19:15] <= 'd1;
      instr_i[14:12] <= 'd0;
      instr_i[11:7]  <= 'd0;
      instr_i[6:0]   <= 7'b1100111;
      #10;
    end

    // ---------------------------------------------------------------------------
    // Inactive
    //
    test_phase = "Inactive";
    instr_i <= {instr_width_p{1'd0}};
    pc_i    <= 'd0;
    
    #10;

    // ---------------------------------------------------------------------------
    // Scenario 2:
    // 3/4 Fill RAS
    //
    test_phase = "3/4 Fill RAS";

    repeat (3) begin
      pc_i <= $random(seed);

      instr_i[31:20] <= 'd0;
      instr_i[19:15] <= 'd0;
      instr_i[14:12] <= 'd0;
      instr_i[11:7]  <= 'd0;
      instr_i[6:0]   <= 7'b1110011;
      #10;
    end

    // ---------------------------------------------------------------------------
    // Scenario 3:
    // Empty RAS and keep issuing RETs
    //
    test_phase = "Starvation";

    repeat (5) begin
      pc_i <= $random(seed);

      instr_i[31:20] <= 'd0;
      instr_i[19:15] <= 'd1;
      instr_i[14:12] <= 'd0;
      instr_i[11:7]  <= 'd0;
      instr_i[6:0]   <= 7'b1100111;
      #10;
    end

    // ---------------------------------------------------------------------------
    // Inactive
    //
    test_phase = "Inactive";
    instr_i <= {instr_width_p{1'd0}};
    pc_i    <= 'd0;
    
    #10;

    // ---------------------------------------------------------------------------
    // Scenario 4:
    // Overfill RAS
    //
    test_phase = "RAS Overflow";

    repeat (6) begin
      pc_i <= $random(seed);

      instr_i[31:20] <= 'd0;
      instr_i[19:15] <= 'd0;
      instr_i[14:12] <= 'd0;
      instr_i[11:7]  <= 'd0;
      instr_i[6:0]   <= 7'b1110011;
      #10;
    end

    // ---------------------------------------------------------------------------
    // Scenario 5:
    // Empty RAS and keep issuing RETs
    //
    test_phase = "Starvation";

    repeat (5) begin
      pc_i <= $random(seed);

      instr_i[31:20] <= 'd0;
      instr_i[19:15] <= 'd1;
      instr_i[14:12] <= 'd0;
      instr_i[11:7]  <= 'd0;
      instr_i[6:0]   <= 7'b1100111;
      #10;
    end

    // ---------------------------------------------------------------------------
    // Inactive
    //
    test_phase = "Inactive";
    instr_i <= {instr_width_p{1'd0}};
    pc_i    <= 'd0;
    
    #10;

    $display("Simulation Finished after providing stimulus");
    $finish();
  end
endmodule
