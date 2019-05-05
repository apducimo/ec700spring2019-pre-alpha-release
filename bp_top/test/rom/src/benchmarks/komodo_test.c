#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "varanus.h"

// nop different from RISC-V's normal nop. Has binary format 0x00001013.
#define VARANUS_NOP asm volatile ("slli x0, x1, 0")

/* int test() { */
/*   int a = 20; */
/*   return a*2; */
/* } */

int main (int argc, char * argv[]) {
  mask_t mask_inst/*, mask_pc*/, mask_inst2;
  act_conf_table_t action_mu1, action_mu2;
  //  xlen_t *komodo_sp = (xlen_t*) calloc(50,sizeof(long unsigned int));
  static long unsigned int foo [50];
  xlen_t *komodo_sp = (xlen_t*) (&foo);

  //xlen_t *komodo_sp = (xlen_t*) malloc(sizeof(xlen_t)*sysconf(_SC_PAGESIZE));
  //memset(komodo_sp, 0, sizeof(xlen_t)*sysconf(_SC_PAGESIZE));

  komodo_set_local_reg(0, komodo_sp);
  komodo_set_local_reg(1, komodo_sp);
  
  // Setup an instruction mask that'll match all program counters, but
  // only our special nop
  mask_inst.care.pc_src    = 0x0000000000000000; // match all PC_src
  mask_inst.dont_care.pc_src   = 0xffffffffffffffff;
  mask_inst.care.pc_dst    = 0x0000000000000000; // match all PC_dst
  mask_inst.dont_care.pc_dst   = 0xffffffffffffffff;
  mask_inst.care.inst  = 0x00009013; // match Call insts
  mask_inst.dont_care.inst = 0xfffff008;
  mask_inst.care.rd = 0x0000000000000000;
  mask_inst.dont_care.rd = 0xffffffffffffffff;
  mask_inst.care.data = 0x0000000000000000;
  mask_inst.dont_care.data = 0xffffffffffffffff;

  mask_inst2.care.pc_src    = 0x0000000000000000; // match all PC_src
  mask_inst2.dont_care.pc_src   = 0xffffffffffffffff;
  mask_inst2.care.pc_dst    = 0x0000000000000000; // match all PC_dst
  mask_inst2.dont_care.pc_dst   = 0xffffffffffffffff;
  mask_inst2.care.inst = 0x00009013; // match Ret insts
  mask_inst2.dont_care.inst = 0x00000000;
  mask_inst2.care.rd = 0x0000000000000000;
  mask_inst2.dont_care.rd = 0xffffffffffffffff;
  mask_inst2.care.data = 0x0000000000000000;
  mask_inst2.dont_care.data = 0xffffffffffffffff;

  // Set the patterns and reset the stored comparator values.
  komodo_pattern(0, &mask_inst);
  komodo_reset_val(0);
  komodo_pattern(1, &mask_inst2);
  komodo_reset_val(1);

  //Increment the Shadow stack pointer
  action_mu1.op_type = 3; //ALU operation
  action_mu1.in1 = 3; //Lcoal1
  action_mu1.in2 = 2; //Constant
  action_mu1.fn = 0; //Add
  action_mu1.out = 0; //Local1
  action_mu1.data = 8; //Constant Data = 8
  komodo_action_config(0, &action_mu1);

  //Write the PC_src of Call inst in shared memory space
  action_mu1.op_type = 1; // Memory write
  action_mu1.in1 = 0; //MU_DATA
  action_mu1.in2 = 3; //Local1
  action_mu1.fn = 9;
  action_mu1.out = 0;
  action_mu1.data = 0;
  komodo_action_config(0, &action_mu1);

  //Decrement PC_dst of Ret inst by 4
  /*action_mu2.op_type = 3; //ALU operation
  action_mu2.in1 = 0; //DATA_MU
  action_mu2.in2 = 2; //Constant
  action_mu2.fn = 1; //SUB
  action_mu2.out = 1; //Local2
  action_mu2.data = 4;
  komodo_action_config(1, &action_mu2);*/

  action_mu2.op_type = 3; //ALU operation
  action_mu2.in1 = 3; //Lcoal1
  action_mu2.in2 = 2; //Constant
  action_mu2.fn = 0; //Add
  action_mu2.out = 0; //Local1
  action_mu2.data = 8; //Constant Data = 8
  komodo_action_config(1, &action_mu2);

  //Write the PC_src of Call inst in shared memory space
  action_mu2.op_type = 1; // Memory write
  action_mu2.in1 = 0; //MU_DATA
  action_mu2.in2 = 3; //Local1
  action_mu2.fn = 9;
  action_mu2.out = 0;
  action_mu2.data = 0;
  komodo_action_config(1, &action_mu2);

  //Read the most recent PC_src of call stored in the share memory space
  /*action_mu2.op_type = 2; //Memory read
  action_mu2.in1 = 0; //Doesn't matter, it's read
  action_mu2.in2 = 3; //Local1
  action_mu2.fn = 9;  //Doesn't matter, no ALU operation
  action_mu2.out = 0; //Doesn't matter, it get stored in mu_resp
  action_mu2.data = 0; //Doesn't matter, no ALU operation
  komodo_action_config(1, &action_mu2);*/

  //Comapre pc_dst and pc_src and trigger interrupt
  /*action_mu2.op_type = 3; //ALU operation
  action_mu2.in1 = 6; //MU_resp
  action_mu2.in2 = 4; //Lcoal2
  action_mu2.fn = 5; //Set Equal
  action_mu2.out = 5; //Interrupt reg
  action_mu2.data = 0;
  komodo_action_config(1, &action_mu2);

  //Decrement shadow stack pointer
  action_mu2.op_type = 3; //ALU operation
  action_mu2.in1 = 3; //Lcoal1
  action_mu2.in2 = 2; //Constant
  action_mu2.fn = 1; //Subtract
  action_mu2.out = 0; //Local1
  action_mu2.data = 8; //Constant Data = 8
  komodo_action_config(1, &action_mu2);*/
    
  xlen_t match_count = 0;
  xlen_t match_count2 = 0;
  //xlen_t match_instruction_count = 0;

    // Set match conditions
  komodo_match_count(0, 1, &match_count);
  komodo_match_count(1, 1, &match_count2);

  // Set memory type
  komodo_set_mem_typ(3);
  ROCC_INSTRUCTION_0_R_R(XCUSTOM_KOMODO, 0, 0, 2, 11, 12);
  //asm volatile ("custom1 0, 0, 0, 2");

  //komodo_match_count_instruction(1, 20, &match_instruction_count);
  //komodo_doorbell_register(&match_doorbell);

  //komodo_doorbell_register(&match_doorbell);
  komodo_set_commit_index(0, 0);
  komodo_set_commit_index(1, 1);
  komodo_set_local_reg(0, komodo_sp);
  //komodo_set_sp_offset(komodo_sp);

  // Run a nop before this to make sure that the comparator is
  // disabled.
  VARANUS_NOP;
  komodo_enable_all();
  //komodo_enable(0);
  //komodo_enable(1);
  //for (int i=0; i <4; i++) {
    VARANUS_NOP;
    //    test();
    VARANUS_NOP;
    VARANUS_NOP;
    //    test();
    VARANUS_NOP;
    //  }
  komodo_disable_all();
  //komodo_disable(0);
  //komodo_disable(1);
  // Enable the comparators and run 8 nops
  /*komodo_enable(0);
  komodo_enable(1);
  for (int i = 0; i < 4; i++) {
    
    first_nop:
    VARANUS_NOP;
    VARANUS_NOP;
    komodo_doorbell_check(&match_doorbell);
    }
  // Disable both comparators
  komodo_disable(0);
  komodo_disable(1);*/

  // One final nop that should be uncounted
  VARANUS_NOP;
  
  long rc0 = komodo_read_count(0);
  long rc1 = komodo_read_count(1);

  unsigned long wait_resp = 0;  
  return 0;
}
