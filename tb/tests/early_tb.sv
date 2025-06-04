
// top_tb.sv - Fisier principal al testbench-ului
`timescale 1ns / 1ps
`define CLOCK_PERIOD 10
// Total simulation cycles
 `define SIM_CYCLES (5000 * `CLOCK_PERIOD)
// `define ADDR_WIDTH 32
// `define DATA_WIDTH 32
// Includerea fisierelor UVM necesare
//`include "/home/fananiae/disertatie_Anania/src/REG32x32.v"
`include "/home/fananiae/disertatie_Anania/tb/interfaces/risc5_if.sv"
`include "/home/fananiae/disertatie_Anania/src/defines.v"
`include "/home/fananiae/disertatie_Anania/src/IF.v"
`include "/home/fananiae/disertatie_Anania/src/ID.v"
`include "/home/fananiae/disertatie_Anania/src/EXE.v"
`include "/home/fananiae/disertatie_Anania/src/MEM.v"

`include "/home/fananiae/disertatie_Anania/src/Risc5.v"
`include "/home/fananiae/disertatie_Anania/src/HU.v"

//`include "/home/fananiae/disertatie_Anania/tb/agents/reg32x32_transaction.sv"
//`include "/home/fananiae/disertatie_Anania/tb/agents/reg32x32_driver.sv"
//`include "/home/fananiae/disertatie_Anania/tb/agents/reg32x32_monitor.sv"
//`include "/home/fananiae/disertatie_Anania/tb/environment/reg32x32_scoreboard.sv"
//`include "reg32x32_sequence.sv"
//`include "reg32x32_env.sv"
//`include "/home/fananiae/disertatie_Anania/tb/tests/reg32x32_test.sv"

