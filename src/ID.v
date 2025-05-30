/*Range   31   30 : 25   24 : 21   20   19 : 15   14 : 12   11 : 8   7   6 : 0 
R-type  |    funct7    |      rs2     |   rs1   |  funct3 |      rd    | opcode |
I-type  |            Imm[11:0]        |   rs1   |  funct3 |      rd    | opcode |
S-type  |   Imm[11:5]  |      rs2     |   rs1   |  funct3 |  Imm[4:0]  | opcode |
B-type  |   | Imm[10:5]|      rs2     |   rs1   |  funct3 |Imm[4:1] |  | opcode |
U-type  |                         Imm[31:12]              |      rd    | opcode |
J-type  |   |        Imm[10:1]     |  |     Imm[19:12]    |      rd    | opcode |
*/

`include "/home/fananiae/disertatie_Anania/src/REG32x32.v"
`include "/home/fananiae/disertatie_Anania/src/defines.v"

module CU (
  output        [`CU_WIDTH-1:0] CU_Cmd,
  output reg                    CU_AluSrc,            // To Sign Extender logic
  output reg              [3:0] CU_AluControl,        // To ALU module
  output reg              [3:0] CU_LoadStoreCtrl,     // To LoadStore module
  output reg                    CU_UnsignedFlag,
  output reg                    CU_RegWrite,          // Floped with the instr processing and then used to enable Reg File writes
  output reg                    CU_MemWriteEn,        // Used as write enable in data memory 
  output reg              [1:0] CU_ResultSrc,         // Selector on wb mux
  output reg                    CU_Jump,              // jal writes PC+4 to rd and changes PC to the jump target address, PC + imm.
  output reg                    CU_Branch,            // Branch flag.

  input [`INSTR_TYPE_WIDTH-1:0] InstrType,
  input                         AddUpperItoPc,
  input                         Funct7Zero,
  input                         Funct7NonZero,
  input         [`FUNCT3_RANGE] InstrIn
  );

  reg [`CMD_WIDTH-1:0]Cmd;
  reg [`CMD_WIDTH-1:0]CmdDec;
  reg                 I_Instr;
  reg                 R_Instr;
  reg                 U_Instr;
  reg                 S_Instr;
  reg                 J_Instr;
  reg                 B_Instr;
  reg                 L_Instr;  

  always @* begin
   // Some Alu Commands have same Funct3 encoding
    R_Instr   = (InstrType[`INSTR_TYPE_WIDTH-1:0] == `R_INSTR);
    I_Instr   = (InstrType[`INSTR_TYPE_WIDTH-1:0] == `I_INSTR);
    B_Instr   = (InstrType[`INSTR_TYPE_WIDTH-1:0] == `B_INSTR);
    S_Instr   = (InstrType[`INSTR_TYPE_WIDTH-1:0] == `S_INSTR);
    U_Instr   = (InstrType[`INSTR_TYPE_WIDTH-1:0] == `U_INSTR);
    J_Instr   = (InstrType[`INSTR_TYPE_WIDTH-1:0] == `J_INSTR);
    L_Instr   = (InstrType[`INSTR_TYPE_WIDTH-1:0] == `L_INSTR);    

    case (InstrIn[`FUNCT3_RANGE])
      // Use Control Fields to decode funct7,funct3,opcode
      // Add ovl here. Default operation is NOP
      3'b000  : CmdDec[`CMD_WIDTH-1:0] = `CMD_ADD  & {`CMD_WIDTH{(Funct7Zero   & R_Instr) | I_Instr}} // Same Funct3 encoding across R and I intr types
                                       | `CMD_SUB  & {`CMD_WIDTH{Funct7NonZero & R_Instr}}            // Only in R type
                                       | `CMD_LB   & {`CMD_WIDTH{L_Instr}}                            // Load byte-> techincally an I type but marked as a subcategory
                                       | `CMD_SB   & {`CMD_WIDTH{S_Instr}}
                                       | `CMD_BEQ  & {`CMD_WIDTH{B_Instr}}
                                       ;
      3'b001  : CmdDec[`CMD_WIDTH-1:0] = `CMD_SLL  & {`CMD_WIDTH{Funct7Zero    & (R_Instr | I_Instr)}}
                                       | `CMD_LH   & {`CMD_WIDTH{L_Instr}}                            // Load byte-> techincally an I type but marked as a subcategory
                                       | `CMD_SH   & {`CMD_WIDTH{S_Instr}}
                                       | `CMD_BNE  & {`CMD_WIDTH{B_Instr}}
                                       ;
      3'b010  : CmdDec[`CMD_WIDTH-1:0] = `CMD_SLT  & {`CMD_WIDTH{(Funct7Zero   & R_Instr) | I_Instr}}
                                       | `CMD_LW   & {`CMD_WIDTH{L_Instr}}                            // Load byte-> techincally an I type but marked as a subcategory
                                       | `CMD_SW   & {`CMD_WIDTH{S_Instr}}
                                       ;
      3'b011  : CmdDec[`CMD_WIDTH-1:0] = `CMD_SLTU & {`CMD_WIDTH{Funct7Zero    & (R_Instr | I_Instr)}};
      3'b100  : CmdDec[`CMD_WIDTH-1:0] = `CMD_XOR  & {`CMD_WIDTH{(Funct7Zero   & R_Instr) | I_Instr}}
                                       | `CMD_LBU  & {`CMD_WIDTH{L_Instr}}                            // Load byte-> techincally an I type but marked as a subcategory 
                                       | `CMD_BLT  & {`CMD_WIDTH{B_Instr}}                                    
                                       ;
      3'b101  : CmdDec[`CMD_WIDTH-1:0] = `CMD_SRL  & {`CMD_WIDTH{Funct7Zero    & (R_Instr | I_Instr)}}
                                       | `CMD_SRA  & {`CMD_WIDTH{Funct7NonZero & (R_Instr | I_Instr)}}
                                       | `CMD_LHU  & {`CMD_WIDTH{L_Instr}}                            // Load byte-> techincally an I type but marked as a subcategory                                     
                                       | `CMD_BGE  & {`CMD_WIDTH{B_Instr}}
                                       ;
      3'b110  : CmdDec[`CMD_WIDTH-1:0] = `CMD_OR   & {`CMD_WIDTH{(Funct7Zero   & R_Instr) | I_Instr}}
                                       | `CMD_BLTU & {`CMD_WIDTH{B_Instr}}      
                                       ;
      3'b111  : CmdDec[`CMD_WIDTH-1:0] = `CMD_AND  & {`CMD_WIDTH{(Funct7Zero   & R_Instr) | I_Instr}}
                                       | `CMD_BGEU & {`CMD_WIDTH{B_Instr}}
                                       ;
      default : CmdDec[`CMD_WIDTH-1:0] = `CMD_NOP;
    endcase
    // Above are covered almost all commands
    // U instr do not use funct3 
    if (U_Instr) begin
      Cmd[`CMD_WIDTH-1:0] = `CMD_ADD & {`CMD_WIDTH{AddUpperItoPc}};
    end else begin
      Cmd[`CMD_WIDTH-1:0] = CmdDec[`CMD_WIDTH-1:0];
    end

    // Should control de SrcB entry in ALU. If 0 expect RD2 from reg file otherwise go with Imm.
    CU_AluSrc = I_Instr | U_Instr | L_Instr | S_Instr;    // Instr types which expects Imm

    // Control reg file write back policy. All instructions which stores data in rd will write in reg file R-Type/J-Type/I-Type (non store).
    // Branch and Store instr do not activate the Write back flag.
    CU_RegWrite  = ~(S_Instr | B_Instr)
                 &  |CmdDec[`CMD_WIDTH-1:0]    // not an NOP
                 ;
    CU_LoadStoreCtrl[3:0] = {(S_Instr | L_Instr), CmdDec[2:0]};
    // on Result src the rd writing that is decided.
    // 00 take the ALu result (specific to arithmetic instructs.)
    // 01 take the memory output 
    // 10 take the PC incremented value
    // 11 Reserved
    CU_ResultSrc [1:0] = {J_Instr,L_Instr}; //00 when is non L/J value and just takes the 01/10 values based on the L/J opcodes
    // Excpet to write in data memory only for store commands
    CU_MemWriteEn = S_Instr;
    CU_Jump       = J_Instr;
    CU_Branch     = B_Instr;
  end
  // Most decoded comamnds will need simple ALU op.
  always @* begin
    case (CmdDec[`CMD_WIDTH-1:0])
      `CMD_ADD,
      `CMD_LW,
      `CMD_SW,
      `CMD_SB,
      `CMD_LB,
      `CMD_SH,
      `CMD_LH   : begin
                     CU_AluControl[3:0] = `ALU_ADD;   // Add define for 3U_AluControl
                     CU_UnsignedFlag    = 1'b0;
                  end
      `CMD_LHU,      
      `CMD_LBU  : begin
                     CU_AluControl[3:0] = `ALU_ADD;   // Add define for CU_AluControl
                     CU_UnsignedFlag    = 1'b1;                     
                  end
      `CMD_SUB  : begin
                    CU_AluControl[3:0] = `ALU_SUB;
                    CU_UnsignedFlag    = 1'b0;                                         
                  end
      `CMD_BEQ  : begin
                    CU_AluControl[3:0] = `ALU_BEQ;
                    CU_UnsignedFlag    = 1'b0;                                         
                  end
      `CMD_BNE  : begin
                    CU_AluControl[3:0] = `ALU_BNE;
                    CU_UnsignedFlag    = 1'b0;                                         
                  end
      `CMD_BGE  : begin
                    CU_AluControl[3:0] = `ALU_BGE;
                    CU_UnsignedFlag    = 1'b0;                                         
                  end
      `CMD_AND  : begin
                    CU_AluControl[3:0] = `ALU_AND;    // Add define for CU_AluControl
                    CU_UnsignedFlag    = 1'b0;                                         
                  end
      `CMD_OR   : begin
                    CU_AluControl[3:0] = `ALU_OR;     // Add define for CU_AluControl
                    CU_UnsignedFlag    = 1'b0;                                         
                  end
      `CMD_XOR  : begin 
                    CU_AluControl[3:0] = `ALU_XOR;    // Add define for CU_AluControl
                    CU_UnsignedFlag    = 1'b0;                     
                  end
      `CMD_SLT,
      `CMD_BLT  : begin 
                    CU_AluControl[3:0] = `ALU_SLT;    // Add define for CU_AluControl
                    CU_UnsignedFlag    = 1'b0;                     
                  end
      `CMD_SLTU,
      `CMD_BLTU : begin 
                    CU_AluControl[3:0] = `ALU_SLT;    // Add define for CU_AluControl
                    CU_UnsignedFlag    = 1'b1;                     
                  end
      default   :  {CU_AluControl[3:0],CU_UnsignedFlag} = {`ALU_NOP,1'b0};
    endcase
  end

  assign CU_Cmd[`CMD_WIDTH-1:0] = Cmd[`CMD_WIDTH-1:0];
endmodule

module DECODE_INSTR (
  output     [`DATA_WIDTH-1:0] ID_Rd1,                       // Regfile outputs
  output     [`DATA_WIDTH-1:0] ID_Rd2,
  output reg   [`PC_WIDTH-1:0] ID_Pc,                        // Program Counter (flopped version of IF_Pc)
  output reg [`DATA_WIDTH-1:0] ID_ImmExt,                    // 32 bit sign extended Imm 
  output reg                   ID_AluSrc,                    // Sel for the srcB mux in Alu
  output reg             [3:0] ID_AluControl,                // ALU controller
  output reg                   ID_RegWrite,
  output reg                   ID_MemWriteEn,                // 
  output reg                   ID_Jump,
  output reg             [3:0] ID_LoadStoreCtrl,             // Load and Store control signal
  output reg   [`ADDR_IDX-1:0] ID_Rdest,                     // here we are writing the result
  output reg             [1:0] ID_ResultSrc,                 // Control the WB mux
  output reg                   ID_Branch,
  output reg                   ID_UnsignedFlag,              // Unsigned Flag
  output reg   [`ADDR_IDX-1:0] ID_Rs1,                       // Corresponding reg addr for ID_Rd1
  output reg   [`ADDR_IDX-1:0] ID_Rs2,                       // Corresponding reg addr for ID_Rd2

  input     [`INSTR_WIDTH-1:0] IF_Instr,                     // switched out to in
  input        [`PC_WIDTH-1:0] IF_Pc,
  input                        FlushD,    
  input                        WB_WriteEn,                   // BOZO wire this up and add the originating stage in front of it
  input      [`DATA_WIDTH-1:0] WB_Result,
  input        [`ADDR_IDX-1:0] Wr_Addr,
  input                        clk,
  input                        rst
  );
 
  wire                        ClkEn;
  wire                        CU_RegWrite;
  wire                  [1:0] CU_ResultSrc;
  wire      [`DATA_WIDTH-1:0] RegOut1_d0;
  wire      [`DATA_WIDTH-1:0] RegOut2_d0;
  wire                        ALUSrcE_d0;
  wire       [`CMD_WIDTH-1:0] Cmd_d0;
  wire                        CU_Jump;
  wire                        CU_Branch;
  wire                  [3:0] CU_AluControl;
  wire                  [3:0] CU_LoadStoreCtrl;
  reg        [`CMD_WIDTH-1:0] Cmd_d1;
  reg       [`DATA_WIDTH-1:0] ImmExt;
  reg       [`DATA_WIDTH-1:0] RegOut1_d1;
  reg       [`DATA_WIDTH-1:0] RegOut2_d1;
  reg [`INSTR_TYPE_WIDTH-1:0] InstrType;
  reg                         Funct7Zero;
  reg                         Funct7NonZero;
  reg                         AddUpperItoPc;
  reg                         SignImm;
  reg                         Imm_shft; // 0-> slli; 1-> srli; 2 ->srai
  reg      [`DATA_WIDTH-1:0] I_Type_Imm;
  reg      [`DATA_WIDTH-1:0] U_Type_Imm;
  reg      [`DATA_WIDTH-1:0] S_Type_Imm;
  reg      [`DATA_WIDTH-1:0] J_Type_Imm;  
  reg      [`DATA_WIDTH-1:0] B_Type_Imm;
  reg                        CU_AluSrc;
  
  assign ClkEn                    = 1'b1;   // Set it unconditionally to 1 for now
  // The register file is written by every instruction except sw. 
  // In the pipelined processor, the register file is used twice in every cycle: 
  // - written in the first part of a cycle 
  // - read in the 2nd part of the cycle in the second part
  REG32x32 Regfile_inst (
  .DataOutReg1          (RegOut1_d0),
  .DataOutReg2          (RegOut2_d0),
  .clk                  (~clk),
  .rst                  (rst),
  .write_enable         (WB_WriteEn),
  .wr_addr              (Wr_Addr),
  .data_in              (WB_Result),
  .r_addr1              (IF_Instr[`RS1_RANGE]),
  .r_addr2              (IF_Instr[`RS2_RANGE]) 
  );

  always @* begin
  // Decoding Instruction area  
    InstrType[`INSTR_TYPE_WIDTH-1:0] = (`R_INSTR &   {`INSTR_TYPE_WIDTH{IF_Instr[`OPCODE_RANGE] == `OP_ARITM_R     }})    // opcode is matching the R encoding
                                     | (`L_INSTR &   {`INSTR_TYPE_WIDTH{IF_Instr[`OPCODE_RANGE] == `OP_LOAD_IMM    }})    // load is techincally an I type but I'm segregating in it's own type
                                     | (`I_INSTR & (({`INSTR_TYPE_WIDTH{IF_Instr[`OPCODE_RANGE] == `OP_ARITM_IMM   }})
                                                  | ({`INSTR_TYPE_WIDTH{IF_Instr[`OPCODE_RANGE] == `OP_JUMP_LINK_I }})))  // BOZO not sure if shuold be added on j type
                                     | (`J_INSTR &   {`INSTR_TYPE_WIDTH{IF_Instr[`OPCODE_RANGE] == `OP_JUMP_LINK_J }})    // opcode is matching the J encoding
                                     | (`S_INSTR &   {`INSTR_TYPE_WIDTH{IF_Instr[`OPCODE_RANGE] == `OP_STORE_IMM   }})    // opcode is matching the S encoding
                                     | (`U_INSTR & (({`INSTR_TYPE_WIDTH{IF_Instr[`OPCODE_RANGE] == `OP_ADD_UPPER_I }})    // opcode is matching the U encoding
                                                  | ({`INSTR_TYPE_WIDTH{IF_Instr[`OPCODE_RANGE] == `OP_LOAD_UPPER_I}})))  // opcode is matching one of 2 expected I types opcodes
                                     | (`B_INSTR &   {`INSTR_TYPE_WIDTH{IF_Instr[`OPCODE_RANGE] == `OP_BRANCH      }})    // opcode is matching the B encoding
                                     ;                                                                                        // NOP will be assigned be default
  // Some I type instructions are using only uimm: 5-bit unsigned immediate in imm4:0. Segregating the legacy Imm[11:0] field in two sides : funct7[11:5] and Imm[4:0]
  // R type instructions uses funct7 but have only 2 values 7'b0 and 7'b0100000
    Funct7Zero    = ~|IF_Instr[`FUNCT7_RANGE];                // All 7 bits are zeroed
    Funct7NonZero = IF_Instr[`FUNCT7_RANGE] == 7'b0100000;
    AddUpperItoPc = IF_Instr[`OPCODE_RANGE]==`OP_ADD_UPPER_I;
  end

  CU ControlUnit_inst (
  .CU_Cmd             (Cmd_d0[`CMD_WIDTH-1:0]),
  .CU_AluSrc          (CU_AluSrc),
  .CU_AluControl      (CU_AluControl[3:0]),
  .CU_ResultSrc       (CU_ResultSrc[1:0]),
  .CU_LoadStoreCtrl   (CU_LoadStoreCtrl[3:0]),
  .CU_UnsignedFlag    (UnsignedFlag_d0),               // Not sure if it really matter
  .CU_RegWrite        (CU_RegWrite),
  .CU_MemWriteEn      (CU_MemWriteEn),
  .CU_Jump            (CU_Jump),
  .CU_Branch          (CU_Branch),  
  .InstrType          (InstrType[`INSTR_TYPE_WIDTH-1:0]),
  .AddUpperItoPc      (AddUpperItoPc),
  .Funct7Zero         (Funct7Zero),
  .Funct7NonZero      (Funct7NonZero),
  .InstrIn            (IF_Instr[`FUNCT3_RANGE])
  );

  always @* begin
    // bit 31 represents the sign bit and [30:20] would be the actual Imm value
    SignImm  = IF_Instr[`IMM_MSB];                  // Imm 31st bit is consider the sign bit 
    // For these shift instructions, imm4:0 is the 5-bit unsigned shift amount; 
    // The upper seven imm bits are 0 for srli and slli, but srai puts a 1 in imm10 (i.e., instruction bit 30)
    Imm_shft = ((Cmd_d0[`CMD_WIDTH-1:0] == `CMD_SLL)
             |  (Cmd_d0[`CMD_WIDTH-1:0] == `CMD_SRA) 
             |  (Cmd_d0[`CMD_WIDTH-1:0] == `CMD_SRL))
             &  (IF_Instr[`OPCODE_RANGE] == `OP_ARITM_IMM)  // shift commands
             ;
    // LUI (Load Upper Immediate) used to construct 32 bits constants :
    // - U-type.
    // - Uses first 20 bits for  Imm (msb).
    // - last 12 bits are setted to 0.
    // RO note: "Pare ca pentru U sau UJ shifteaza IMM la stanga cu 12 pozitii nu s sigur"
    I_Type_Imm[`DATA_WIDTH-1:0] = (Imm_shft) ? {{(`INSTR_WIDTH-`IMM_SHAMT_WIDTH){1'b0}},IF_Instr[`IMM_SHAMT_RANGE]}     // slli/srli
                                             : {{20{SignImm}},IF_Instr[`IMM_RANGE]}                                     // Valid for classic Imm instructions except immediate shift instructions (slli, srli, and srai) 
                                             ;
    U_Type_Imm[`DATA_WIDTH-1:0] = {IF_Instr[`UIMM_RANGE],12'b0};                                                        // Load upper 20 bits in RD. fill less 12 bits with 0
    // Store instructions use S-type and branch instructions use B-type.
    // S- and B-type formats differ only in how the immediate is encoded.
    // S-type instructions encode a 12-bit signed (twos complement) immediate, with the top seven bits (imm11:5) in bits 31:25 of the instr
    S_Type_Imm[`DATA_WIDTH-1:0] = {{20{SignImm}},{IF_Instr[`S_B_IMMHI_RANGE],IF_Instr[`S_B_IMMLO_RANGE]}};              // {31:25,11:7}
    // B-type instructions encode a 13-bit signed immediate representing the branch offset, but only 12 of the bits are encoded in the instruction
    B_Type_Imm[`DATA_WIDTH-1:0] = {{11{SignImm}},IF_Instr[7],IF_Instr[30:25],IF_Instr[11:8],1'b0};                      // Here I'm not using define to have better visibility on the bits ranges
    J_Type_Imm[`DATA_WIDTH-1:0] = {{11{SignImm}},IF_Instr[19:12],IF_Instr[11],IF_Instr[30:21],1'b0};                    // Here I'm not using define to have better visibility on the bits ranges

    case (InstrType[`INSTR_TYPE_WIDTH-1:0])
      `I_INSTR,
      `L_INSTR  : ImmExt[`DATA_WIDTH-1:0] = I_Type_Imm[`DATA_WIDTH-1:0];                                                // on I+L formats expect same Imm format
      `U_INSTR  : ImmExt[`DATA_WIDTH-1:0] = U_Type_Imm[`DATA_WIDTH-1:0];                                                // Upper shifted value
      `B_INSTR  : ImmExt[`DATA_WIDTH-1:0] = B_Type_Imm[`DATA_WIDTH-1:0];                                                // Upper shifted value
      `S_INSTR  : ImmExt[`DATA_WIDTH-1:0] = S_Type_Imm[`DATA_WIDTH-1:0];                                                      
      `J_INSTR  : ImmExt[`DATA_WIDTH-1:0] = J_Type_Imm[`DATA_WIDTH-1:0];                                                // BOZO make sure that the right J cmds are here
       default  : ImmExt[`DATA_WIDTH-1:0] = `DATA_WIDTH'h0;                                                             // For R formats
    endcase
  end

  always @(posedge clk) begin
    if (rst | FlushD) begin
      RegOut1_d1     [`DATA_WIDTH-1:0] <= `DATA_WIDTH'h0;
      RegOut2_d1     [`DATA_WIDTH-1:0] <= `DATA_WIDTH'h0;
      ID_Pc            [`PC_WIDTH-1:0] <= `PC_WIDTH'h0;
      ID_ImmExt      [`DATA_WIDTH-1:0] <= `DATA_WIDTH'h0;   
      ID_AluSrc                        <= 1'b0;
      ID_AluControl              [3:0] <= 3'b0;
      ID_RegWrite                      <= 1'b0;
      ID_MemWriteEn                    <= 1'b0;
      ID_LoadStoreCtrl           [3:0] <= 4'b0;
      ID_Rdest         [`ADDR_IDX-1:0] <= `ADDR_IDX'h0;
      ID_ResultSrc               [1:0] <= 2'b0;      
      ID_Jump                          <= 1'b0;
      ID_Branch                        <= 1'b0;
      ID_UnsignedFlag                  <= 1'b0;
      ID_Rs1           [`ADDR_IDX-1:0] <= `ADDR_IDX'h0;
      ID_Rs2           [`ADDR_IDX-1:0] <= `ADDR_IDX'h0;
    end else if (ClkEn) begin
      RegOut1_d1     [`DATA_WIDTH-1:0] <= RegOut1_d0      [`DATA_WIDTH-1:0];
      RegOut2_d1     [`DATA_WIDTH-1:0] <= RegOut2_d0      [`DATA_WIDTH-1:0];
      ID_Pc            [`PC_WIDTH-1:0] <= IF_Pc           [`PC_WIDTH  -1:0];
      ID_ImmExt      [`DATA_WIDTH-1:0] <= ImmExt          [`DATA_WIDTH-1:0];
      ID_AluSrc                        <= CU_AluSrc;
      ID_AluControl              [3:0] <= CU_AluControl               [3:0];
      ID_RegWrite                      <= CU_RegWrite; 
      ID_MemWriteEn                    <= CU_MemWriteEn;   
      ID_LoadStoreCtrl           [3:0] <= CU_LoadStoreCtrl            [3:0];   
      ID_Rdest         [`ADDR_IDX-1:0] <= IF_Instr             [ `RD_RANGE];    
      ID_ResultSrc               [1:0] <= CU_ResultSrc                [1:0];
      ID_Jump                          <= CU_Jump;
      ID_Branch                        <= CU_Branch;
      ID_UnsignedFlag                  <= UnsignedFlag_d0;
      ID_Rs1           [`ADDR_IDX-1:0] <= IF_Instr             [`RS1_RANGE];
      ID_Rs2           [`ADDR_IDX-1:0] <= IF_Instr             [`RS2_RANGE];
    end else begin
      RegOut1_d1     [`DATA_WIDTH-1:0] <= RegOut1_d1      [`DATA_WIDTH-1:0];
      RegOut2_d1     [`DATA_WIDTH-1:0] <= RegOut2_d1      [`DATA_WIDTH-1:0];
      ID_Pc            [`PC_WIDTH-1:0] <= ID_Pc             [`PC_WIDTH-1:0];
      ID_ImmExt      [`DATA_WIDTH-1:0] <= ID_ImmExt       [`DATA_WIDTH-1:0];
      ID_AluSrc                        <= ID_AluSrc;
      ID_AluControl              [3:0] <= ID_AluControl               [3:0];    
      ID_RegWrite                      <= ID_RegWrite;     
      ID_MemWriteEn                    <= ID_MemWriteEn;
      ID_LoadStoreCtrl           [3:0] <= ID_LoadStoreCtrl            [3:0];   
      ID_Rdest         [`ADDR_IDX-1:0] <= ID_Rdest          [`ADDR_IDX-1:0];
      ID_ResultSrc               [1:0] <= ID_ResultSrc                [1:0];
      ID_Jump                          <= ID_Jump;
      ID_Branch                        <= ID_Branch;
      ID_UnsignedFlag                  <= ID_UnsignedFlag;      
      ID_Rs1           [`ADDR_IDX-1:0] <= ID_Rs1           [`ADDR_IDX-1:0];
      ID_Rs2           [`ADDR_IDX-1:0] <= ID_Rs2           [`ADDR_IDX-1:0];      
    end
  end

  assign ID_Rd1        [`DATA_WIDTH-1:0] = RegOut1_d1     [`DATA_WIDTH-1:0];
  assign ID_Rd2        [`DATA_WIDTH-1:0] = RegOut2_d1     [`DATA_WIDTH-1:0];
endmodule
