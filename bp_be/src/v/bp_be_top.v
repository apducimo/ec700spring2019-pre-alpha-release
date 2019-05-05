/**
 *
 * Name:
 *   bp_be_top.v
 * 
 * Description:
 *
 * Parameters:
 *   vaddr_width_p               - FE-BE structure sizing parameter
 *   paddr_width_p               - ''
 *   asid_width_p                - ''
 *   branch_metadata_fwd_width_p - ''
 *
 *   num_cce_p                   - 
 *   num_lce_p                   - 
 *   lce_assoc_p                 - 
 *   lce_sets_p                  - 
 *   cce_block_size_in_bytes_p   - 
 * 
 * Inputs:
 *   clk_i                       -
 *   reset_i                     -
 *
 *   fe_queue_i                  -
 *   fe_queue_v_i                -
 *   fe_queue_rdy_o              -
 *
 *   cce_lce_cmd_i               -
 *   cce_lce_cmd_v_i             -
 *   cce_lce_cmd_rdy_o           -
 *
 *   cce_lce_data_cmd_i          -
 *   cce_lce_data_cmd_v_i        -
 *   cce_lce_data_cmd_rdy_o      -
 * 
 *   lce_lce_tr_resp_i           - 
 *   lce_lce_tr_resp_v_i         -
 *   lce_lce_tr_resp_rdy_o       -
 * 
 *   proc_cfg_i                  -
 *
 * Outputs:
 *   fe_cmd_o                    -
 *   fe_cmd_v_o                  -
 *   fe_cmd_rdy_i                -
 *
 *   fe_queue_clr_o              -
 *   fe_queue_dequeue_inc_o      -
 *   fe_queue_rollback_o         -
 *
 *   lce_cce_req_o               -
 *   lce_cce_req_v_o             -
 *   lce_cce_req_rdy_i           -
 *
 *   lce_cce_resp_o              -
 *   lce_cce_resp_v_o            -
 *   lce_cce_resp_rdy_i          -
 *
 *   lce_cce_data_resp_o         -
 *   lce_cce_data_resp_v_o       -
 *   lce_cce_data_resp_rdy_i     -
 *
 *   lce_lce_tr_resp_o           -
 *   lce_lce_tr_resp_v_o         -
 *   lce_lce_tr_resp_rdy_i       -
 *
 *   cmt_trace_stage_reg_o       -
 *   cmt_trace_result_o          -
 *   cmt_trace_exc_o             -
 *
 * Keywords:
 *   be, top
 * 
 * Notes:
 *
 */

