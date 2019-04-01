/**
 *
 * Name:
 *   bp_mmu_top.v
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
 *   mmu_resp_i                  -
 *   mmu_resp_v_i                -
 *   mmu_resp_ready_o            -
 *
 *   cce_lce_cmd_i               -
 *   cce_lce_cmd_v_i             -
 *   cce_lce_cmd_ready_o         -
 *
 *   cce_lce_data_cmd_i          -
 *   cce_lce_data_cmd_v_i        -
 *   cce_lce_data_cmd_ready_o    -
 * 
 *   lce_lce_tr_resp_i           - 
 *   lce_lce_tr_resp_v_i         -
 *   lce_lce_tr_resp_ready_o     -
 * 
 *   proc_cfg_i                  -
 *
 * Outputs:
 *   mmu_cmd_o                   -
 *   mmu_cmd_v_o                 -
 *   mmu_cmd_ready_i             -
 *
 *   lce_req_o               -
 *   lce_req_v_o             -
 *   lce_req_ready_i         -
 *
 *   lce_resp_o              -
 *   lce_resp_v_o            -
 *   lce_resp_ready_i        -
 *
 *   lce_data_resp_o         -
 *   lce_data_resp_v_o       -
 *   lce_data_resp_ready_i   -
 *
 *   lce_lce_tr_resp_o           -
 *   lce_lce_tr_resp_v_o         -
 *   lce_lce_tr_resp_ready_i     -
 *
 *   dcache_id_i                 -
 *
 * Keywords:
 *   mmu, top, dcache, d$, mem
 * 
 * Notes:
 *   Does not currently support virtual memory translation
 */

module bp_be_mmu_top 
  import bp_common_pkg::*;
  import bp_be_pkg::*;
  import bp_be_rv64_pkg::*;
  import bp_be_dcache_pkg::*;
 #(parameter vaddr_width_p                 = "inv"
   , parameter paddr_width_p               = "inv"
   , parameter asid_width_p                = "inv"
   , parameter branch_metadata_fwd_width_p = "inv"
 
   // ME parameters
   , parameter num_cce_p                 = "inv"
   , parameter num_lce_p                 = "inv"
   , parameter cce_block_size_in_bytes_p = "inv"
   , parameter lce_assoc_p               = "inv"
   , parameter lce_sets_p                = "inv"


   // From RISC-V specifications
   , localparam reg_data_width_lp = rv64_reg_data_width_gp

   // Generated parameters
   // D$   
   , localparam block_size_in_words_lp = lce_assoc_p // Due to cache interleaving scheme
   , localparam data_mask_width_lp     = (reg_data_width_lp >> 3) // Byte mask
   , localparam byte_offset_width_lp   = `BSG_SAFE_CLOG2(reg_data_width_lp >> 3)
   , localparam word_offset_width_lp   = `BSG_SAFE_CLOG2(block_size_in_words_lp)
   , localparam block_offset_width_lp  = (word_offset_width_lp + byte_offset_width_lp)
   , localparam index_width_lp         = `BSG_SAFE_CLOG2(lce_sets_p)
   , localparam page_offset_width_lp   = (block_offset_width_lp + index_width_lp)
   , localparam dcache_pkt_width_lp    = `bp_be_dcache_pkt_width(page_offset_width_lp
                                                                 , reg_data_width_lp
                                                                 )
   , localparam lce_id_width_lp = `BSG_SAFE_CLOG2(num_lce_p)

   // MMU                                                              
   , localparam mmu_cmd_width_lp  = `bp_be_mmu_cmd_width(vaddr_width_p)
   , localparam mmu_resp_width_lp = `bp_be_mmu_resp_width
   , localparam vtag_width_lp     = `bp_be_vtag_width(vaddr_width_p
                                                      , lce_sets_p
                                                      , cce_block_size_in_bytes_p
                                                      )
                                                    
   , localparam ptag_width_lp     = `bp_be_ptag_width(paddr_width_p
                                                      , lce_sets_p
                                                      , cce_block_size_in_bytes_p
                                                      )
                                                      
   // ME
   , localparam cce_block_size_in_bits_lp = 8 * cce_block_size_in_bytes_p

   , localparam lce_req_width_lp = `bp_lce_cce_req_width(num_cce_p
                                                         , num_lce_p
                                                         , paddr_width_p
                                                         , lce_assoc_p
                                                         )
   , localparam lce_resp_width_lp = `bp_lce_cce_resp_width(num_cce_p
                                                           , num_lce_p
                                                           , paddr_width_p
                                                           )
   , localparam lce_data_resp_width_lp = `bp_lce_cce_data_resp_width(num_cce_p
                                                                     , num_lce_p
                                                                     , paddr_width_p
                                                                     , cce_block_size_in_bits_lp
                                                                     )
   , localparam cce_cmd_width_lp=`bp_cce_lce_cmd_width(num_cce_p
                                                       , num_lce_p
                                                       , paddr_width_p
                                                       , lce_assoc_p
                                                       )
   , localparam cce_data_cmd_width_lp=`bp_cce_lce_data_cmd_width(num_cce_p
                                                                 , num_lce_p
                                                                 , paddr_width_p
                                                                 , cce_block_size_in_bits_lp
                                                                 , lce_assoc_p
                                                                 )
   , localparam lce_lce_tr_resp_width_lp=`bp_lce_lce_tr_resp_width(num_lce_p
                                                                   , paddr_width_p
                                                                   , cce_block_size_in_bits_lp
                                                                   , lce_assoc_p
                                                                   )
   )
  (input                                   clk_i
   , input                                 reset_i


   , input [mmu_cmd_width_lp-1:0]          mmu_cmd_i
   , input                                 mmu_cmd_v_i
   , output                                mmu_cmd_ready_o

   , input                                 chk_psn_ex_i

   , output [mmu_resp_width_lp-1:0]        mmu_resp_o
   , output                                mmu_resp_v_o
   , input                                 mmu_resp_ready_i

   , output [lce_req_width_lp-1:0]         lce_req_o
   , output                                lce_req_v_o
   , input                                 lce_req_ready_i

   , output [lce_resp_width_lp-1:0]        lce_resp_o
   , output                                lce_resp_v_o
   , input                                 lce_resp_ready_i                                 

   , output [lce_data_resp_width_lp-1:0]   lce_data_resp_o
   , output                                lce_data_resp_v_o
   , input                                 lce_data_resp_ready_i

   , input [cce_cmd_width_lp-1:0]          lce_cmd_i
   , input                                 lce_cmd_v_i
   , output                                lce_cmd_ready_o

   , input [cce_data_cmd_width_lp-1:0]     lce_data_cmd_i
   , input                                 lce_data_cmd_v_i
   , output                                lce_data_cmd_ready_o

   , input [lce_lce_tr_resp_width_lp-1:0]  lce_tr_resp_i
   , input                                 lce_tr_resp_v_i
   , output                                lce_tr_resp_ready_o

   , output [lce_lce_tr_resp_width_lp-1:0] lce_tr_resp_o
   , output                                lce_tr_resp_v_o
   , input                                 lce_tr_resp_ready_i

   , input [lce_id_width_lp-1:0]           dcache_id_i
   );

`declare_bp_be_internal_if_structs(vaddr_width_p
                                   , paddr_width_p
                                   , asid_width_p
                                   , branch_metadata_fwd_width_p
                                   );

