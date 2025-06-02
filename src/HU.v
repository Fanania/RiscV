`include "/home/fananiae/disertatie_Anania/src/defines.v"

    // Hazards are classified as data hazards or control hazards.
    // A data hazard occurs when an instruction tries to read a register that has not yet been written back by a previous instruction. 
    // A control hazard occurs when the decision of what instruction to fetch next has not been madeby the time the fetch takes place
    // Some data hazards can be solved by forwarding a result from the Memory or Writeback stage to a dependent instruction in the Execute stage.
    // Another solution is to stall the pipeline, holding up operation until the data is available.
    // When a stage is stalled, all previous stages must also be stalled so that no subsequent instructions are lost. 
    // The pipeline register directly after the stalled stage must be cleared (flushed) to prevent bogusinformation from propagating forward. 
    // Stalls degrade performance, so they should be used only when necessary.

module HAZARD_UNIT (
  output reg [`FW_WIDTH-1:0] HU_ForwardA,   // used a selector for the mux which choose the srcA entry on ALU
  output reg [`FW_WIDTH-1:0] HU_ForwardB,   // used a selector for the mux which choose the srcB entry on ALU
  output reg                 HU_Stall,      // HU_Stall = StallF = StallD = FlushE
  output                     HU_Hwa,

  input [`ADDR_IDX-1:0] IF_Rs2,
  input [`ADDR_IDX-1:0] IF_Rs1,
  input [`ADDR_IDX-1:0] ID_Rs2,
  input [`ADDR_IDX-1:0] ID_Rs1,
  input [`ADDR_IDX-1:0] ID_Rdest, 
  input           [1:0] ID_ResultSrc, 
  input [`ADDR_IDX-1:0] EXE_Rdest,
  input                 ID_RegWrite,
  input                 EXE_RegWrite,      // Forward only if the mem instr tries to write back on reg file
  input                 MEM_RegWrite,      // Forward only if the wb instr tries to write back on reg file
  input [`ADDR_IDX-1:0] MEM_Rdest
  );

  reg FwdD2Rs1;
  reg FwdD2Rs2;
  reg FwdE2Rs1;
  reg FwdE2Rs2;
  reg FwdM2Rs1;
  reg FwdM2Rs2;

  always @* begin
  // The Hazard Unit should forward from a stage if that stage will write a destination register and the destination register matches the source register.
  // However, x0 is hardwired to 0 and should never be forwarded. If both the Memory and Writeback stages contain matching destination registers,
  // ..then the Memory stage should have priority because it contains the more recently executed instr.

    FwdM2Rs2 =  (ID_Rs2[`ADDR_IDX-1:0] == MEM_Rdest[`ADDR_IDX-1:0])  // Matchig reg addr
             & ~|ID_Rs2[`ADDR_IDX-1:0]                               // Non 0 value
             &   MEM_RegWrite                                        // Forward only if the data is suppose to be written in reg file
             ;
    FwdM2Rs1 =  (ID_Rs1[`ADDR_IDX-1:0] == MEM_Rdest[`ADDR_IDX-1:0])  // Matchig reg addr
             & ~|ID_Rs1[`ADDR_IDX-1:0]                               // Non 0 value
             &   MEM_RegWrite                                        // Forward only if the data is suppose to be written in reg file             
             ;
    FwdE2Rs2 =  (ID_Rs2[`ADDR_IDX-1:0] == EXE_Rdest[`ADDR_IDX-1:0])  // Matchig reg addr
             & ~|ID_Rs2[`ADDR_IDX-1:0]                               // Non 0 value
             &   EXE_RegWrite                                        // Forward only if the data is suppose to be written in reg file
             ;
    FwdE2Rs1 =  (ID_Rs1[`ADDR_IDX-1:0] == EXE_Rdest[`ADDR_IDX-1:0])  // Matchig reg addr
             & ~|ID_Rs1[`ADDR_IDX-1:0]                               // Non 0 value
             &   EXE_RegWrite                                        // Forward only if the data is suppose to be written in reg file               
             ;
    // For Stall logic
    FwdD2Rs2 =  (IF_Rs2[`ADDR_IDX-1:0] == ID_Rdest[`ADDR_IDX-1:0])   // Matchig reg addr
             & ~|IF_Rs2[`ADDR_IDX-1:0]                               // Non 0 value
             &   ID_RegWrite                                         // Forward only if the data is suppose to be written in reg file
             ;
    FwdD2Rs1 =  (IF_Rs1[`ADDR_IDX-1:0] == ID_Rdest[`ADDR_IDX-1:0])   // Matchig reg addr
             & ~|IF_Rs1[`ADDR_IDX-1:0]                               // Non 0 value
             &   ID_RegWrite                                         // Forward only if the data is suppose to be written in reg file
             ;

    if (FwdE2Rs1) begin                                              // Rd will be written by an instruction from MEM stage
      HU_ForwardA[`FW_WIDTH-1:0] = `MEM;                             // take the data from the MEM stage (flopped Exe signal)
    end else if (FwdM2Rs1)  begin                                    // Rd will be written by an instruction from WB stage
      HU_ForwardA[`FW_WIDTH-1:0] = `WB;                              // take the data from the WB stage (flopped Mem signal)
    end else begin
      HU_ForwardA[`FW_WIDTH-1:0] = `NORMAL;                          // Normal behav -> take the data from the EXE stage (flopped Id signal)
    end
  
    if (FwdE2Rs2) begin                                              // Rd will be written by an instruction from MEM stage
      HU_ForwardB[`FW_WIDTH-1:0] = `MEM;                             // take the data from the MEM stage (flopped Exe signal)
    end else if (FwdM2Rs2)  begin                                    // Rd will be written by an instruction from WB stage
      HU_ForwardB[`FW_WIDTH-1:0] = `WB;                              // take the data from the WB stage (flopped Mem signal)
    end else begin
      HU_ForwardB[`FW_WIDTH-1:0] = `NORMAL;                          // Normal behav -> take the data from the EXE stage (flopped Id signal)
    end 
  end

  // In order for the Hazard Unit to stall the pipeline, the following conditions must be met:
  // 1. load in Execute stage
  // 2. Reg destination  == Decode Reg source1/2

  // Stalls are supported by adding enable inputs (EN) to the Fetch and Decode pipeline registers and a synchronous clear (CLR) input to the Execute pipeline register.
  // When a load stall occurs, BOZO and BOZO are asserted to force the Decode and Fetch stage pipeline registers to retain their existing values. 
  // BOZO is also asserted to clear the contents of the Execute stage pipeline register, introducing a bubble.
  always @* begin
    HU_Stall = ID_ResultSrc[0]         // the lsb is asserted only for load cmds
             & (FwdD2Rs2 | FwdD2Rs1)   // Hazard detected 
             ;
  end

  assign HU_Hwa = ((HU_ForwardA[`FW_WIDTH-1:0] == `RSVD)               // Trigger hwa if rsvd value is somehow generated
                 | (HU_ForwardB[`FW_WIDTH-1:0] == `RSVD))
                &  (EXE_RegWrite | MEM_RegWrite)
                ;
endmodule