module top_tb;

  logic clk;
  logic rst;
  logic [31:0] reg_shadow [0:31];         // Array pentru verificare
  int cyc_counter = 0;                    // Folosit in numararea ciclurilor

  // Instanytierea interfetei UVM
  reg32x32_if       reg_if(clk, rst);
  instrMem_if       imem_if(clk);
  fetch_instr_if    fetch_if(clk, rst);
  control_if        cu_if();
  decode_instr_if   decode_if(.clk(clk), .rst(rst));
  execute_instr_if  exe_if(.clk(clk), .rst(rst));
  memorate_instr_if mem_if(clk, rst);

  // Instantierea DUT (Design Under Test)
 REG32x32 reg32x32     (
                       .DataOutReg1   (reg_if.DataOutReg1),
                       .DataOutReg2   (reg_if.DataOutReg2),
                       .clk           (clk),
                       .rst           (rst),
                       .write_enable  (reg_if.write_enable),
                       .wr_addr       (reg_if.wr_addr),
                       .data_in       (reg_if.data_in),
                       .r_addr1       (reg_if.r_addr1),
                       .r_addr2       (reg_if.r_addr2)
                       );

 FETCH_INSTR fetch     (
                       .IF_Instr      (fetch_if.IF_Instr),
                       .IF_Pc         (fetch_if.IF_Pc),
                       .EXE_PcSrc     (fetch_if.EXE_PcSrc),
                       .EXE_PcTgt     (fetch_if.EXE_PcTgt),
                       .CountStall    (fetch_if.CountStall),
                       .clk           (fetch_if.clk),
                       .rst           (fetch_if.rst)
                       );

 IMEM imem_inst        (
                       .ReadDataOut  (imem_if.ReadDataOut),
                       .clk          (clk),
                       .ReadAddrIn   (imem_if.ReadAddrIn)
                       );

 CU controlUnit        (
                       .CU_Cmd           (cu_if.CU_Cmd),
                       .CU_AluSrc        (cu_if.CU_AluSrc),
                       .CU_AluControl    (cu_if.CU_AluControl),
                       .CU_LoadStoreCtrl (cu_if.CU_LoadStoreCtrl),
                       .CU_UnsignedFlag  (cu_if.CU_UnsignedFlag),
                       .CU_RegWrite      (cu_if.CU_RegWrite),
                       .CU_MemWriteEn    (cu_if.CU_MemWriteEn),
                       .CU_ResultSrc     (cu_if.CU_ResultSrc),
                       .CU_Jump          (cu_if.CU_Jump),
                       .CU_Branch        (cu_if.CU_Branch),
                       .InstrType        (cu_if.InstrType),
                       .AddUpperItoPc    (cu_if.AddUpperItoPc),
                       .Funct7Zero       (cu_if.Funct7Zero),
                       .Funct7NonZero    (cu_if.Funct7NonZero),
                       .InstrIn          (cu_if.InstrIn)
                       );

 DECODE_INSTR decode   (
                       .ID_Rd1                   (decode_if.ID_Rd1),
                       .ID_Rd2                   (decode_if.ID_Rd2),
                       .ID_Pc                    (decode_if.ID_Pc),
                       .ID_ImmExt                (decode_if.ID_ImmExt),
                       .ID_AluSrc                (decode_if.ID_AluSrc),
                       .ID_AluControl            (decode_if.ID_AluControl),
                       .ID_RegWrite              (decode_if.ID_RegWrite),
                       .ID_MemWriteEn            (decode_if.ID_MemWriteEn),
                       .ID_Jump                  (decode_if.ID_Jump),                       
                       .ID_LoadStoreCtrl         (decode_if.ID_LoadStoreCtrl),
                       .ID_Rdest                 (decode_if.ID_Rdest),
                       .ID_ResultSrc             (decode_if.ID_ResultSrc),
                       .ID_Branch                (decode_if.ID_Branch),
                       .ID_UnsignedFlag          (decode_if.ID_UnsignedFlag),
                       .IF_Instr                 (decode_if.IF_Instr),
                       .IF_Pc                    (decode_if.IF_Pc),
                       .WB_WriteEn               (decode_if.WB_WriteEn),
                       .WB_Result                (decode_if.WB_Result),
                       .Wr_Addr                  (decode_if.Wr_Addr),
                       .clk                      (decode_if.clk),
                       .rst                      (decode_if.rst)
                       );

 EXECUTE_INSTR execute  (
                        .EXE_AluResult    (exe_if.EXE_AluResult),
                        .EXE_Overflow     (exe_if.EXE_Overflow),
                        .EXE_Pc           (exe_if.EXE_Pc),
                        .EXE_ZeroFlag     (exe_if.EXE_ZeroFlag),
                        .EXE_RegWrite     (exe_if.EXE_RegWrite),
                        .EXE_MemWriteEn   (exe_if.EXE_MemWriteEn),
                        .EXE_WriteData    (exe_if.EXE_WriteData),
                        .EXE_ResultSrc    (exe_if.EXE_ResultSrc),
                        .EXE_Rdest        (exe_if.EXE_Rdest),
                        .EXE_PcSrc        (exe_if.EXE_PcSrc),
                        .EXE_PcTgt        (exe_if.EXE_PcTgt),
                        .EXE_UnsignedFlag (exe_if.EXE_UnsignedFlag),
                        .ID_Pc            (exe_if.ID_Pc),
                        .ID_ImmIn         (exe_if.ID_ImmIn),
                        .ID_Rd1           (exe_if.ID_Rd1),
                        .ID_Rd2           (exe_if.ID_Rd2),
                        .ID_AluSrc        (exe_if.ID_AluSrc),
                        .ID_AluControl    (exe_if.ID_AluControl),
                        .ID_RegWrite      (exe_if.ID_RegWrite),
                        .ID_MemWriteEn    (exe_if.ID_MemWriteEn),
                        .ID_UnsignedFlag  (exe_if.ID_UnsignedFlag),
                        .ID_Jump          (exe_if.ID_Jump),
                        .ID_Branch        (exe_if.ID_Branch),
                        .ID_Rdest         (exe_if.ID_Rdest),
                        .ID_ResultSrc     (exe_if.ID_ResultSrc),
                        .WB_Result        (exe_if.WB_Result),
                        .clk              (clk),
                        .rst              (rst)
                        );

  MEMORATE_INSTR mem    (
                        .MEM_ReadData     (mem_if.MEM_ReadData),
                        .MEM_ALUResult    (mem_if.MEM_ALUResult),
                        .MEM_ResultSrc    (mem_if.MEM_ResultSrc),
                        .MEM_RegWrite     (mem_if.MEM_RegWrite),
                        .MEM_Pc           (mem_if.MEM_Pc),
                        .MEM_Rdest        (mem_if.MEM_Rdest),
                        .EXE_Pc           (mem_if.EXE_Pc),
                        .EXE_RegWrite     (mem_if.EXE_RegWrite),
                        .EXE_UnsignedFlag (mem_if.EXE_UnsignedFlag),                        
                        .EXE_MemWriteEn   (mem_if.EXE_MemWriteEn),
                        .EXE_ResultSrc    (mem_if.EXE_ResultSrc),
                        .EXE_AluResult    (mem_if.EXE_AluResult),
                        .EXE_WriteData    (mem_if.EXE_WriteData),
                        .EXE_Rdest        (mem_if.EXE_Rdest),
                        .clk              (clk),
                        .rst              (rst)
                        );


