//----------------------------------------------------------------------
//                   Defines used on all files
//----------------------------------------------------------------------

`define ADDR_WIDTH          32
`define ADDR_IDX             5
`define INSTR_WIDTH         32
`define DATA_WIDTH          32
`define PC_WIDTH            32
`define CU_WIDTH             5
`define BYTES_NR             4
`define HWA_WIDTH           32

//----------------------------------------------------------------------
//                   Defines used Fetch stage
//----------------------------------------------------------------------
`define PC_INCR             4
`define INSTR_DEPTH        200
`define IMEM_IDX           $clog2(`INSTR_DEPTH)
`define BYTES_ALLIGN_RANGE 2+`IMEM_IDX-1:2
//----------------------------------------------------------------------
//                   Defines used Decode stage
//----------------------------------------------------------------------
// Instruction Encoding
`define FUNCT7_RANGE     31:25       // FUNCT7
`define RS2_RANGE        24:20       // Source register 2 range in R-type
`define RS1_RANGE        19:15       // Source register 1 range in R-type
`define FUNCT3_RANGE     14:12       // FUNCT3
`define FUNCT3_MSB          14
`define FUNCT3_LSB          12
`define RD_RANGE          11:7       // Destination register range in R-type
`define OPCODE_RANGE       6:0       // Opcode range
// IMM subfields
`define IMM_RANGE        31:20       // Imm
`define IMM_LSB             20       // Imm
`define IMM_MSB             31       // Imm
`define IMM_WIDTH           12       // Imm

`define IMM_SHAMT_RANGE  24:20       // 24:20 
`define IMM_SHAMT_WIDTH      5
// Upper Immediate subfields
`define UIMM_RANGE       31:12       // 20 Upper Imm bits
`define UIMM_WIDTH          20       // Imm
// Store/Branch immediate subfields
`define S_B_IMMHI_RANGE  31:25       // S/B-type replace funct7 with imm11:5 bits for store/branch
`define S_B_IMMLO_RANGE   11:7       // S/B-type replace rd with lower imm4:0 bits for store/branch

// ALU CONTROLLER
`define CMD_WIDTH            5
// Semanlele ce vor controla ALU
`define CMD_ADD           5'b00001   // ADDI & ADD
`define CMD_SUB           5'b00010
`define CMD_AND           5'b00011   // AND & ANDI 
`define CMD_JALR          5'b00100
`define CMD_OR            5'b00101
`define CMD_J             5'b00110
`define CMD_XOR           5'b00111
`define CMD_MULT          5'b01000  
`define CMD_SLL           5'b01001
`define CMD_SRA           5'b01010
`define CMD_SRL           5'b01011
`define CMD_SLT           5'b01100
`define CMD_SLTI          5'b01101
`define CMD_DIV           5'b01110
`define CMD_MHFI          5'b01111  // not sure it is a real inst. seems to be present only in mips
`define CMD_BLT           5'b10000
`define CMD_BEQ           5'b10001
`define CMD_BNE           5'b10010
`define CMD_BGE           5'b10011
`define CMD_BLTU          5'b10100
`define CMD_BGEU          5'b10101
`define CMD_SLTU          5'b10110
`define CMD_MFLO          5'b10111

`define CMD_LB            5'b11000
`define CMD_LH            5'b11001
`define CMD_LW            5'b11010
`define CMD_LBU           5'b11011
`define CMD_LHU           5'b11100

`define CMD_SB            5'b11101
`define CMD_SH            5'b11110
`define CMD_SW            5'b11111
`define CMD_NOP           5'b00000 // pentru NOP, BEZ, BNQ, JMP

// Alu Control
`define ALU_ADD           4'b0001  
`define ALU_NOP           4'b0000
`define ALU_AND           4'b0010 
`define ALU_OR            4'b0011 
`define ALU_XOR           4'b0100
`define ALU_SUB           4'b0101
`define ALU_SLL           4'b0110
`define ALU_SRA           4'b0111 // notr sure if needed ?????????
`define ALU_SRL           4'b1000 
`define ALU_SLT           4'b1001
`define ALU_BEQ           4'b1010
`define ALU_BGE           4'b1011
`define ALU_BNE           4'b1100

