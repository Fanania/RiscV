// Instruction Memory, momentaly declared as an Latch array, it's values will be programmed through the testbench

module IMEM (
  output reg [`INSTR_WIDTH-1:0] InstrData,   // BOZO switch from Data into Instr
  input                         clk,
  input         [`PC_WIDTH-1:0] ReadAddrIn   // Wired to PC 
);
  wire [`ADDR_IDX   -1:0] ReadAddrAlligned;
  reg  [`INSTR_WIDTH-1:0] InstrMemArr [`INSTR_WIDTH-1:0]; // BOZO add more "memory"

  // 4B allignment
  assign ReadAddrAlligned[`ADDR_IDX-1:0] = ReadAddrIn[`BYTES_ALLIGN_RANGE];

  always @(posedge clk) begin
    InstrData <= InstrMemArr[ReadAddrAlligned[`ADDR_IDX-1:0]][`INSTR_WIDTH-1:0];
  end

  initial begin
    // Static init of the instructions in the ROM
    $readmemh("/home/fananiae/disertatie_Anania/src/instr_mem_with_every_cmd.hex", InstrMemArr); 
  end
endmodule

module FETCH_INSTR (
  output reg [`INSTR_WIDTH-1:0] IF_Instr,       // Raw instruction
  output        [`PC_WIDTH-1:0] IF_Pc,          // Program Counter

  input                         EXE_PcSrc,      // Control Signal which dictate what PC should be used
  input         [`PC_WIDTH-1:0] EXE_PcTgt,      // Branched PC
  input                         HU_Stall,       // Stop the Fetch stage: no PC update + stall pipeline
  input                         clk,
  input                         rst
);
  reg  [`PC_WIDTH   -1:0] ProgramCounter_d0;
  reg  [`PC_WIDTH   -1:0] ProgramCounter_d1;
  reg  [`PC_WIDTH   -1:0] ProgramCounter_d2;    
  reg  [`PC_WIDTH   -1:0] PCNext;
  wire [`INSTR_WIDTH-1:0] FetchedInstr;
  reg  ActiveInstr_d0;
  reg  ActiveInstr;
  reg  CountStarted;
  wire ClkEn;
  //---- Used on Debug
  wire [`PC_WIDTH-1:0] ProgramCounter_4BALign_d1;
  wire [`PC_WIDTH-1:0] ProgramCounter_4BALign_d2;
  wire [`PC_WIDTH-1:0] ProgramCounter_4BALign_d0;

  assign ClkEn    = ~HU_Stall;              // BOZO add more here

  // Program Counter incrementation
  always @* begin
    PCNext         [`PC_WIDTH-1:0] = ProgramCounter_d1[`PC_WIDTH-1:0];       // Exit of the PC reg used to choose the instruction
    if (~HU_Stall) begin                                                     // Count if Stall if Hazard Unit don't trigger an Stall
      if (EXE_PcSrc) begin                                                   // If asserted take the Jump/branch value
        ProgramCounter_d0[`PC_WIDTH-1:0] = EXE_PcTgt[`PC_WIDTH-1:0];         // Load the calculated Jump/Branch PC
        CountStarted                     = 1'b1;                             // Flag used to show that the count is started
      end else begin
        ProgramCounter_d0[`PC_WIDTH-1:0] = PCNext[`PC_WIDTH-1:0] + `PC_INCR; // Increment by 4
        CountStarted                     = 1'b1;                             // Flag used to show that the count is started
      end
    end else begin
      ProgramCounter_d0[`PC_WIDTH-1:0] = PCNext[`PC_WIDTH-1:0];
      CountStarted                     = 1'b0;                               // The Flag is cleaned when Count_en deasserts & teher is no active stall
    end
    ActiveInstr                       = ActiveInstr_d0 & CountStarted;

    IF_Instr[`INSTR_WIDTH-1:0] = FetchedInstr[`INSTR_WIDTH-1:0] 
                               & {`INSTR_WIDTH{ActiveInstr}}
                               ;    
  end

  IMEM instMem_inst (
  .InstrData        (FetchedInstr),
  .clk              (clk),
  .ReadAddrIn       (PCNext)                                                 // BOZO check if this stage is okay to be used in instruction reading
  );
  
  always @(posedge clk) begin
    if (rst) begin
      ProgramCounter_d1[`PC_WIDTH   -1:0] <= `PC_WIDTH'h0;
      ProgramCounter_d2[`PC_WIDTH   -1:0] <= `PC_WIDTH'h0;      
      ActiveInstr_d0                      <= 1'b0;
    end else if (ClkEn) begin
      ProgramCounter_d1[`PC_WIDTH   -1:0] <= ProgramCounter_d0[`PC_WIDTH   -1:0]; 
      ProgramCounter_d2[`PC_WIDTH   -1:0] <= ProgramCounter_d1[`PC_WIDTH   -1:0];       
      ActiveInstr_d0                      <= 1'b1;
    end else begin
      ProgramCounter_d1[`PC_WIDTH   -1:0] <= ProgramCounter_d1[`PC_WIDTH   -1:0];
      ProgramCounter_d2[`PC_WIDTH   -1:0] <= ProgramCounter_d2[`PC_WIDTH   -1:0];             
      ActiveInstr_d0                      <= 1'b0;            
    end
  end

  assign IF_Pc   [`PC_WIDTH   -1:0] = ProgramCounter_d2[`PC_WIDTH   -1:0];

  //---- Used on Debug
  assign ProgramCounter_4BALign_d0[`PC_WIDTH-4:0] = {ProgramCounter_d0[`PC_WIDTH-1:7],ProgramCounter_d0[`BYTES_ALLIGN_RANGE]};
  assign ProgramCounter_4BALign_d1[`PC_WIDTH-4:0] = {ProgramCounter_d1[`PC_WIDTH-1:7],ProgramCounter_d1[`BYTES_ALLIGN_RANGE]};  
  assign ProgramCounter_4BALign_d2[`PC_WIDTH-4:0] = {ProgramCounter_d2[`PC_WIDTH-1:7],ProgramCounter_d2[`BYTES_ALLIGN_RANGE]};  


endmodule