//------------------------------------------------------------------------------
// Clock generator (simuleaza un semnal de clock la fiecare 10 ns)
//------------------------------------------------------------------------------
  initial begin
    clk = 0;
    forever begin
      #(`CLOCK_PERIOD/2) clk = ~clk;
      cyc_counter = cyc_counter+1;
    end
  end

//------------------------------------------------------------------------------
// Reg File zone
//------------------------------------------------------------------------------
integer i;                           // Used to populate instr mem
logic [31:0] Read_mem [0:31];

  // Task pentru scriere constanta
  task write(logic [`ADDR_WIDTH-1:0] WrAddr, logic [`DATA_WIDTH-1:0] Data, logic WriteMode);
  // WriteMode face diferenta dintre screierea in blocul de registrii si initierea memoriei de instr
    if (WriteMode==1) begin
      reg_if.write_enable = 1;
      reg_if.wr_addr      = WrAddr[`ADDR_WIDTH-1:0];
      reg_if.data_in      = Data  [`DATA_WIDTH-1:0];

      $display("reg_if.data_in = %h", reg_if.data_in);  
      @(posedge clk); 
      reg_if.write_enable = 0;
    end else begin
      for (i=0; i<32; i++) begin 
        $readmemh("/home/fananiae/disertatie_Anania/src/instr_mem.hex",Read_mem);
        $display("memory = %h", Read_mem[i]);          
      end
    end
  endtask
  
  task init();
    int incr;

    #`CLOCK_PERIOD rst = 0;   

    for (incr=0; incr<`ADDR_WIDTH; incr=incr+1) begin
      #`CLOCK_PERIOD write(incr[`ADDR_WIDTH-1:0],`DATA_WIDTH'h0, 1);
    end
  endtask

  initial begin
    rst = 1;
    #200 init();  // Reset activ pentru 200ns, apoi dezactivat

   repeat (100) begin
        // Scriere random
        reg_if.write_enable = 1;
        reg_if.wr_addr = $urandom_range(0, 31);
        reg_if.data_in = $urandom_range(0, 31);
        $display("Cycle %h:->  reg_if.wr_addr = %h, reg_if.data_in = %h", cyc_counter, reg_if.wr_addr, reg_if.data_in);        
        reg_shadow[reg_if.wr_addr] = reg_if.data_in; // Salvam valoarea
        #10;

        // Citire random
        reg_if.write_enable = 0;
        reg_if.r_addr1 = $urandom_range(0, 31);
        reg_if.r_addr2 = $urandom_range(0, 31);
        #10;

        // Verificare (daca am scris înainte în acel registru)
        if (reg_shadow[reg_if.r_addr1] !== reg_if.DataOutReg1)
            $display("Cycle %h:-> MISMATCH at r_addr1: Expected %h, Got %h", cyc_counter, reg_shadow[reg_if.r_addr1], reg_if.DataOutReg1);
        if (reg_shadow[reg_if.r_addr2] !== reg_if.DataOutReg2)
            $display("Cycle %h:-> MISMATCH at r_addr2: Expected %h, Got %h", cyc_counter, reg_shadow[reg_if.r_addr2], reg_if.DataOutReg2);
    end
  end
  // UVM Testbench Launch
//  initial begin
//    run_test("reg32x32_test"); 
//  end

//------------------------------------------------------------------------------
// Instruction Fetch zone
//------------------------------------------------------------------------------
  initial begin
      #`CLOCK_PERIOD write(`ADDR_WIDTH'h0,`DATA_WIDTH'h0, 0);
    repeat (100) begin
      fetch_if.CountStall = 1;
      #100
      fetch_if.CountStall = $urandom_range(0, 1);
      #`CLOCK_PERIOD
      fetch_if.CountStall = 1;
      #(25*`CLOCK_PERIOD)
      fetch_if.CountStall = 0;
      #(25*`CLOCK_PERIOD);
    end
  end

  initial begin
      $fsdbDumpfile("inter.fsdb");
      $fsdbDumpvars(0);
      $dumpfile("dump.vcd");
      $dumpvars(1);
  
      #`SIM_CYCLES $display ("Test done!\n");
  
      $finish;     
  end

//------------------------------------------------------------------------------
// Control Unit zone
//------------------------------------------------------------------------------
  // === Combinare complet pentru multe combinatii ===
  int total_tests  = 0;
  int passed_tests = 0;
  int opcode       = cu_if.InstrIn[`OPCODE_RANGE];

  function automatic logic [`INSTR_WIDTH-1:0] build_instr(
    input logic [6:0] funct7,
    input logic [4:0] rs2,
    input logic [4:0] rs1,
    input logic [2:0] funct3,
    input logic [4:0] rd,
    input logic [6:0] opcode
  );
    return {funct7, rs2, rs1, funct3, rd, opcode};
  endfunction

  // Task pentru afisare frumoasa
  task automatic print_result(
    input [`INSTR_TYPE_WIDTH-1:0] instr_type,
    input [2:0] funct3,
    input f7z, f7nz, auipc,
    input [`CU_WIDTH-1:0] cmd_out
  );
    $display("InstrType = %03b | Funct3 = %03b | F7z = %b | F7nz = %b | AUIPC = %b || CU_Cmd = %08b",
              instr_type, funct3, f7z, f7nz, auipc, cmd_out);
  endtask

  initial begin
    $display("=== START Extensive Testbench CU ===");

  // Iterate prin toate tipurile de instr
    for (int t = 0; t < 7; t++) begin
      for (int f3 = 0; f3 < 8; f3++) begin
        for (int f7z = 0; f7z < 2; f7z++) begin
          for (int f7nz = 0; f7nz < 2; f7nz++) begin
            for (int auipc = 0; auipc < 2; auipc++) begin
              cu_if.InstrType       = t[2:0];
              cu_if.AddUpperItoPc   = auipc;
              cu_if.Funct7Zero      = f7z;
              cu_if.Funct7NonZero   = f7nz;
              cu_if.InstrIn         = 32'b0;  // Zicem ca toate celelalte campuri sunt nule
              cu_if.InstrIn[14:12]  = f3[2:0]; // funct3 în pozitie

              #1; 

              print_result(cu_if.InstrType, f3[2:0], f7z, f7nz, auipc, cu_if.CU_Cmd);
            end
          end
        end
      end
    end
    $display("=== End Testbench ===");
    $finish;
    $display("\n=== END TESTS ===");
    $display("Total tests run: %0d", total_tests);
    $finish;
  end

endmodule