//----------------------------------------------------------------------
//                   OPCODE decoded
//----------------------------------------------------------------------
`define OP_LOAD_IMM       7'b0000011     // Load operations in rd with imm(rs1). dec=3
`define OP_ARITM_IMM      7'b0010011     // Arithmetic operations in rd with imm and rs1. dec=19
`define OP_ADD_UPPER_I    7'b0010111     // Add upper immediate to PC
`define OP_STORE_IMM      7'b0100011     // Store operations. dec=35
`define OP_ARITM_R        7'b0110011     // R-type operations : rd= rs1 op rs2. dec=51
`define OP_LOAD_UPPER_I   7'b0110111     // Load upper immediate. dec 55
`define OP_BRANCH         7'b1100011     // Branch. dec 99
`define OP_JUMP_LINK_I    7'b1100111     // Jump and link register. PC = rs1 + SignExt(imm), rd = PC + 4
`define OP_JUMP_LINK_J    7'b1101111     // Jump and link PC = JTA, rd = PC + 4

`define INSTR_TYPE_WIDTH  3              // Instruction Decoded Types
`define N_INSTR           3'b000         // NOP
`define R_INSTR           3'b001         // R INSTR
`define I_INSTR           3'b010         // I INSTR
`define U_INSTR           3'b011         // U INSTR
`define L_INSTR           3'b100         // L INSTR -> practically an I type instr
`define J_INSTR           3'b101         // J INSTR
`define S_INSTR           3'b110         // S INSTR
`define B_INSTR           3'b111         // B INSTR

//----------------------------------------------------------------------
//                   MEM stage defines
//----------------------------------------------------------------------
`define RAM_ALLIGN_RANGE 9:2
`define RAM_ADDR_MSB       9
`define DATA_MASK_BYTE     8
`define DATA_MASK_HALF    16

//----------------------------------------------------------------------
//                   WB stage defines
//----------------------------------------------------------------------
`define WB_ALU 0
`define WB_RAM 1
`define WB_PC  2

//----------------------------------------------------------------------
//                   Hazard Detection Unit defines
//----------------------------------------------------------------------
`define  FW_WIDTH 2        // Used as selector for Forwarded variants 
`define  WB       1        // Forward the data from wb stage 
`define  MEM      2        // Forward the data from mem stage 
`define  RSVD     3        // Rsvd. Illegal value for now
`define  NORMAL   0        // Normal behaviour. Just take the data from srcA and srcB 

//----------------------------------------------------------------------
//                   Hardware assert bus defines
//----------------------------------------------------------------------
// Priority encoding of the Interrupts

`define HWA_MSB                31
`define HWA_WIDTH              32 
`define HWA_ID_WIDTH            8  // ID and CU Interrupts
`define HWA_ID_RANGE        31:24
`define HWA_INVLD_OP     `HWA_MSB  // biggest priority
`define HWA_INVLD_FCT3 `HWA_MSB-1
`define HWA_INVLD_FCT7 `HWA_MSB-2
`define HWA_MEM_WIDTH           7  // MEM  Interrupts
`define HWA_MEM_RANGE       23:17
`define HWA_EXE_WIDTH           8 // EXE  Interrupts
`define HWA_EXE_RANGE        16:9
`define HWA_HU_WIDTH            1
`define HWA_HU_RANGE          8:8
`define HWA_IF_WIDTH            8
`define HWA_IF_RANGE          7:0
//----------------------------------------------------------------------
//                   Branch Predictor Defines
//----------------------------------------------------------------------
`define BPB_ENABLE          1                                      // Branch predictor enable
`define BRANCH_ST_DEFAULT   2'b01
`define BPS_WIDTH           2                                      // Branch Predictor State width
`define BPT_WIDTH          `PC_WIDTH                               // Branch Predictor Target width
`define BPB_WIDTH          `BPS_WIDTH  +`BPT_WIDTH                 // Branch Predictor Buffer width
`define BPS_RANGE          `BPB_WIDTH-1:`BPB_WIDTH-`BPS_WIDTH      // The state is in the upper 2 bits of the buffer
`define BPT_RANGE         (`BPB_WIDTH  -`BPS_WIDTH)-1:0            // The targeted pc (addr) 

//----------------------------------------------------------------------
//                   Used on simulation
//----------------------------------------------------------------------

`define SIMULATION_ON 1

//----------------------------------------------------------------------
//                   Variant Specific
//----------------------------------------------------------------------

`define VARIANT_RV32I_PRESENT 1    // Used to guard non- base rvi32 implementations
`define C_EXTENSION_ON        1    // Used to guard compressed instr extesion logic (like 2Byte alligned jumps)