module bp_be_top
 import bp_common_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_be_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"

   , parameter core_els_p                  = "inv"

   // MMU parameters
   , parameter num_cce_p                   = "inv"
   , parameter num_lce_p                   = "inv"
   , parameter lce_assoc_p                 = "inv"
   , parameter lce_sets_p                  = "inv"
   , parameter cce_block_size_in_bytes_p   = "inv"
 
   // Generated parameters
   , localparam cce_block_size_in_bits_lp  = cce_block_size_in_bytes_p * rv64_byte_width_gp
   , localparam fe_queue_width_lp          = `bp_fe_queue_width(vaddr_width_p
                                                                , branch_metadata_fwd_width_p)
   , localparam fe_cmd_width_lp            = `bp_fe_cmd_width(vaddr_width_p
                                                              , paddr_width_p
                                                              , asid_width_p
                                                              , branch_metadata_fwd_width_p
                                                              )
   , localparam lce_cce_req_width_lp       = `bp_lce_cce_req_width(num_cce_p
                                                            , num_lce_p
                                                            , paddr_width_p
                                                            , lce_assoc_p
                                                            )
   , localparam lce_cce_resp_width_lp      = `bp_lce_cce_resp_width(num_cce_p
                                                              , num_lce_p
                                                              , paddr_width_p
                                                              )
   , localparam lce_cce_data_resp_width_lp = `bp_lce_cce_data_resp_width(num_cce_p
                                                                        , num_lce_p
                                                                        , paddr_width_p
                                                                        , cce_block_size_in_bits_lp
                                                                        )
   , localparam cce_lce_cmd_width_lp       = `bp_cce_lce_cmd_width(num_cce_p
                                                                   , num_lce_p
                                                                   , paddr_width_p
                                                                   , lce_assoc_p
                                                                   )
   , localparam cce_lce_data_cmd_width_lp  = `bp_cce_lce_data_cmd_width(num_cce_p
                                                                       , num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bits_lp
                                                                       , lce_assoc_p
                                                                       )
   , localparam lce_lce_tr_resp_width_lp   = `bp_lce_lce_tr_resp_width(num_lce_p
                                                                       , paddr_width_p
                                                                       , cce_block_size_in_bits_lp
                                                                       , lce_assoc_p
                                                                       )                                                               
   , localparam proc_cfg_width_lp          = `bp_proc_cfg_width(core_els_p, num_lce_p)

   , localparam pipe_stage_reg_width_lp    = `bp_be_pipe_stage_reg_width(branch_metadata_fwd_width_p)
   , localparam calc_result_width_lp       = `bp_be_calc_result_width(branch_metadata_fwd_width_p)
   , localparam exception_width_lp         = `bp_be_exception_width
   )
  (input                                     clk_i
   , input                                   reset_i

   // FE queue interface
   , input [fe_queue_width_lp-1:0]           fe_queue_i
   , input                                   fe_queue_v_i
   , output                                  fe_queue_rdy_o

   , output                                  fe_queue_clr_o
   , output                                  fe_queue_dequeue_o
   , output                                  fe_queue_rollback_o
 
   // FE cmd interface
   , output [fe_cmd_width_lp-1:0]            fe_cmd_o
   , output                                  fe_cmd_v_o
   , input                                   fe_cmd_rdy_i

   // LCE-CCE interface
   , output [lce_cce_req_width_lp-1:0]       lce_cce_req_o
   , output                                  lce_cce_req_v_o
   , input                                   lce_cce_req_rdy_i

   , output [lce_cce_resp_width_lp-1:0]      lce_cce_resp_o
   , output                                  lce_cce_resp_v_o
   , input                                   lce_cce_resp_rdy_i                                 

   , output [lce_cce_data_resp_width_lp-1:0] lce_cce_data_resp_o
   , output                                  lce_cce_data_resp_v_o
   , input                                   lce_cce_data_resp_rdy_i

   , input [cce_lce_cmd_width_lp-1:0]        cce_lce_cmd_i
   , input                                   cce_lce_cmd_v_i
   , output                                  cce_lce_cmd_rdy_o

   , input [cce_lce_data_cmd_width_lp-1:0]   cce_lce_data_cmd_i
   , input                                   cce_lce_data_cmd_v_i
   , output                                  cce_lce_data_cmd_rdy_o

   , input [lce_lce_tr_resp_width_lp-1:0]    lce_lce_tr_resp_i
   , input                                   lce_lce_tr_resp_v_i
   , output                                  lce_lce_tr_resp_rdy_o

   , output [lce_lce_tr_resp_width_lp-1:0]   lce_lce_tr_resp_o
   , output                                  lce_lce_tr_resp_v_o
   , input                                   lce_lce_tr_resp_rdy_i

   // Processor configuration
   , input [proc_cfg_width_lp-1:0]           proc_cfg_i

   // Commit tracer
   , output [pipe_stage_reg_width_lp-1:0]    cmt_trace_stage_reg_o
   , output [calc_result_width_lp-1:0]       cmt_trace_result_o
   , output [exception_width_lp-1:0]         cmt_trace_exc_o


   , input [63:0] pc_src
   , input [63:0] pc_dst
   );

// Declare parameterized structures
`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_common_proc_cfg_s(core_els_p, num_lce_p)
`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

// Casting
bp_proc_cfg_s proc_cfg;

assign proc_cfg = proc_cfg_i;

// Top-level interface connections
bp_be_issue_pkt_s issue_pkt;
logic issue_pkt_v, issue_pkt_rdy;

bp_be_mmu_cmd_s mmu_cmd;
logic mmu_cmd_v, mmu_cmd_rdy;

bp_be_mmu_resp_s mmu_resp;
logic mmu_resp_v, mmu_resp_rdy;

bp_be_calc_status_s    calc_status;
bp_be_exception_s      cmt_trace_exc;
bp_be_pipe_stage_reg_s cmt_trace_stage_reg;
bp_be_calc_result_s    cmt_trace_result;

logic chk_dispatch_v, chk_psn_isd, chk_psn_ex, chk_roll, chk_instr_dequeue_v;