`declare_bp_be_mmu_structs(vaddr_width_p, lce_sets_p, cce_block_size_in_bytes_p)
`declare_bp_be_dcache_pkt_s(page_offset_width_lp, reg_data_width_lp);

// Cast input and output ports 
bp_be_mmu_cmd_s        mmu_cmd;
bp_be_mmu_resp_s       mmu_resp;
bp_be_mmu_vaddr_s      mmu_cmd_vaddr;

assign mmu_cmd    = mmu_cmd_i;
assign mmu_resp_o = mmu_resp;

// TODO: This struct is not working properly (mismatched widths in synth). Figure out why.
//         This cast works, though
assign mmu_cmd_vaddr = mmu_cmd.vaddr;

/* Internal connections */
logic tlb_miss;
logic [ptag_width_lp-1:0] ptag_r;

bp_be_dcache_pkt_s dcache_pkt;
logic dcache_ready, dcache_miss_v, dcache_v;

/* Suppress warnings */
logic unused0;
assign unused0 = mmu_resp_ready_i;

// Passthrough TLB conversion
always_ff @(posedge clk_i) 
  begin
    ptag_r <= ptag_width_lp'(mmu_cmd_vaddr.tag);
  end

bp_be_dcache 
  #(.data_width_p(reg_data_width_lp) 
    ,.sets_p(lce_sets_p)
    ,.ways_p(lce_assoc_p)
    ,.paddr_width_p(paddr_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    )
  dcache
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(dcache_id_i)

    ,.dcache_pkt_i(dcache_pkt)
    ,.v_i(mmu_cmd_v_i)
    ,.ready_o(dcache_ready)

    ,.v_o(dcache_v)
    ,.data_o(mmu_resp.data)

    ,.tlb_miss_i(1'b0)
    ,.ptag_i(ptag_r)

    ,.cache_miss_o(dcache_miss_v)
    ,.poison_i(chk_psn_ex_i)

    // LCE-CCE interface
    ,.lce_req_o(lce_req_o)
    ,.lce_req_v_o(lce_req_v_o)
    ,.lce_req_ready_i(lce_req_ready_i)

    ,.lce_resp_o(lce_resp_o)
    ,.lce_resp_v_o(lce_resp_v_o)
    ,.lce_resp_ready_i(lce_resp_ready_i)

    ,.lce_data_resp_o(lce_data_resp_o)
    ,.lce_data_resp_v_o(lce_data_resp_v_o)
    ,.lce_data_resp_ready_i(lce_data_resp_ready_i)

    // CCE-LCE interface
    ,.lce_cmd_i(lce_cmd_i)
    ,.lce_cmd_v_i(lce_cmd_v_i)
    ,.lce_cmd_ready_o(lce_cmd_ready_o)

    ,.lce_data_cmd_i(lce_data_cmd_i)
    ,.lce_data_cmd_v_i(lce_data_cmd_v_i)
    ,.lce_data_cmd_ready_o(lce_data_cmd_ready_o)

    // LCE-LCE interface
    ,.lce_tr_resp_i(lce_tr_resp_i)
    ,.lce_tr_resp_v_i(lce_tr_resp_v_i)
    ,.lce_tr_resp_ready_o(lce_tr_resp_ready_o)

    ,.lce_tr_resp_o(lce_tr_resp_o)
    ,.lce_tr_resp_v_o(lce_tr_resp_v_o)
    ,.lce_tr_resp_ready_i(lce_tr_resp_ready_i)
    );

