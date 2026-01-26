// Instruction Memory, momentaly declared as an Latch array, it's values will be programmed through the testbench
`include "/home/fananiae/disertatie_Anania/src/defines.v"

module IMEM (
  output reg [`INSTR_WIDTH-1:0] InstrData,   // BOZO switch from Data into Instr
  input                         clk,
  input         [`PC_WIDTH-1:0] ReadAddrIn,  // Wired to PC
  input                         load_done    // Asserted by TB when hex file is ready
);
  wire [`IMEM_IDX   -1:0] ReadAddrAlligned;
  reg  [`INSTR_WIDTH-1:0] InstrMemArr [`INSTR_DEPTH-1:0]; // BOZO add more "memory"

  // 4B allignment
  assign ReadAddrAlligned[`IMEM_IDX-1:0] = ReadAddrIn[2+`IMEM_IDX-1:2];

  always @(posedge clk) begin
    InstrData <= InstrMemArr[ReadAddrAlligned[`ADDR_IDX-1:0]][`INSTR_WIDTH-1:0];
  end

  initial begin
    // Static init of the instructions in the ROM happens after testbench signals readiness
    wait (load_done === 1'b1);
    #1 $readmemh("/home/fananiae/disertatie_Anania/tb/tests/test_general.hex", InstrMemArr);
  //  #1 $readmemh("/home/fananiae/disertatie_Anania/tb/tests/test_add.hex", InstrMemArr);

  end
 // DEBUG FLORIN BOZO Remove me 
  genvar i;
  generate
    for (i = 0; i < `INSTR_DEPTH; i = i + 1) begin : expose_instr_memory
      wire [`INSTR_WIDTH-1:0] InstrMemArr_debug = InstrMemArr[i][`INSTR_WIDTH-1:0];
    end
  endgenerate

 // end debug mode
endmodule

