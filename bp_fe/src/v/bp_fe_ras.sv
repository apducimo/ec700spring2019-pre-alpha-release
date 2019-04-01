// ============================================================================
//
// Original Author: Anthony Ducimo
// Filename       : bp_fe_ras.v
// Description    : Black Parrot RAS
// 
// ============================================================================

module bp_fe_ras (
  // --------------------------------------------------------------------------
  // Module Port Arguments
  //
  reset_i, // (I) Reset, active high

  clk_i,   // (I) Clock

  instr_i, // (I) Opcode

  pc_i,    // (O) Opcode PC

  pc_o,    // (O) PC prediction

  pc_v_o   // (O) PC prediction valid
);

  // ---------------------------------------------------------------------------
  // Parameters / Localparams
  //
  parameter eaddr_width_p  = 32'd32;

  localparam [eaddr_width_p-1:0] pc_incr_lp = {{(eaddr_width_p-1){1'd0}}, 1'd1} << 32'd2;

  parameter instr_width_p  = 32'd32;

  parameter ras_idx_width_p = 32'd4;

  localparam ras_depth_lp = 32'd2**ras_idx_width_p;

  // ---------------------------------------------------------------------------
  // Module Port Declarations
  //
  input                           reset_i;

  input                           clk_i;

  input       [instr_width_p-1:0] instr_i;

  input       [eaddr_width_p-1:0] pc_i;

  output wire [eaddr_width_p-1:0] pc_o;

  output wire                     pc_v_o;

  //---------------------------------------------------------------------------
  // Internal Signals
  //
  reg                   [ras_idx_width_p-1:0] ras_wr_ptr;
  reg                   [ras_idx_width_p-1:0] nxt_ras_wr_ptr;

  reg                   [ras_idx_width_p-1:0] ras_top_ptr;
  reg                   [ras_idx_width_p-1:0] nxt_ras_top_ptr;

  reg [ras_depth_lp-1:0]                      ras_valid;
  reg [ras_depth_lp-1:0]                      nxt_ras_valid;

  reg [ras_depth_lp-1:0]  [eaddr_width_p-1:0] ras_pc;
  reg [ras_depth_lp-1:0]  [eaddr_width_p-1:0] nxt_ras_pc;

  wire push;

  wire pop;

  genvar ii;

  //---------------------------------------------------------------------------
  // Push Detection
  //
  // Detect CALL RET to push entries onto RAS
  assign push =   (instr_i[ 6: 0] ==  7'h73)
                & (instr_i[31: 7] == 25'd0);

  //---------------------------------------------------------------------------
  // Pop Detection
  //
  // Detect RET to pop entries off of RAS.
  // RET is a pseudo-instruction: JALR x0, 0, ra
  assign pop =    (instr_i[ 6: 0] ==  7'h67)  // opcode    == JALR
                & (instr_i[11: 7] ==  5'd0)   // rd        == x0 (zero)
                & (instr_i[31:20] == 12'd0)   // imm[11:0] == 12'd0
                & (instr_i[19:15] ==  5'd1);  // rs1       == x1 (ra)

  //---------------------------------------------------------------------------
  // Pointer Management
  //
  always @(posedge clk_i or posedge reset_i) begin : ras_ptr_seq
    if (reset_i) begin
      ras_wr_ptr  <= {ras_idx_width_p{1'd0}};
      ras_top_ptr <= {ras_idx_width_p{1'd1}};
    end else begin
      ras_wr_ptr  <= nxt_ras_wr_ptr;
      ras_top_ptr <= nxt_ras_top_ptr;
    end
  end

  always @* begin : ras_ptr_comb
    if (push) begin
      nxt_ras_wr_ptr  = ras_wr_ptr  - {ras_idx_width_p{1'd1}}; // += 1
      nxt_ras_top_ptr = ras_top_ptr - {ras_idx_width_p{1'd1}}; // += 1
    end else begin
      if (pop) begin
        nxt_ras_wr_ptr  = ras_wr_ptr  + {ras_idx_width_p{1'd1}}; // -= 1
        nxt_ras_top_ptr = ras_top_ptr + {ras_idx_width_p{1'd1}}; // -= 1
      end else begin
        nxt_ras_wr_ptr  = ras_wr_ptr;
        nxt_ras_top_ptr = ras_top_ptr;
      end
    end
  end

  //---------------------------------------------------------------------------
  // Stack
  //
  for (ii=0; ii<ras_depth_lp; ii=ii+1) begin : ras_entry
    always @(posedge clk_i or posedge reset_i) begin : seq
      if (reset_i) begin
        ras_pc[ii]    <= {eaddr_width_p{1'd0}};
        ras_valid[ii] <= 1'd1;
      end else begin
        ras_pc[ii]    <= nxt_ras_pc[ii];
        ras_valid[ii] <= nxt_ras_valid[ii];
      end
    end

    always @* begin : cmb
      if (push && (ras_wr_ptr == ii[ras_idx_width_p-1:0])) begin
        nxt_ras_pc[ii]    = pc_i + pc_incr_lp;
        nxt_ras_valid[ii] = 1'd1;
      end else begin
        if (pop && (ras_top_ptr == ii[ras_idx_width_p-1:0])) begin
          nxt_ras_pc[ii]    = ras_pc[ii];
          nxt_ras_valid[ii] = 1'd0;
        end else begin
          nxt_ras_pc[ii]    = ras_pc[ii];
          nxt_ras_valid[ii] = ras_valid[ii];
        end
      end
    end
  end

  //---------------------------------------------------------------------------
  // Prediction
  //
  // Validation
  assign pc_v_o = pop & ras_valid[ras_top_ptr];

  // PC Prediction
  assign pc_o = ras_pc[ras_top_ptr];

endmodule
