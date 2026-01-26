`include "/home/fananiae/disertatie_Anania/src/defines.v"

module EXECUTE_INSTR (
  output reg [`DATA_WIDTH-1:0] EXE_AluResult,
  output reg                   EXE_Overflow,
  output reg   [`PC_WIDTH-1:0] EXE_Pc,
  output reg                   EXE_RegWrite,
  output reg                   EXE_MemWriteEn,
  output reg [`DATA_WIDTH-1:0] EXE_WriteData,
  output reg             [3:0] EXE_LoadStoreCtrl,             // Load And Store Signal just flopped version of the ID_LoadStoreCtrl
  output reg   [`ADDR_IDX-1:0] EXE_Rdest,                     // here we are writing the result
  output reg             [1:0] EXE_ResultSrc,                 // Control the WB mux (ID_ResultSrc flopped)
  output                       EXE_PcSrc,                     // Control the Pc mux in IF
  output       [`PC_WIDTH-1:0] EXE_PcTgt,                     // Branch/Jump calculated PC
  output reg                   EXE_UnsignedFlag,
  output  [`HWA_EXE_WIDTH-1:0] EXE_Hwa,

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
  input                        Flush,      
  input                  [3:0] ID_LoadStoreCtrl,
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
  reg  [`DATA_WIDTH     -1:0] SrcRawA;
  reg  [`DATA_WIDTH     -1:0] SrcRawB;  // Should contain the Imm value or Reg1 value based on the Instruction type
  reg  [`DATA_WIDTH     -1:0] Result[15:0];
  reg                         Overflow;
  reg                         IsAdd; 
  reg                         IsSub; 
  reg                         IsBgeOk;
  reg                         ZeroFlag;
  reg                         BranchOk;
  reg  [`DATA_WIDTH     -1:0] AluResult;
  wire                        ClkEn;
  wire                        Hwa;
  reg  [1:0]                  Sign;

  assign ClkEn                    = 1'b1;   // Set it unconditionally to 1 for now
  
  always @* begin
    IsAdd = ID_AluControl[3:0] == `ALU_ADD;
    IsSub = (ID_AluControl[3:0] == `ALU_SUB)
          | (ID_AluControl[3:0] == `ALU_BEQ)
          | (ID_AluControl[3:0] == `ALU_BNE)
          | (ID_AluControl[3:0] == `ALU_BGE)
          ;

    // Stage 1: SrcA is normally wired to Re0 output but in special cases can have different values like:
    // Stage 2: if there is a data hazard use the mem/eb data instead of exe data    
    case (HU_ForwardA[`FW_WIDTH-1:0])
      `NORMAL  : SrcA[`DATA_WIDTH-1:0] = ID_Rd1       [`DATA_WIDTH-1:0];
      `WB      : SrcA[`DATA_WIDTH-1:0] = WB_Result    [`DATA_WIDTH-1:0];
      `MEM     : SrcA[`DATA_WIDTH-1:0] = EXE_AluResult[`DATA_WIDTH-1:0];       // should use the EXE output instead
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
        `MEM     : SrcRawB[`DATA_WIDTH-1:0] = EXE_AluResult[`DATA_WIDTH-1:0];  // should use the EXE output instead
        default  : SrcRawB[`DATA_WIDTH-1:0] = ID_Rd2       [`DATA_WIDTH-1:0];  // Not sure if okay to use this one as default
      endcase
    end

    // The sub comannd is just add but with the 2nds term negated version
    SrcB   [`DATA_WIDTH-1:0] = (IsSub) ? ~SrcRawB[`DATA_WIDTH-1:0] + `DATA_WIDTH'h1  // use the 2's complement 
                                       :  SrcRawB[`DATA_WIDTH-1:0]
                                       ;
    Sign[1:0] = {2{~ID_UnsignedFlag}}        // when there is no unsigned flag 
              & {SrcA[31],SrcRawB[31]}       // ..use the msb to dictate the sign
              ;

    // SLL and SRL are basically same shifting operation. the operands need to be switched.
    
    AluResult[`DATA_WIDTH-1:0] = {`DATA_WIDTH{IsAdd | IsSub}}                    & (SrcA[`DATA_WIDTH-1:0] + SrcB[`DATA_WIDTH-1:0])
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_AND)}} & (SrcA[`DATA_WIDTH-1:0] & SrcB[`DATA_WIDTH-1:0])
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_OR )}} & (SrcA[`DATA_WIDTH-1:0] | SrcB[`DATA_WIDTH-1:0])
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_XOR)}} & (SrcA[`DATA_WIDTH-1:0] ^ SrcB[`DATA_WIDTH-1:0])
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_SLL)}} & (SrcA[`DATA_WIDTH-1:0] << SrcB[`DATA_WIDTH-1:0]) 
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_SRL)}} & (SrcA[`DATA_WIDTH-1:0] >> SrcB[`DATA_WIDTH-1:0])
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_SRA)}} & ((SrcA[`DATA_WIDTH-1:0] >> SrcB[`DATA_WIDTH-1:0])
                                                                                 | ({`DATA_WIDTH{SrcA[31]}} >> SrcB[`IMM_SHAMT_WIDTH-1:0]))
                               | {`DATA_WIDTH{(ID_AluControl[3:0] == `ALU_SLT)}} & ((SrcA[`DATA_WIDTH-1:0] < SrcB[`DATA_WIDTH-1:0])               // if the slt 
                                                                                 ^ (|Sign[1:0]))                                                  // Just rvert the slt result whenever there is a negative number in A or B
                               ;
    // Calculate Overflow. The only commands which can trigger Overflow it will be add and sub
    Overflow = (IsAdd | IsSub) & ~(SrcA[31] ^ SrcB[31]) & (SrcA[31] ^ AluResult[31]) 
       //      | (IsSub &  (SrcA[31] ^ SrcB[31]) & (SrcA[31] ^ AluResult[31]))
             ;
    IsBgeOk = ((ID_AluControl[3:0] == `ALU_BGE) // if bge
            & ~Overflow)                        // ..and not overflow that means the sub instr had an positive output
            `ifdef CMD_BGEU                     // ..and if BGEU defined use a xor to reverse the polarity if there are negative inputs
            ^ (|Sign[1:0])
            `endif
            ;
    ZeroFlag = ~|AluResult[`DATA_WIDTH-1:0];
    BranchOk =  (ID_AluControl[3:0] == `ALU_BEQ) &  ZeroFlag      // Expect to have zero if rs1==rs2
             |  (ID_AluControl[3:0] == `ALU_BNE) & ~ZeroFlag      // Non zero 
             |  (ID_AluControl[3:0] == `ALU_SLT) &  AluResult[0]  // 1 on lsb. BLT is processed as SLT
             |  (ID_AluControl[3:0] == `ALU_BGE) & ~Overflow      // if bge and not overflow that means the sub instr had an positive output
             ;
  end
  // In store cases; the actaul addr needs to be lower than the limits of the addr. 
  // For example sw x1 offset(x2);
  //   where: x1=x2=0; and the calculated offset is -32. that translates to 4 GB. Can't address this zone.
  assign Hwa = ID_LoadStoreCtrl[3]                        // Load store indicator
             & AluResult[`DATA_WIDTH-1:`RAM_ADDR_MSB+1]   // The resulting addr can't be bigger than the max addr. NO negative results
             ;
  assign EXE_Hwa[`HWA_EXE_WIDTH-1:0] = {                  // Add new entries on top
                                        7'h0,             // Reserved bits
                                        Hwa               // Mem Addr miscalculation.
                                       }
                                     ;
  always @(posedge clk) begin
    if (rst | Flush) begin
      EXE_AluResult[`DATA_WIDTH  -1:0] <= `DATA_WIDTH'h0;
      EXE_Overflow                     <= 1'b0;
      EXE_Pc       [`PC_WIDTH    -1:0] <= `PC_WIDTH'h0;
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
assign EXE_PcTgt[`PC_WIDTH-1:0] = ID_Pc[`PC_WIDTH-1:0] + ID_ImmIn[`PC_WIDTH-1:0];  // For Branches will add the 12 bit (extended) Imm and for J will add teh 20 bits (2 Bytes) Imm
endmodule
