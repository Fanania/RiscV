`include "/home/fananiae/disertatie_Anania/src/defines.v"

 module DMEM (
   output reg [`DATA_WIDTH-1:0] DataOut,
  input                        clk,
  input                        MemWriteEn,
  input    [`ADDR_WIDTH  -1:0] Addr,
  input      [`DATA_WIDTH-1:0] DataIn
 );
   reg [31:0] data_mem [0:255];

  `ifdef SIMULATION_ON
     integer k;
     initial begin
       for (k=0; k<256; k=k+1) begin
         data_mem[k][`DATA_MASK_BYTE-1:0] <= k*10;
         data_mem[k][2*`DATA_MASK_BYTE-1:`DATA_MASK_BYTE] <= k*20;
         data_mem[k][3*`DATA_MASK_BYTE-1:2*`DATA_MASK_BYTE] <= k*30;
         data_mem[k][4*`DATA_MASK_BYTE-1:3*`DATA_MASK_BYTE] <= k*40;                           
       end
     end
   `endif

   always @(posedge clk) begin
     if (MemWriteEn) begin
       data_mem[Addr[`RAM_ALLIGN_RANGE]][`DATA_WIDTH-1:0] <= DataIn[`DATA_WIDTH-1:0];  // Aliniere pe 32b
     end
   end

   // Memory Read (combinational read to match previous behaviour)
   always @* begin
     DataOut[`DATA_WIDTH-1:0] = data_mem[Addr[`RAM_ALLIGN_RANGE]][`DATA_WIDTH-1:0];
   end

`ifdef SIMULATION_ON
  genvar i;
  generate
    for (i = 0; i < 32; i = i + 1) begin : expose_memory
      wire [31:0] data_mem_debug = data_mem[i][`DATA_WIDTH-1:0];
    end
  endgenerate
`endif
 endmodule