/* -----\/----- EXCLUDED -----\/-----
    logic [lce_req_width_lp-1:0] lce_sb_req;
    logic                        lce_sb_req_v;
    logic                        lce_sb_req_ready;

    logic [lce_resp_width_lp-1:0] lce_sb_resp;
    logic                         lce_sb_resp_v;
    logic                         lce_sb_resp_ready;                                 

    logic [lce_data_resp_width_lp-1:0] lce_sb_data_resp;
    logic                              lce_sb_data_resp_v;
    logic                              lce_sb_data_resp_ready;

    logic [cce_cmd_width_lp-1:0] sb_lce_cmd;
    logic                        sb_lce_cmd_v;
    logic                        sb_lce_cmd_ready;

    logic [cce_data_cmd_width_lp-1:0] sb_lce_data_cmd;
    logic                             sb_lce_data_cmd_v;
    logic                             sb_lce_data_cmd_ready;

bp_be_dcache 
  #(.data_width_p(reg_data_width_lp) 
    ,.sets_p(lce_sets_p)
    ,.ways_p(lce_assoc_p)
    ,.paddr_width_p(paddr_width_p)
    ,.num_cce_p(num_cce_p)
    ,.num_lce_p(num_lce_p)
    )
  dcache
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.lce_id_i(dcache_id_i)

    ,.dcache_pkt_i(dcache_pkt)
    ,.v_i(mmu_cmd_v_i)
    ,.ready_o(dcache_ready)

    ,.v_o(dcache_v)
    ,.data_o(mmu_resp.data)

    ,.tlb_miss_i(1'b0)
    ,.ptag_i(ptag_r)

    ,.cache_miss_o(dcache_miss_v)
    ,.poison_i(chk_psn_ex_i)

    // LCE-CCE interface
    ,.lce_req_o(lce_sb_req)
    ,.lce_req_v_o(lce_sb_req_v)
    ,.lce_req_ready_i(lce_sb_req_ready)

    ,.lce_resp_o(lce_sb_resp)
    ,.lce_resp_v_o(lce_sb_resp_v)
    ,.lce_resp_ready_i(lce_sb_resp_ready)

    ,.lce_data_resp_o(lce_sb_data_resp)
    ,.lce_data_resp_v_o(lce_sb_data_resp_v)
    ,.lce_data_resp_ready_i(lce_sb_data_resp_ready)

    // CCE-LCE interface
    ,.lce_cmd_i(sb_lce_cmd)
    ,.lce_cmd_v_i(sb_lce_cmd_v)
    ,.lce_cmd_ready_o(sb_lce_cmd_ready)

    ,.lce_data_cmd_i(sb_lce_data_cmd)
    ,.lce_data_cmd_v_i(sb_lce_data_cmd_v)
    ,.lce_data_cmd_ready_o(sb_lce_data_cmd_ready)

    // LCE-LCE interface
    ,.lce_tr_resp_i(lce_tr_resp_i)
    ,.lce_tr_resp_v_i(lce_tr_resp_v_i)
    ,.lce_tr_resp_ready_o(lce_tr_resp_ready_o)

    ,.lce_tr_resp_o(lce_tr_resp_o)
    ,.lce_tr_resp_v_o(lce_tr_resp_v_o)
    ,.lce_tr_resp_ready_i(lce_tr_resp_ready_i)
    );

  // ---------------------------------------------------------------------------
  // Stream Buffer
  //
  bp_be_stream_buffer #(
    .num_cce_p        (num_cce_p),
    .num_lce_p        (num_lce_p),
    .lce_addr_width_p (paddr_width_p),
    .lce_data_width_p (cce_block_size_in_bits_lp),
    .ways_p           (lce_assoc_p),
    .sb_depth_p       (4)
  ) u_bp_be_stream_buffer (
    // Clocks and Resets
    .reset_i (reset_i), // (I) Reset, active high

    .clk_i   (clk_i),   // (I) Clock

    // LCE-SB Interface
    .lce_sb_req_i       (lce_sb_req),       // (I)
    .lce_sb_req_v_i     (lce_sb_req_v),     // (I)
    .lce_sb_req_ready_o (lce_sb_req_ready), // (O)

    .lce_sb_resp_i       (lce_sb_resp),       // (I)
    .lce_sb_resp_v_i     (lce_sb_resp_v),     // (I)
    .lce_sb_resp_ready_o (lce_sb_resp_ready), // (O)

    .lce_sb_data_resp_i       (lce_sb_data_resp),       // (I)
    .lce_sb_data_resp_v_i     (lce_sb_data_resp_v),     // (I)
    .lce_sb_data_resp_ready_o (lce_sb_data_resp_ready), // (O)

    // SB-LCE Interface
    .sb_lce_cmd_o       (sb_lce_cmd),            // (O)
    .sb_lce_cmd_v_o     (sb_lce_cmd_v),          // (O)
    .sb_lce_cmd_ready_i (sb_lce_cmd_ready),      // (I)

    .sb_lce_data_cmd_o       (sb_lce_data_cmd),       // (O)
    .sb_lce_data_cmd_v_o     (sb_lce_data_cmd_v),     // (O)
    .sb_lce_data_cmd_ready_i (sb_lce_data_cmd_ready), // (I)

    // SB-CCE Interface
    .sb_cce_req_o       (lce_req_o),             // (O)
    .sb_cce_req_v_o     (lce_req_v_o),           // (O)
    .sb_cce_req_ready_i (lce_req_ready_i),       // (I)

    .sb_cce_resp_o       (lce_resp_o),            // (O)
    .sb_cce_resp_v_o     (lce_resp_v_o),          // (O)
    .sb_cce_resp_ready_i (lce_resp_ready_i),      // (I)

    .sb_cce_data_resp_o       (lce_data_resp_o),       // (O)
    .sb_cce_data_resp_v_o     (lce_data_resp_v_o),     // (O)
    .sb_cce_data_resp_ready_i (lce_data_resp_ready_i), // (I)

    // CCE-SB Interface
    .cce_sb_cmd_i       (lce_cmd_i),       // (I)
    .cce_sb_cmd_v_i     (lce_cmd_v_i),     // (I)
    .cce_sb_cmd_ready_o (lce_cmd_ready_o), // (O)

    .cce_sb_data_cmd_i       (lce_data_cmd_i),       // (I)
    .cce_sb_data_cmd_v_i     (lce_data_cmd_v_i),     // (I)
    .cce_sb_data_cmd_ready_o (lce_data_cmd_ready_o)  // (O)
  );
 -----/\----- EXCLUDED -----/\----- */

always_comb 
  begin
    dcache_pkt.opcode      = bp_be_dcache_opcode_e'(mmu_cmd.mem_op);
    dcache_pkt.page_offset = {mmu_cmd_vaddr.index, mmu_cmd_vaddr.offset};
    dcache_pkt.data        = mmu_cmd.data;

    mmu_resp.exception.cache_miss_v = dcache_miss_v;
  end

// Ready-valid handshakes
assign mmu_resp_v_o    = dcache_v;
assign mmu_cmd_ready_o = dcache_ready & ~dcache_miss_v;

endmodule : bp_be_mmu_top
