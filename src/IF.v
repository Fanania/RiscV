
   // This module implements a simple branch predictor based on a 4-state finite state machine,
   // as described in *Computer Organization and Design: The Hardware/Software Interface (RISC-V Edition)*.
   // 
   // In a basic processor without branch prediction, the control logic fetches and decodes instructions sequentially,
   // even after a branch instruction. If the branch is later determined to be taken, subsequent instructions are flushed.
   // While simple, this "go with the flow" strategy can be inefficient, especially for branch-heavy workloads,
   // as it leads to pipeline flushes and wasted cycles.
   //
   // To improve performance, this module introduces a dynamic branch prediction mechanism,
   // allowing the processor to speculatively execute based on predicted branch outcomes.
   // 
   // Note: Consider reviewing whether this predictor logic should be placed in the Instruction Decode (ID) stage,
   // as suggested in the textbook, for potentially better timing and integration.
   //
   // TODO: Evaluate and tune prediction accuracy and placement for optimal pipeline efficiency.

module BRANCH_PREDICTOR (
  output reg [`PC_WIDTH-1:0] Pc_out,           // Strong taken/ Weak taken/ Strong Not taken/ Weak Not taken
  output                     BPB_Hwa,          // Hardware assert triggered if an reserved value is being hit on EXE_MissPredict
  output                     Miss,             // Misspredicted -> Flush the pipeline
  input                      BranchTaken,      // Use The branch decison to control the FSM.
  input                      WrEn,             // Update the State Machine only on Branch decoded instructions
  input                      RdEn,             // Update the State Machine only on Branch decoded instructions
  input      [`PC_WIDTH-1:0] Fetched_Pc,       // Curent PC
  input      [`PC_WIDTH-1:0] ID_Pc,            // Use to update the BPB when there are branch instr 
  input      [`PC_WIDTH-1:0] EXE_PcTgt,        // Exe calculated PC.
  input                      clk,
  input                      rst
);
  reg  [1:0] StateUp;
  wire [1:0] State;                            // Strong taken/ Weak taken/ Strong Not taken/ Weak Not taken
  wire [1:0] DfltState;                        
  reg        PosPred;                          // Positive prediction
  reg  [1:0] EXE_MissPredict;                  // Missprediction detected when the branch is in EXE:
                                               // 01 -> Miss predicted that an branch condition is met
                                               // 10 -> Miss predicted that an branch condition will not be met
                                               // 00 -> Rightfull predicted
                                               // 11 -> Reserved

  always @* begin
    if (BranchTaken) begin                     // If the Branch is Taken update the state 
      if (&State[1:0]) begin                   // ..if already in Strong Taken (2'b11) 
        StateUp[1:0] = State[1:0];             // ..keep the state 
      end else begin                           // Otherwise increment 
        StateUp[1:0] = State[1:0] + 2'b01;     // .. from SNT->WNT; WNT-> WT; WT->ST
      end
    end else begin                             // If the Branch is not Taken update the state
      if (|State[1:0]) begin                   // ..if not in Strong Not Taken (2'b00) 
        StateUp[1:0] = State[1:0] - 2'b01;     // Decrement the State ST->WT; WT->WNT WNT->SNT
      end else begin                           // Otherwise if in SNT
        StateUp[1:0] = State[1:0];             // ..keep the state
      end
    end
  end

  // Branch Prediction Buffer 
  // Implementing a buffer to store the states of every decoded branch.
  // based on the state; the next fetched instr will be the branch calculated pc if predicted as taken or PC+4 if not predicted as taken
  reg  [`BPB_WIDTH-1:0] BPB [`INSTR_DEPTH-1:0];                                   // reg array 
  
  always @(posedge clk) begin
    if (rst) begin
      for (int i=0; i<`INSTR_DEPTH; i=i+1) begin
        BPB[i][`BPS_RANGE] <= `BRANCH_ST_DEFAULT;                                 // Go to default. for now is weak taken
                                                                                  // I think that the default state can be different based on the programmed executed
        BPB[i][`BPT_RANGE] <= `BPT_WIDTH'h0;
      end
    end else if (WrEn) begin
      BPB[ID_Pc[`PC_WIDTH-1:2]][`BPS_RANGE] <= StateUp[1:0];                      // update only on branches
      BPB[ID_Pc[`PC_WIDTH-1:2]][`BPT_RANGE] <= EXE_PcTgt[`PC_WIDTH-1:0];          // update only on branches
    end
  end
                                                                                  // Used only to update the buffer state
  assign State[1:0] = BPB[ID_Pc[`PC_WIDTH-1:2]][`BPS_RANGE];                      // Read the current state of the buffer entry
  always @* begin                                                                 // Read the buffer stored prediction state
      PosPred = RdEn & 
              & (2'b10 <= BPB[Fetched_Pc[`PC_WIDTH-1:2]][`BPS_RANGE])             // Positive Prediction == 2'b1x
              ;
    if (WrEn) begin                                                               // Assert the Positive prediction indicator only if the prev instr is branch
      // An missprediction can't be identify until EXE Stage.
      // When identified... the pipeline is flushed and the adecvate instr is fetched
      EXE_MissPredict[0] = ~BranchTaken &  State[1];                              // Wrongly assumed that the Branch was ok
      EXE_MissPredict[1] =  BranchTaken & ~State[1];                              // Wrongly assumed that the Branch was not ok
    end else begin
      EXE_MissPredict[1:0] = 2'b0;
    end

    if (EXE_MissPredict[0]) begin                                                 // When "Branch taken" missprediction is detected ..
      Pc_out[`PC_WIDTH-1:0] = ID_Pc[`PC_WIDTH-1:0] + `PC_INCR;                    // Use the Branch PC from EXE and increment with 4
    end else if (EXE_MissPredict[1]) begin                                        // When "Branch not taken" missprediction is detected ..
      Pc_out[`PC_WIDTH-1:0] = EXE_PcTgt[`PC_WIDTH-1:0];                           // Use the calculated Branch target 
    end else begin
      if (PosPred) begin                                                          // Use the Predictor if not blocked by any misspredicted instr
        Pc_out[`PC_WIDTH-1:0] = BPB[Fetched_Pc[`PC_WIDTH-1:2]][`BPT_RANGE];
      end else begin
        Pc_out[`PC_WIDTH-1:0] = Fetched_Pc[`PC_WIDTH-1:0] + `PC_INCR;
      end
    end
  end
  assign Miss    = |EXE_MissPredict[1:0];                                         // Misspredictions are completly normal
  assign BPB_Hwa = &EXE_MissPredict[1:0];                                         // expected values for EXE_MissPredict  = 01 if wrongly assumed that the branch is taken    
                                                                                  //                                      = 10 if wrongly assumed that the branch is not taken
                                                                                  //                                     != 11 Unexpected -> HWA
  genvar i;
  generate
    for (i = 0; i < `INSTR_DEPTH; i = i + 1) begin : expose_bpb
      wire [`BPS_RANGE] BPS_debug = BPB[i][`BPS_RANGE];
      wire [`BPT_RANGE] BPT_debug = BPB[i][`BPT_RANGE];      
    end
  endgenerate

endmodule

module FETCH_INSTR (
  output reg [`INSTR_WIDTH-1:0] IF_Instr,                                         // Raw instruction
  output        [`PC_WIDTH-1:0] IF_Pc,                                            // Program Counter
  output    [`HWA_IF_WIDTH-1:0] IF_Hwa,
  output                        BpbMiss,                                          // Flush if mispredicted
  output        [`PC_WIDTH-1:0] ProgramCounter_d0,                                // ProgramCounter_d0 used to read the instruction
  input      [`INSTR_WIDTH-1:0] FetchedInstr,                                     // Instruction wich is aligned with ProgramCounter_d1
  input                         ID_Branch,                                        // Jump or Branch
  input         [`PC_WIDTH-1:0] ID_Pc,                                            // Use to update the BPB when there are branch instr   
  input                         EXE_PcSrc,                                        // Control Signal which dictate what PC should be used
  input         [`PC_WIDTH-1:0] EXE_PcTgt,                                        // Branched PC
  input                         CountStall,                                       // Stop the Fetch stage: no PC update + stall pipeline
  input                         Flush,
  input                         clk,
  input                         rst
);
  wire [`PC_WIDTH   -1:0] BranchedPc;
  reg  [`PC_WIDTH   -1:0] ProgramCounter_d1;
  reg  ActiveInstr_d0;
  reg  ActiveInstr;
  reg rst_d1;
  wire ClkEn;
  wire IF_Branch;

  assign ClkEn     = ~CountStall;              // BOZO add more here
  assign IF_Branch = IF_Instr[`OPCODE_RANGE] == `OP_BRANCH;
 `ifdef BPB_ENABLE  
  BRANCH_PREDICTOR Bpb_inst (
  .Pc_out                   (BranchedPc),
  .BPB_Hwa                  (BPB_Hwa),
  .BranchTaken              (EXE_PcSrc),                                          // Used a sel for the PC mux. should be asserted pon Branch/Jump instructions
  .Miss                     (BpbMiss),
  .WrEn                     (ID_Branch),
  .RdEn                     (IF_Branch),
  .Fetched_Pc               (ProgramCounter_d1),
  .ID_Pc                    (ID_Pc),
  .EXE_PcTgt                (EXE_PcTgt),
  .clk                      (clk),
  .rst                      (rst)
  );
 
  assign ProgramCounter_d0[`PC_WIDTH-1:0] = EXE_PcSrc & ~ID_Branch ? EXE_PcTgt[`PC_WIDTH-1:0]        // Jump
                                                                   : BranchedPc[`PC_WIDTH-1:0] & {`PC_WIDTH{~rst_d1}}      // Or Branch or simple incremenatation
                                                                   ;

 `else
  assign BPB_Hwa = 1'b0;
  // If Pc Source from EXE is asserted take the Jump/branch value
  assign ProgramCounter_d0[`PC_WIDTH-1:0] = EXE_PcSrc ? EXE_PcTgt[`PC_WIDTH-1:0]                      // Load the calculated Jump/Branch PC
                                                      : ProgramCounter_d1[`PC_WIDTH-1:0] + `PC_INCR   // Increment by 4
                                                      ;

 `endif
  // Program Counter incrementation
  always @* begin
    ActiveInstr                = ActiveInstr_d0 & ~Flush;                          // Count if Stall if Hazard Unit don't trigger an Stall

    IF_Instr[`INSTR_WIDTH-1:0] = FetchedInstr[`INSTR_WIDTH-1:0] 
                               & {`INSTR_WIDTH{ActiveInstr}}
                               ;    
  end

  always @(posedge clk) begin
    if (rst) begin
      rst_d1                           <= rst;        
    end else if (ClkEn) begin
      rst_d1                           <= rst;  
    end else begin
      rst_d1                           <= rst_d1;        
    end
  end

  always @(posedge clk) begin
    if (rst /*| Flush*/) begin
      ProgramCounter_d1[`PC_WIDTH-1:0] <= `PC_WIDTH'h0;            
      ActiveInstr_d0                   <= 1'b0;
    end else if (ClkEn) begin
      ProgramCounter_d1[`PC_WIDTH-1:0] <= ProgramCounter_d0[`PC_WIDTH-1:0];       
      ActiveInstr_d0                   <= 1'b1;
    end else begin
      ProgramCounter_d1[`PC_WIDTH-1:0] <= ProgramCounter_d1[`PC_WIDTH-1:0];             
      ActiveInstr_d0                   <= 1'b0;            
    end
  end

  assign IF_Pc  [`PC_WIDTH   -1:0] = ProgramCounter_d1[`PC_WIDTH-1:0]
                                   & {`PC_WIDTH{~Flush}}
                                   ;

  assign IF_Hwa[`HWA_ID_WIDTH-1:0] = {                                             // Add new entries on top
                                      7'h0,                                        // Reserved bits
                                      BPB_Hwa                                      // Missprediction reserved bit on BPB module
                                     }
                                   ;
endmodule