// Module instantiations
bp_be_checker_top 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)
   )
 be_checker
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.chk_dispatch_v_o(chk_dispatch_v)
   ,.chk_roll_o(chk_roll)
   ,.chk_poison_isd_o(chk_psn_isd)
   ,.chk_poison_ex_o(chk_psn_ex)

   ,.calc_status_i(calc_status)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)

   ,.fe_cmd_o(fe_cmd_o)
   ,.fe_cmd_v_o(fe_cmd_v_o)
   ,.fe_cmd_ready_i(fe_cmd_rdy_i)

   ,.chk_roll_fe_o(fe_queue_rollback_o)
   ,.chk_flush_fe_o(fe_queue_clr_o)
   ,.chk_dequeue_fe_o(fe_queue_dequeue_o)

   ,.fe_queue_i(fe_queue_i)
   ,.fe_queue_v_i(fe_queue_v_i)
   ,.fe_queue_ready_o(fe_queue_rdy_o)

   ,.issue_pkt_o(issue_pkt)
   ,.issue_pkt_v_o(issue_pkt_v)
   ,.issue_pkt_ready_i(issue_pkt_rdy)
   );

// STD: TODO -- remove synth hack and find real solution
wire [`bp_be_fu_op_width-1:0] decoded_fu_op_n;
reg  [`bp_be_fu_op_width-1:0] decoded_fu_op_r;

// STD: TODO -- remove synth hack and find real solution
always_ff @(posedge clk_i)
  begin
    decoded_fu_op_r <= decoded_fu_op_n;
  end

bp_be_calculator_top 
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

   ,.core_els_p(core_els_p)
   ,.num_lce_p(num_lce_p)
   ,.lce_sets_p(lce_sets_p)
   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
   )
 be_calculator
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.issue_pkt_i(issue_pkt)
   ,.issue_pkt_v_i(issue_pkt_v)
   ,.issue_pkt_ready_o(issue_pkt_rdy)
   
   ,.chk_dispatch_v_i(chk_dispatch_v)

   ,.chk_roll_i(chk_roll)
   ,.chk_poison_ex_i(chk_psn_ex)
   ,.chk_poison_isd_i(chk_psn_isd)

   ,.calc_status_o(calc_status)

   ,.mmu_cmd_o(mmu_cmd)
   ,.mmu_cmd_v_o(mmu_cmd_v)
   ,.mmu_cmd_ready_i(mmu_cmd_rdy)

   ,.mmu_resp_i(mmu_resp) 
   ,.mmu_resp_v_i(mmu_resp_v)
   ,.mmu_resp_ready_o(mmu_resp_rdy)   

   ,.proc_cfg_i(proc_cfg_i)     

   ,.cmt_trace_stage_reg_o(cmt_trace_stage_reg_o)
   ,.cmt_trace_result_o(cmt_trace_result_o)
   ,.cmt_trace_exc_o(cmt_trace_exc_o)

    // STD: TODO -- remove synth hack and find real solution
   ,.decoded_fu_op_o(decoded_fu_op_n)
    );

