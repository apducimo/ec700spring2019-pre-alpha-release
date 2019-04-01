/**
 *
 * test_bp.v
 *
 */

module test_bp
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
   , parameter btb_indx_width_p            = "inv"
   , parameter bht_indx_width_p            = "inv"
   , parameter ras_addr_width_p            = "inv"
   , parameter core_els_p                  = "inv"
   , parameter num_cce_p                   = "inv"
   , parameter num_lce_p                   = "inv"
   , parameter lce_sets_p                  = "inv"
   , parameter lce_assoc_p                 = "inv"
   , parameter cce_block_size_in_bytes_p   = "inv"
   , parameter cce_num_inst_ram_els_p      = "inv"
   , parameter mem_els_p                   = "inv"

   , parameter boot_rom_width_p            = "inv"
   , parameter boot_rom_els_p              = "inv"
   
   // Trace replay parameters
   , parameter trace_ring_width_p          = "inv"
   , parameter trace_rom_addr_width_p      = "inv"
   ,parameter TIMEOUT = 32'd1000000
 );

logic clk, reset;

bsg_nonsynth_clock_gen 
 #(.cycle_time_p(10))
 clock_gen 
  (.o(clk));

bsg_nonsynth_reset_gen 
 #(.num_clocks_p(1)
   ,.reset_cycles_lo_p(1)
   ,.reset_cycles_hi_p(10)
   )
 reset_gen
  (.clk_i(clk)
   ,.async_reset_o(reset)
   );

testbench
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   ,.btb_indx_width_p(btb_indx_width_p)
   ,.bht_indx_width_p(bht_indx_width_p)
   ,.ras_addr_width_p(ras_addr_width_p)
   ,.core_els_p(core_els_p)
   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ,.lce_sets_p(lce_sets_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
   ,.cce_num_inst_ram_els_p(cce_num_inst_ram_els_p)
   ,.mem_els_p(mem_els_p)

   ,.boot_rom_width_p(boot_rom_width_p)
   ,.boot_rom_els_p(boot_rom_els_p)
   )
 tb
  (.clk_i(clk)
   ,.reset_i(reset)
   );

  // ---------------------------------------------------------------------------
  // Simulation Control
  //  
  reg [31:0] clk_cnt = 0;
  reg [31:0] lce_req_cnt;
  reg [31:0] cce_req_cnt;
  reg [31:0] sb_miss_cnt;
  reg [31:0] bp_correct;
  reg [31:0] bp_incorrect;

  initial begin
    #(TIMEOUT);
    $display("Simulation Timeout!!!");
        $display("Clock cycles count: %0d", test_bp.clk_cnt);
        $display("Correct predictions: %0d", test_bp.bp_correct);
        $display("Incorrect predictions: %0d", test_bp.bp_incorrect);
        $display("LCE request count: %0d", test_bp.lce_req_cnt);
        $display("CCE request count: %0d", test_bp.cce_req_cnt);
        $display("SB miss count: %0d", test_bp.sb_miss_cnt); 
    $finish;
  end

always @(posedge clk or posedge reset) begin : sb_cce_rq_vld_seq
  if (reset) begin
    lce_req_cnt  <= 'd0;
    cce_req_cnt  <= 'd0;
    sb_miss_cnt  <= 'd0;
    bp_correct   <= 'd0;
    bp_incorrect <= 'd0;
  end else begin
    if (tb.dut.rof1[0].fe.bp_fe_pc_gen_1.gen_bp.branch_prediction_1.w_v_i) begin
      if (tb.dut.rof1[0].fe.bp_fe_pc_gen_1.gen_bp.branch_prediction_1.attaboy_i) begin
        bp_correct <= bp_correct + 1;
      end else begin
        bp_incorrect <= bp_incorrect + 1;
      end
    end
    if (tb.dut.rof1[0].be.be_mmu.dcache.lce_req_v_o && tb.dut.rof1[0].be.be_mmu.dcache.lce_req_ready_i) begin
      lce_req_cnt <= lce_req_cnt + 1;
    end
    if (tb.dut.rof1[0].be.be_mmu.lce_req_v_o && tb.dut.rof1[0].be.be_mmu.lce_req_ready_i) begin
      cce_req_cnt <= cce_req_cnt + 1;
    end
/* -----\/----- EXCLUDED -----\/-----
    if (tb.dut.rof1[0].be.be_mmu.u_bp_be_stream_buffer.sb_miss) begin
      sb_miss_cnt <= sb_miss_cnt +1;
    end
 -----/\----- EXCLUDED -----/\----- */
  end
end

  always @(posedge clk) begin
    clk_cnt <= clk_cnt + 1;
  end
endmodule : test_bp

