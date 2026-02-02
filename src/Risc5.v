`include "/home/fananiae/disertatie_Anania/src/defines.v"

module RISC_V (
  input clk,
  input rst,
  input imem_load_done
);

  wire [`INSTR_WIDTH -1:0] FetchedInstr;
  wire [`PC_WIDTH    -1:0] ReadAddrInstrMem;
  wire [`DATA_WIDTH  -1:0] RdData;
  wire [`DATA_WIDTH  -1:0] DataMasked;
  wire                     EXE_MemWriteEn;
  wire [`DATA_WIDTH  -1:0] EXE_AluResult;
  wire                     Flush;
  CPU cpu           (
  .ReadAddrInstrMem (ReadAddrInstrMem),
  .EXE_AluResult    (EXE_AluResult),
  .DataMasked       (DataMasked),
  .EXE_MemWriteEn   (EXE_MemWriteEn), 
  .Flush            (Flush),
  .clk              (clk),
  .rst              (rst),
  .FetchedInstr     (FetchedInstr),
  .RdData           (RdData)
  );

  IMEM InstMem_inst (
  .InstrData        (FetchedInstr),
  .RdEn             (~Flush),
  .clk              (clk),
  .ReadAddrIn       (ReadAddrInstrMem),                                           // BOZO check if this stage is okay to be used in instruction reading
  .load_done        (imem_load_done)
  );

  DMEM DataMem_inst (
  .DataOut          (RdData),
  .clk              (clk),
  .MemWriteEn       (EXE_MemWriteEn),
  .Addr             (EXE_AluResult),
  .DataIn           (DataMasked)
  );
endmodule