// STD: TODO -- remove synth hack and find real solution
localparam mmu_sub_width_lp = $bits(mmu_cmd)-`bp_be_fu_op_width;

bp_be_mmu_top
 #(.vaddr_width_p(vaddr_width_p)
   ,.paddr_width_p(paddr_width_p)
   ,.asid_width_p(asid_width_p)
   ,.branch_metadata_fwd_width_p(branch_metadata_fwd_width_p)

   ,.num_cce_p(num_cce_p)
   ,.num_lce_p(num_lce_p)
   ,.cce_block_size_in_bytes_p(cce_block_size_in_bytes_p)
   ,.lce_assoc_p(lce_assoc_p)
   ,.lce_sets_p(lce_sets_p)
   )
 be_mmu
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    // STD: TODO -- remove synth hack and find real solution
    ,.mmu_cmd_i({decoded_fu_op_r, mmu_cmd[mmu_sub_width_lp-1:0]})
    ,.mmu_cmd_v_i(mmu_cmd_v)
    ,.mmu_cmd_ready_o(mmu_cmd_rdy)

    ,.chk_psn_ex_i(chk_psn_ex)

    ,.mmu_resp_o(mmu_resp)
    ,.mmu_resp_v_o(mmu_resp_v)
    ,.mmu_resp_ready_i(mmu_resp_rdy)      

    ,.lce_req_o(lce_cce_req_o)
    ,.lce_req_v_o(lce_cce_req_v_o)
    ,.lce_req_ready_i(lce_cce_req_rdy_i)

    ,.lce_resp_o(lce_cce_resp_o)
    ,.lce_resp_v_o(lce_cce_resp_v_o)
    ,.lce_resp_ready_i(lce_cce_resp_rdy_i)        

    ,.lce_data_resp_o(lce_cce_data_resp_o)
    ,.lce_data_resp_v_o(lce_cce_data_resp_v_o)
    ,.lce_data_resp_ready_i(lce_cce_data_resp_rdy_i)

    ,.lce_cmd_i(cce_lce_cmd_i)
    ,.lce_cmd_v_i(cce_lce_cmd_v_i)
    ,.lce_cmd_ready_o(cce_lce_cmd_rdy_o)

    ,.lce_data_cmd_i(cce_lce_data_cmd_i)
    ,.lce_data_cmd_v_i(cce_lce_data_cmd_v_i)
    ,.lce_data_cmd_ready_o(cce_lce_data_cmd_rdy_o)

    ,.lce_tr_resp_i(lce_lce_tr_resp_i)
    ,.lce_tr_resp_v_i(lce_lce_tr_resp_v_i)
    ,.lce_tr_resp_ready_o(lce_lce_tr_resp_rdy_o)

    ,.lce_tr_resp_o(lce_lce_tr_resp_o)
    ,.lce_tr_resp_v_o(lce_lce_tr_resp_v_o)
    ,.lce_tr_resp_ready_i(lce_lce_tr_resp_rdy_i)

    ,.dcache_id_i(proc_cfg.dcache_id)
    );

  // --------------------------------------------------------------------------
  // RoCC Adaptor
  //
  bp_be_pipe_stage_reg_s commit_for_xcl;

  // RoCC: Core Control
  wire xcl_busy;
  wire xcl_interrupt;
  wire xcl_exception;

  wire        xcl_cmd_status_debug;
  wire        xcl_cmd_status_cease;
  wire [31:0] xcl_cmd_status_isa;
  wire  [1:0] xcl_cmd_status_dprv;
  wire  [1:0] xcl_cmd_status_prv;
  wire        xcl_cmd_status_sd;
  wire [26:0] xcl_cmd_status_zero2;
  wire  [1:0] xcl_cmd_status_sxl;
  wire  [1:0] xcl_cmd_status_uxl;
  wire        xcl_cmd_status_sd_rv32;
  wire  [7:0] xcl_cmd_status_zero1;
  wire        xcl_cmd_status_tsr;
  wire        xcl_cmd_status_tw;
  wire        xcl_cmd_status_tvm;
  wire        xcl_cmd_status_mxr;
  wire        xcl_cmd_status_sum;
  wire        xcl_cmd_status_mprv;
  wire  [1:0] xcl_cmd_status_xs;
  wire  [1:0] xcl_cmd_status_fs;
  wire  [1:0] xcl_cmd_status_mpp;
  wire  [1:0] xcl_cmd_status_hpp;
  wire        xcl_cmd_status_spp;
  wire        xcl_cmd_status_mpie;
  wire        xcl_cmd_status_hpie;
  wire        xcl_cmd_status_spie;
  wire        xcl_cmd_status_upie;
  wire        xcl_cmd_status_mie;
  wire        xcl_cmd_status_hie;
  wire        xcl_cmd_status_sie;
  wire        xcl_cmd_status_uie;

  // RoCC: Register Mode
  wire         xcl_cmd_ready;
  wire         xcl_cmd_v;
  wire   [6:0] xcl_cmd_inst_funct;
  wire   [4:0] xcl_cmd_inst_rs2;
  wire   [4:0] xcl_cmd_inst_rs1;
  wire         xcl_cmd_inst_xd;
  wire         xcl_cmd_inst_xs1;
  wire         xcl_cmd_inst_xs2;
  wire   [4:0] xcl_cmd_inst_rd;
  wire   [6:0] xcl_cmd_inst_opcode;
  wire  [63:0] xcl_cmd_rs1;
  wire  [63:0] xcl_cmd_rs2;

  wire           xcl_resp_ready;
  wire           xcl_resp_v;
  wire     [4:0] xcl_resp_rd;
  wire    [63:0] xcl_resp_data;

  // RoCC: Memory Mode
  wire         xcl_mem_req_ready;
  wire         xcl_mem_req_v;
  wire  [39:0] xcl_mem_req_addr;
  wire   [7:0] xcl_mem_req_tag;
  wire   [4:0] xcl_mem_req_cmd;
  wire   [2:0] xcl_mem_req_typ;
  wire         xcl_mem_req_phys;
  wire  [63:0] xcl_mem_req_data;

  wire        xcl_mem_resp_v;
  wire [39:0] xcl_mem_resp_addr;
  wire [7:0]  xcl_mem_resp_tag;
  wire [4:0]  xcl_mem_resp_cmd;
  wire [2:0]  xcl_mem_resp_typ;
  wire [63:0] xcl_mem_resp_data;
  wire        xcl_mem_resp_has_data;

  wire        xcl_mem_resp_replay;
  wire [63:0] xcl_mem_resp_data_word_bypass;
  wire [63:0] xcl_mem_resp_store_data;

  // LCE Command / Data Interface
  wire [cce_lce_cmd_width_lp-1:0] xcl_lce_cmd;
  wire                            xcl_lce_cmd_v;
  wire                            xcl_lce_cmd_ready;

  wire [cce_lce_data_cmd_width_lp-1:0] xcl_lce_data_cmd;
  wire                                 xcl_lce_data_cmd_v;
  wire                                 xcl_lce_data_cmd_ready;

  // LCE Response Interface
  wire [lce_cce_resp_width_lp-1:0] xcl_lce_resp;
  wire                             xcl_lce_resp_v;
  wire                             xcl_lce_resp_ready;

  wire [lce_cce_data_resp_width_lp-1:0] xcl_lce_data_resp;
  wire                                  xcl_lce_data_resp_v;
  wire                                  xcl_lce_data_resp_ready;

  // Core-Side Command
  wire       xcl_cmd_stall;

  // Core-Side Response
  wire        xcl_rf_wr_rdy = 1'b1;
  wire        xcl_rf_wr_v;
  wire  [4:0] xcl_rf_rd_addr;
  wire [63:0] xcl_rf_rd_data;
  
  bp_be_rocc_adaptor #(
    .num_cce_p        (num_cce_p),
    .num_lce_p        (num_lce_p),
    .lce_addr_width_p (paddr_width_p),
    .lce_data_width_p (cce_block_size_in_bits_lp),
    .ways_p           (lce_assoc_p)
  ) u_bp_be_rocc_adaptor (
    // Clocks and Resets
    .reset_i (reset_i), // (I) Reset, active high
    .clk_i   (clk_i),   // (I) Clock

    // RoCC: Core Control
    .busy_i      (xcl_busy),      // (I) Busy signal
    .interrupt_i (xcl_interrupt), // (I) Interrupt
    .exception_o (xcl_exception), // (O) Exception

    .cmd_status_debug_o   (xcl_cmd_status_debug),   // (O)
    .cmd_status_cease_o   (xcl_cmd_status_cease),   // (O)
    .cmd_status_isa_o     (xcl_cmd_status_isa),     // (O)
    .cmd_status_dprv_o    (xcl_cmd_status_dprv),    // (O)
    .cmd_status_prv_o     (xcl_cmd_status_prv),     // (O)
    .cmd_status_sd_o      (xcl_cmd_status_sd),      // (O)
    .cmd_status_zero2_o   (xcl_cmd_status_zero2),   // (O)
    .cmd_status_sxl_o     (xcl_cmd_status_sxl),     // (O)
    .cmd_status_uxl_o     (xcl_cmd_status_uxl),     // (O)
    .cmd_status_sd_rv32_o (xcl_cmd_status_sd_rv32), // (O)
    .cmd_status_zero1_o   (xcl_cmd_status_zero1),   // (O)
    .cmd_status_tsr_o     (xcl_cmd_status_tsr),     // (O)
    .cmd_status_tw_o      (xcl_cmd_status_tw),      // (O)
    .cmd_status_tvm_o     (xcl_cmd_status_tvm),     // (O)
    .cmd_status_mxr_o     (xcl_cmd_status_mxr),     // (O)
    .cmd_status_sum_o     (xcl_cmd_status_sum),     // (O)
    .cmd_status_mprv_o    (xcl_cmd_status_mprv),    // (O)
    .cmd_status_xs_o      (xcl_cmd_status_xs),      // (O)
    .cmd_status_fs_o      (xcl_cmd_status_fs),      // (O)
    .cmd_status_mpp_o     (xcl_cmd_status_mpp),     // (O)
    .cmd_status_hpp_o     (xcl_cmd_status_hpp),     // (O)
    .cmd_status_spp_o     (xcl_cmd_status_spp),     // (O)
    .cmd_status_mpie_o    (xcl_cmd_status_mpie),    // (O)
    .cmd_status_hpie_o    (xcl_cmd_status_hpie),    // (O)
    .cmd_status_spie_o    (xcl_cmd_status_spie),    // (O)
    .cmd_status_upie_o    (xcl_cmd_status_upie),    // (O)
    .cmd_status_mie_o     (xcl_cmd_status_mie),     // (O)
    .cmd_status_hie_o     (xcl_cmd_status_hie),     // (O)
    .cmd_status_sie_o     (xcl_cmd_status_sie),     // (O)
    .cmd_status_uie_o     (xcl_cmd_status_uie),     // (O)

    // RoCC: Register Mode
    .cmd_ready_i       (xcl_cmd_ready),       // (I) Control ready
    .cmd_v_o           (xcl_cmd_v),           // (O) Control valid
    .cmd_inst_funct_o  (xcl_cmd_inst_funct),  // (O) Accelerator function
    .cmd_inst_rs2_o    (xcl_cmd_inst_rs2),    // (O) Source Register 2 ID
    .cmd_inst_rs1_o    (xcl_cmd_inst_rs1),    // (O) Source Regsiter 1 ID
    .cmd_inst_xd_o     (xcl_cmd_inst_xd),     // (O) Destination Register use valid
    .cmd_inst_xs1_o    (xcl_cmd_inst_xs1),    // (O) Source Register 1 use valid
    .cmd_inst_xs2_o    (xcl_cmd_inst_xs2),    // (O) Source Register 2 use valid
    .cmd_inst_rd_o     (xcl_cmd_inst_rd),     // (O) Destination Register ID
    .cmd_inst_opcode_o (xcl_cmd_inst_opcode), // (O) Custom instruction opcode
    .cmd_rs1_o         (xcl_cmd_rs1),         // (O) Source Register 1 Data
    .cmd_rs2_o         (xcl_cmd_rs2),         // (O) Source Register 2 Data

    .resp_ready_o      (xcl_resp_ready), // (O) Response ready
    .resp_v_i          (xcl_resp_v),     // (I) Response valid
    .resp_rd_i         (xcl_resp_rd),    // (I) Response Destination Register ID
    .resp_data_i       (xcl_resp_data),  // (I) Response Destination Register data

    // RoCC: Memory Mode //
    .mem_req_ready_o (xcl_mem_req_ready), // (O) Request ready
    .mem_req_v_i     (xcl_mem_req_v),     // (I) Request valid
    .mem_req_addr_i  (xcl_mem_req_addr),  // (I) Request address
    .mem_req_tag_i   (xcl_mem_req_tag),   // (I) Request tag
    .mem_req_cmd_i   (xcl_mem_req_cmd),   // (I) Request command code
    .mem_req_typ_i   (xcl_mem_req_typ),   // (I) Response width request
    .mem_req_phys_i  (xcl_mem_req_phys),  // (I) Request address type
    .mem_req_data_i  (xcl_mem_req_data),  // (I) Request write data

    .mem_resp_v_o        (xcl_mem_resp_v),                // (O) Response valid
    .mem_resp_addr_o     (xcl_mem_resp_addr),             // (O) Response address
    .mem_resp_tag_o      (xcl_mem_resp_tag),              // (O) Response tag
    .mem_resp_cmd_o      (xcl_mem_resp_cmd),              // (O) Response command code
    .mem_resp_typ_o      (xcl_mem_resp_typ),              // (O) Response data width indicator
    .mem_resp_data_o     (xcl_mem_resp_data),             // (O) Response data
    .mem_resp_has_data_o (xcl_mem_resp_has_data),         // (O) Response data valid indicator

    .mem_resp_replay_o           (xcl_mem_resp_replay),           // (O) TBD
    .mem_resp_data_word_bypass_o (xcl_mem_resp_data_word_bypass), // (O) Response store bypass indicator
    .mem_resp_store_data_o       (xcl_mem_resp_store_data),       // (O) Response store data

    // LCE Command / Data Interface
    .lce_cmd_o            (xcl_lce_cmd),            // (O)
    .lce_cmd_v_o          (xcl_lce_cmd_v),          // (O)
    .lce_cmd_ready_i      (xcl_lce_cmd_ready),      // (I)

    .lce_data_cmd_o       (xcl_lce_data_cmd),       // (O)
    .lce_data_cmd_v_o     (xcl_lce_data_cmd_v),     // (O)
    .lce_data_cmd_ready_i (xcl_lce_data_cmd_ready), // (I)

    // LCE Response Interface
    .lce_resp_i            (xcl_lce_resp),       // (I)
    .lce_resp_v_i          (xcl_lce_resp_v),     // (I)
    .lce_resp_ready_o      (xcl_lce_resp_ready), // (O)

    .lce_data_resp_i       (xcl_lce_data_resp),       // (I)
    .lce_data_resp_v_i     (xcl_lce_data_resp_v),     // (I)
    .lce_data_resp_ready_o (xcl_lce_data_resp_ready), // (O)

    // Core-Side Command
    .instr_i     (commit_for_xcl.instr),
    .rs1_data_i  (commit_for_xcl.instr_operands.rs1),
    .rs2_data_i  (commit_for_xcl.instr_operands.rs2),
    .cmd_stall_o (xcl_cmd_stall),

    // Core-Side Response
    .rf_wr_rdy_i  (xcl_rf_wr_rdy),  // (I) Regfile write ready
    .rf_wr_v_o    (xcl_rf_wr_v),    // (O) Regfile write enable
    .rf_rd_addr_o (xcl_rf_rd_addr), // (O) Regfile write address
    .rf_rd_data_o (xcl_rf_rd_data)  // (O) Regfile write data
  );

  assign commit_for_xcl = cmt_trace_stage_reg_o;
  assign xcl_cmd_ready = 1'd1; // PHMonRoCC always ready (?)
  
  // --------------------------------------------------------------------------

  PHMonRoCC komodo (
    .clock                         (clk_i),
    .reset                         (reset_i),

    .io_cmd_valid                  (xcl_cmd_v),
    .io_cmd_bits_inst_funct        (xcl_cmd_inst_funct),
    .io_cmd_bits_inst_rd           (xcl_cmd_inst_rd),
    .io_cmd_bits_rs1               (xcl_cmd_rs1),
    .io_cmd_bits_rs2               (xcl_cmd_rs2),

    .io_resp_valid                 (xcl_resp_v),
    .io_resp_bits_rd               (xcl_resp_rd),
    .io_resp_bits_data             (xcl_resp_data),

    .io_mem_req_ready              (xcl_mem_req_ready),
    .io_mem_req_valid              (xcl_mem_req_v),
    .io_mem_req_bits_addr          (xcl_mem_req_addr),
    .io_mem_req_bits_tag           (xcl_mem_req_tag),
    .io_mem_req_bits_cmd           (xcl_mem_req_cmd),
    .io_mem_req_bits_typ           (xcl_mem_req_typ),
    .io_mem_req_bits_data          (xcl_mem_req_data),

    .io_mem_resp_valid             (xcl_mem_resp_v),
    .io_mem_resp_bits_addr         (xcl_mem_resp_addr),
    .io_mem_resp_bits_data         (xcl_mem_resp_data),
    .io_mem_resp_bits_count        (64'd0),
    .io_mem_resp_bits_s2_xcpt_else (1'd0),

    .io_mem_s2_xcpt_ma_ld          (1'd0),
    .io_mem_s2_xcpt_ma_st          (1'd0),
    .io_mem_s2_xcpt_pf_ld          (1'd0),
    .io_mem_s2_xcpt_pf_st          (1'd0),
    .io_mem_s2_xcpt_ae_ld          (1'd0),
    .io_mem_s2_xcpt_ae_st          (1'd0),

    .io_mem_assertion              (1'd0),
    .io_busy                       (xcl_busy),
    .io_interrupt                  (xcl_interrupt),
    .io_exception                  (xcl_exception),

    .io_commitLog_valid            (1'd1),
    .io_commitLog_bits_pc_src      (pc_src),
    .io_commitLog_bits_pc_dst      (pc_dst),
    .io_commitLog_bits_inst        (commit_for_xcl.instr),
    .io_commitLog_bits_addr        ({8'd0, mmu_cmd.vaddr}),
    .io_commitLog_bits_data        (64'd0),
    .io_commitLog_bits_priv        (2'd0),
    .io_commitLog_bits_time        (64'd0)
  );

endmodule : bp_be_top

