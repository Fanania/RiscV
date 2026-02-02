`include "/home/fananiae/disertatie_Anania/src/defines.v"

// I'm adding this module to handle the Interrput/exceptions cases.
// In big lines this module should:
// 1) take the Hardware assert bus as an input and calsiffy the ERROR/WARNING
// 2) Take all 4 stages PC to correllate with the correct ERROR
//    -> The basic action that the processor must perform when an exception occurs is to save the address of the unfortunate
//       instruction in the supervisor exception cause register (SEPC) and then transfer control
//       to the operating system at some specified address.
// 3) Generates the interrupt cause which will be further stored in SCAUSE
//    -> The method used in the RISC-V architecture is to include a register (called the Supervisor Exception
//    -> Cause Register or SCAUSE), which holds a field that indicates the reason for the exception.
// Generates Flushes to not poluate the memory
// Generetes a signal which goes to IF to redirect the PC to  0000 0000 1C09 0000hex

module TRAP_INTER (
  output reg                      Interrupt,
  output reg [`PC_WIDTH   -1:0]   SEPC,
  output reg [31:0]               SCAUSE,
  output reg [`DATA_WIDTH -1:0]   STVAL,
  input      [`HWA_WIDTH  -1:0]   Hwa,      // Hardware asserts collected from all the stages
  input      [`PC_WIDTH   -1:0]   IF_Pc,
  input      [`PC_WIDTH   -1:0]   ID_Pc,
  input      [`PC_WIDTH   -1:0]   EXE_Pc,
  input      [`PC_WIDTH   -1:0]   MEM_Pc
  );

  localparam [31:0] CAUSE_INST_ADDR_MISALIGN = 32'd0;
  localparam [31:0] CAUSE_ILLEGAL_INSTR      = 32'd2;
  localparam [31:0] CAUSE_LOAD_ADDR_MISALIGN = 32'd4;
  localparam [31:0] CAUSE_LOAD_ACCESS_FAULT  = 32'd5;

  localparam integer HWA_JUMP_UNAL_BIT = `HWA_INVLD_FCT7 - 1;  // Decode-stage jump/branch alignment issue.

  reg [`PC_WIDTH-1:0]   next_sepc;
  reg [31:0]            next_scause;
  reg [`DATA_WIDTH-1:0] next_stval;
  reg                   trap_detected;

  always @* begin
    trap_detected = 1'b0;
    next_sepc     = {`PC_WIDTH{1'b0}};
    next_scause   = {32{1'b0}};
    next_stval    = {`DATA_WIDTH{1'b0}};

    if (|Hwa[`HWA_WIDTH-1:0]) begin
      trap_detected = 1'b1;

      if (Hwa[`HWA_INVLD_OP] | Hwa[`HWA_INVLD_FCT3] | Hwa[`HWA_INVLD_FCT7]) begin
        next_scause = CAUSE_ILLEGAL_INSTR;
        next_sepc   = ID_Pc;
        next_stval  = ID_Pc; // TODO: capture offending instruction word once routed here.
      end else if (Hwa[HWA_JUMP_UNAL_BIT]) begin
        next_scause = CAUSE_INST_ADDR_MISALIGN;
        next_sepc   = ID_Pc;
        next_stval  = ID_Pc;
      end else if (|Hwa[`HWA_EXE_RANGE]) begin
        next_scause = CAUSE_LOAD_ACCESS_FAULT; // Address calculator produced an out-of-range value.
        next_sepc   = EXE_Pc;
        next_stval  = EXE_Pc;
      end else if (|Hwa[`HWA_MEM_RANGE]) begin
        next_scause = CAUSE_LOAD_ADDR_MISALIGN; // Applies for both load/store misalign; refine once type is exposed.
        next_sepc   = MEM_Pc;
        next_stval  = MEM_Pc;
      end else if (Hwa[`HWA_HU_RANGE]) begin
        next_scause = CAUSE_ILLEGAL_INSTR;
        next_sepc   = EXE_Pc;
        next_stval  = EXE_Pc;
      end else if (|Hwa[`HWA_IF_RANGE]) begin
        next_scause = CAUSE_ILLEGAL_INSTR;
        next_sepc   = IF_Pc;
        next_stval  = IF_Pc;
      end else begin
        next_scause = CAUSE_ILLEGAL_INSTR;
        next_sepc   = ID_Pc;
        next_stval  = ID_Pc;
      end
    end
  end

  always @* begin
    Interrupt = trap_detected;
    SEPC      = next_sepc;
    SCAUSE    = next_scause;
    STVAL     = next_stval;
  end
endmodule
