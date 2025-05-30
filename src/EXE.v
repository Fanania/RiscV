`include "/home/fananiae/disertatie_Anania/src/defines.v"

module EXECUTE_INSTR (
  output reg [`DATA_WIDTH-1:0] EXE_AluResult,
  output reg                   EXE_Overflow,
  output reg   [`PC_WIDTH-1:0] EXE_Pc,
  output reg                   EXE_ZeroFlag,
  output reg                   EXE_RegWrite,
  output reg                   EXE_MemWriteEn,
  output reg [`DATA_WIDTH-1:0] EXE_WriteData,
  output reg             [3:0] EXE_LoadStoreCtrl,             // Load And Store Signal just flopped version of the ID_LoadStoreCtrl
  output reg   [`ADDR_IDX-1:0] EXE_Rdest,                     // here we are writing the result
  output reg             [1:0] EXE_ResultSrc,                 // Control the WB mux (ID_ResultSrc flopped)
  output                       EXE_PcSrc,                     // Control the Pc mux in IF
  output       [`PC_WIDTH-1:0] EXE_PcTgt,                     // Branch/Jump calculated PC
  output reg                   EXE_UnsignedFlag,

  input                        ID_UnsignedFlag,
  input        [`PC_WIDTH-1:0] ID_Pc,
  input      [`DATA_WIDTH-1:0] ID_ImmIn,
  input      [`DATA_WIDTH-1:0] ID_Rd1,                        // Regfile outputs
  input      [`DATA_WIDTH-1:0] ID_Rd2,
  input                        ID_AluSrc,
  input                  [3:0] ID_AluControl,
  input                        ID_RegWrite,
  input                        ID_MemWriteEn,
  input                        ID_Jump,
  input                        ID_Branch,
  input                  [3:0] ID_LoadStoreCtrl,
  input      [`DATA_WIDTH-1:0] MEM_ALUResult,                 // Used as alu input if there is mem.rd == exe.rs situation 
  input      [`DATA_WIDTH-1:0] WB_Result,                     // Used as alu input if there is wb.rd == exe.rs situation 
  input        [`ADDR_IDX-1:0] ID_Rdest,                      // here we are writing the result
  input                  [1:0] ID_ResultSrc,                  // Control the WB mux
  input        [`FW_WIDTH-1:0] HU_ForwardA,                   // 00 -> Normal Behav; 01 -> fwd mem data
  input        [`FW_WIDTH-1:0] HU_ForwardB,                   // ..10 -> fwd wb data; 11 -> reserved
  input                        clk,
  input                        rst
  );
  
  reg  [`DATA_WIDTH     -1:0] SrcA;
  reg  [`DATA_WIDTH     -1:0] SrcB;
  reg  [`DATA_WIDTH     -1:0] SrcRawB;  // Should contain the Imm value or Reg1 value based on the Instruction type
  reg  [`DATA_WIDTH     -1:0] Result[15:0];
  reg                         Overflow;
  reg                         IsAdd; 
  reg                         IsSub; 
  reg                         IsBge;
  reg                         ZeroFlag;
  reg                         BranchOk;
  reg  [`DATA_WIDTH     -1:0] AluResult;
  wire                        ClkEn;

  assign ClkEn                    = 1'b1;   // Set it unconditionally to 1 for now
  
  always @* begin
    IsAdd = ID_AluControl[3:0] == `ALU_ADD;
    IsSub = (ID_AluControl[3:0] == `ALU_SUB)
          | (ID_AluControl[3:0] == `ALU_BEQ)
          | (ID_AluControl[3:0] == `ALU_BNE)
          | (ID_AluControl[3:0] == `ALU_BGE)
          ;

    case (HU_ForwardA[`FW_WIDTH-1:0])
      `NORMAL  : SrcA[`DATA_WIDTH-1:0] = ID_Rd1       [`DATA_WIDTH-1:0];
      `WB      : SrcA[`DATA_WIDTH-1:0] = WB_Result    [`DATA_WIDTH-1:0];
      `MEM     : SrcA[`DATA_WIDTH-1:0] = MEM_ALUResult[`DATA_WIDTH-1:0];
      default  : SrcA[`DATA_WIDTH-1:0] = ID_Rd1       [`DATA_WIDTH-1:0];       // Not sure if okay to use this one as default
    endcase

    // Stage 1: SrcB could be either an extended Imm or the direct Reg1 output
    // Stage 2: if there is a data hazard use the mem/eb data instead of exe data
    // Stage 3: If the operation is an SUB then SrcB need to be transformds in it's 2's complement value

    if (ID_AluSrc) begin                                                       // Based on the Control Unit signal drive the ALU SrcB
       SrcRawB[`DATA_WIDTH-1:0] = ID_ImmIn[`DATA_WIDTH-1:0];                   // Choose between Expended Imm
    end else begin
      case (HU_ForwardB[`FW_WIDTH-1:0])
        `NORMAL  : SrcRawB[`DATA_WIDTH-1:0] = ID_Rd2       [`DATA_WIDTH-1:0];
        `WB      : SrcRawB[`DATA_WIDTH-1:0] = WB_Result    [`DATA_WIDTH-1:0];
        `MEM     : SrcRawB[`DATA_WIDTH-1:0] = MEM_ALUResult[`DATA_WIDTH-1:0];
        default  : SrcRawB[`DATA_WIDTH-1:0] = ID_Rd2       [`DATA_WIDTH-1:0];  // Not sure if okay to use this one as default
      endcase
    end

    // The sub comannd is just add but with the 2nds term negated version
    SrcB   [`DATA_WIDTH-1:0] = (IsSub) ? ~SrcRawB[`DATA_WIDTH-1:0] + `DATA_WIDTH'h1  // use the 2's complement 
                                       :  SrcRawB[`DATA_WIDTH-1:0]
                                       ;
    // Stage 1: SrcA is normally wired to Re0 output but in special cases can have different values like:
    // SLL and SRL are basically same shifting operation. the operands need to be switched.
  
    // Trying not to use any combinational priority:
    Result[`ALU_ADD][`DATA_WIDTH-1:0] =  SrcA[`DATA_WIDTH-1:0] + SrcB[`DATA_WIDTH-1:0];
    Result[`ALU_AND][`DATA_WIDTH-1:0] =  SrcA[`DATA_WIDTH-1:0] & SrcB[`DATA_WIDTH-1:0];
    Result[`ALU_OR ][`DATA_WIDTH-1:0] =  SrcA[`DATA_WIDTH-1:0] | SrcB[`DATA_WIDTH-1:0];
    Result[`ALU_XOR][`DATA_WIDTH-1:0] =  SrcA[`DATA_WIDTH-1:0] ^ SrcB[`DATA_WIDTH-1:0];
  //  Result[`ALU_SUB][`DATA_WIDTH-1:0] =  SrcA[`DATA_WIDTH-1:0] + SrcB[`DATA_WIDTH-1:0]; // BOZO look above
    Result[`ALU_SLL][`DATA_WIDTH-1:0] =  SrcA[`DATA_WIDTH-1:0] << SrcB[`DATA_WIDTH-1:0];
    Result[`ALU_SRL][`DATA_WIDTH-1:0] =  SrcA[`DATA_WIDTH-1:0] >> SrcB[`DATA_WIDTH-1:0];  
    Result[`ALU_SRA][`DATA_WIDTH-1:0] = (SrcA[`DATA_WIDTH-1:0] >> SrcB[`IMM_SHAMT_WIDTH-1:0]) // could be combine with the above one
                                      | ({`DATA_WIDTH{SrcA[31]}} >> SrcB[`IMM_SHAMT_WIDTH-1:0])
                                      ;
    Result[`ALU_SLT][`DATA_WIDTH-1:0] =  SrcA[`DATA_WIDTH-1:0] < SrcB[`DATA_WIDTH-1:0];

    Result[`ALU_NOP][`DATA_WIDTH-1:0] =  `DATA_WIDTH'h0;
  
    AluResult[`DATA_WIDTH-1:0] = {`DATA_WIDTH{IsAdd}}                            & Result[`ALU_ADD][`DATA_WIDTH-1:0]
                               | {`DATA_WIDTH{IsSub}}                            & Result[`ALU_ADD][`DATA_WIDTH-1:0]  
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_AND)}} & Result[`ALU_AND][`DATA_WIDTH-1:0]
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_OR )}} & Result[`ALU_OR ][`DATA_WIDTH-1:0]
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_XOR)}} & Result[`ALU_XOR][`DATA_WIDTH-1:0]
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_SLL)}} & Result[`ALU_SLL][`DATA_WIDTH-1:0]
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_SRL)}} & Result[`ALU_SRL][`DATA_WIDTH-1:0]
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_SRA)}} & Result[`ALU_SRA][`DATA_WIDTH-1:0]
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_SLT)}} & Result[`ALU_SLT][`DATA_WIDTH-1:0]
                               ;
    // Calculate Overflow. The only commands which can trigger Overflow it will be add and sub
    Overflow = (IsAdd & ~(SrcA[31] ^ SrcB[31]) & (SrcA[31] ^ AluResult[31])) 
             | (IsSub &  (SrcA[31] ^ SrcB[31]) & (SrcA[31] ^ AluResult[31]))
             ;

    ZeroFlag = ~|AluResult[`DATA_WIDTH-1:0];
    BranchOk =  (ID_AluControl[3:0] == `ALU_BEQ) &  ZeroFlag      // Expect to have zero if rs1==rs2
             |  (ID_AluControl[3:0] == `ALU_BNE) & ~ZeroFlag      // Non zero 
             |  (ID_AluControl[3:0] == `ALU_SLT) &  AluResult[0]  // 1 on lsb. BLT is processed as SLT
             |  (ID_AluControl[3:0] == `ALU_BGE) & ~Overflow      // if bge and not overflow taht means that the sub instr had an positive output
             ;
  end

  always @(posedge clk) begin
    if (rst) begin
      EXE_AluResult[`DATA_WIDTH  -1:0] <= `DATA_WIDTH'h0;
      EXE_Overflow                     <= 1'b0;
      EXE_Pc       [`PC_WIDTH    -1:0] <= `PC_WIDTH'h0;
      EXE_ZeroFlag                     <= 1'b0;
      EXE_RegWrite                     <= 1'b0;
      EXE_MemWriteEn                   <= 1'b0;
      EXE_WriteData[`DATA_WIDTH  -1:0] <= `DATA_WIDTH'h0; 
      EXE_Rdest        [`ADDR_IDX-1:0] <= `ADDR_IDX'h0;
      EXE_ResultSrc              [1:0] <= 2'b0;
      EXE_LoadStoreCtrl          [3:0] <= 4'b0;
      EXE_UnsignedFlag                 <= 1'b0;
    end else if (ClkEn) begin
      EXE_AluResult[`DATA_WIDTH  -1:0] <= AluResult[`DATA_WIDTH-1:0];
      EXE_Overflow                     <= Overflow;
      EXE_Pc       [`PC_WIDTH    -1:0] <= ID_Pc[`PC_WIDTH-1:0];
      EXE_ZeroFlag                     <= ZeroFlag;   
      EXE_RegWrite                     <= ID_RegWrite;
      EXE_MemWriteEn                   <= ID_MemWriteEn;
      EXE_WriteData[`DATA_WIDTH  -1:0] <= ID_Rd2[`DATA_WIDTH-1:0];
      EXE_Rdest        [`ADDR_IDX-1:0] <= ID_Rdest     [`ADDR_IDX-1:0];
      EXE_ResultSrc              [1:0] <= ID_ResultSrc           [1:0]; 
      EXE_LoadStoreCtrl          [3:0] <= ID_LoadStoreCtrl       [3:0];
      EXE_UnsignedFlag                 <= ID_UnsignedFlag;
    end else begin
      EXE_AluResult[`DATA_WIDTH  -1:0] <= EXE_AluResult[`DATA_WIDTH-1:0];
      EXE_Overflow                     <= EXE_Overflow;
      EXE_Pc       [`PC_WIDTH    -1:0] <= EXE_Pc[`PC_WIDTH-1:0];
      EXE_ZeroFlag                     <= EXE_ZeroFlag;
      EXE_RegWrite                     <= EXE_RegWrite;
      EXE_MemWriteEn                   <= EXE_MemWriteEn;
      EXE_WriteData[`DATA_WIDTH  -1:0] <= EXE_WriteData[`DATA_WIDTH-1:0];
      EXE_Rdest        [`ADDR_IDX-1:0] <= EXE_Rdest     [`ADDR_IDX-1:0];
      EXE_ResultSrc              [1:0] <= EXE_ResultSrc           [1:0];
      EXE_LoadStoreCtrl          [3:0] <= EXE_LoadStoreCtrl       [3:0];
      EXE_UnsignedFlag                 <= EXE_UnsignedFlag;
    end
  end

assign EXE_PcSrc = ID_Jump | (ID_Branch & BranchOk);
assign EXE_PcTgt[`PC_WIDTH-1:0] = ID_Pc[`PC_WIDTH-1:0] + ID_ImmIn[`PC_WIDTH-1:0];
endmodule
