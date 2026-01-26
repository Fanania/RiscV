`include "/home/fananiae/disertatie_Anania/src/defines.v"

module REG32x32 #(parameter ADDR_WIDTH = 32) (
  output [`DATA_WIDTH-1:0] DataOutReg1,
  output [`DATA_WIDTH-1:0] DataOutReg2,

  input clk,
  input rst,
  input write_enable,
  input [`ADDR_IDX  -1:0] wr_addr,
  input [`DATA_WIDTH-1:0] data_in,
  input [`ADDR_IDX  -1:0] r_addr1,
  input [`ADDR_IDX  -1:0] r_addr2
  );
  
  integer k,j;
  reg [`DATA_WIDTH-1:0] Reg_Cell [`ADDR_WIDTH-1:0];
`ifdef SIMULATION_ON
  initial begin
    for (k=0; k<`ADDR_WIDTH; k=k+1) begin
      Reg_Cell[k][`DATA_WIDTH-1:0] <= k;
    end
      Reg_Cell[6][`DATA_WIDTH-1:0] <= {{(`DATA_WIDTH-2){1'b0}},2'b10};
      Reg_Cell[5][`DATA_WIDTH-1:0] <= {{(`DATA_WIDTH-2){1'b1}},2'b10};      
  end
`endif
  always @(posedge clk) begin 
   if (rst) begin
       for (k=0; k<`ADDR_WIDTH; k=k+1) begin
         Reg_Cell[k][`DATA_WIDTH-1:0] <= {`ADDR_WIDTH{1'h0}};
       end
    end else if (write_enable) begin
      // Se foloseste campul de adresa preluat din pachet pentru a determina unde se va peterce scrierea
      Reg_Cell[wr_addr[`ADDR_IDX-1:0]][`DATA_WIDTH-1:0] <= data_in[`DATA_WIDTH-1:0];
    end else begin
      // daca nu avem scriere sau rerset se pastreaza ultima valoare
      Reg_Cell[wr_addr[`ADDR_IDX-1:0]][`DATA_WIDTH-1:0] <= Reg_Cell[wr_addr[`ADDR_IDX-1:0]][`DATA_WIDTH-1:0];
    end 
  end
   // Register 0 should be hardwired to 0 BOZO
    assign DataOutReg1[`DATA_WIDTH-1:0]=Reg_Cell[r_addr1[`ADDR_IDX-1:0]][`DATA_WIDTH-1:0];
    assign DataOutReg2[`DATA_WIDTH-1:0]=Reg_Cell[r_addr2[`ADDR_IDX-1:0]][`DATA_WIDTH-1:0];
 // DEBUG FLORIN BOZO Remove me 
  genvar i;
  generate
    for (i = 0; i < 32; i = i + 1) begin : expose_regfile
      wire [31:0] RegCell_debug = Reg_Cell[i][`DATA_WIDTH-1:0];
    end
  endgenerate

 // end debug mode
endmodule
