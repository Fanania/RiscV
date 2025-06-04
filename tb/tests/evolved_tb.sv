`timescale 1ns / 1ps
`define CLOCK_PERIOD 10
`define SIM_CYCLES (1000 * `CLOCK_PERIOD)
`include "/home/fananiae/disertatie_Anania/src/Risc5.v"
`include "/home/fananiae/disertatie_Anania/src/defines.v"

  class instr_packet;
    rand bit [4:0] rd, rs1, rs2;
    rand bit [6:0] opcode;
    rand logic signed [31:0] imm;
    rand bit [2:0] funct3;
    rand bit [6:0] funct7;
    rand logic [2:0] instr_type;
    string type_name;
  
    function void display();
      $display("[%s] rd=%0d, rs1=%0d, rs2=%0d, imm=%0d, funct3=%0b, funct7=%0b, opcode=%0b",
               type_name, rd, rs1, rs2, imm, funct3, funct7, opcode);
    endfunction
  endclass

  class r_instr_packet extends instr_packet;
    function new();
      this.type_name = "R_TYPE";                 // used only in logs
      this.instr_type = `R_INSTR;
    endfunction
  
    constraint fields {
      rd  inside {[0:31]};
      rs1 inside {[0:31]};
      rs2 inside {[0:31]};
      funct3 inside {[0:7]};
      funct7 == 7'b0000000;
      opcode == 7'b0110011;
    }
  endclass

  class i_instr_packet extends instr_packet;
    function new();
      this.type_name = "I_TYPE";             // used only in logs
      this.instr_type = `I_INSTR;
    endfunction
  
    constraint fields {
      rd  inside {[0:31]};
      rs1 inside {[0:31]};
      rs2 == 0;
      funct3 inside {[0:7]};
      imm inside {[-2048:2047]};
      opcode == 7'b0000011;
      funct7 == 7'b0000000;   // further constraint on sll
    }
  endclass

 class l_instr_packet extends instr_packet;
   function new();
     this.type_name = "L_TYPE";             // used only in logs
     this.instr_type = `L_INSTR;     
   endfunction
   
   constraint fields {
      rd  inside {[0:31]};
      rs1 inside {[0:31]};
      rs2 == 0;
      funct3 inside {3'h0, 3'h1, 3'h2, 3'h4, 3'h5};
      imm inside {[-2048:2047]};
      opcode == 7'b0010011;
      funct7 == 7'b0000000;
    }
  endclass

  class s_instr_packet extends instr_packet;
    function new();
      this.type_name = "S_TYPE";             // used only in logs
      this.instr_type = `S_INSTR;     
    endfunction
  
    constraint fields {
      rs1 inside {[0:31]};
      rs2 inside {[0:31]};
      rd == 0;
      funct3 inside {3'h0, 3'h1, 3'h2};
      imm inside {[-2048:2047]};
      opcode == 7'b0100011;
      funct7 == 7'b0000000;
    }
  endclass
   
  class b_instr_packet extends instr_packet;
    function new();
      this.type_name = "B_TYPE";           // used only in logs
      this.instr_type = `B_INSTR;
    endfunction
  
    constraint fields {
      rs1 inside {[0:31]};
      rs2 inside {[0:31]};
      rd == 0;
      funct3 inside {3'b000, 3'b001};
      imm inside {[-2048:2047]};
      opcode == 7'b1100011;
      funct7 == 7'b0000000;
    }
    endclass
 
 class u_instr_packet extends instr_packet;
  function new();
    this.type_name = "U_TYPE";
    this.instr_type = `U_INSTR;
  endfunction

  constraint fields {
    rd inside {[0:31]};
    rs1 == 0;
    rs2 == 0;
    imm inside {[0:(2**20)-1]};
    opcode == 7'b0110111;
    funct3 == 0;
    funct7 == 0;
  }
  endclass

  class j_instr_packet extends instr_packet;
    function new();
      this.type_name = "J_TYPE";
      this.instr_type = `J_INSTR;      
    endfunction
  
    constraint fields {
      rd inside {[0:31]};
      rs1 == 0;
      rs2 == 0;
      imm inside {[-(2**20):(2**20)-1]};
      opcode == 7'b1101111;
      funct3 == 0;
      funct7 == 0;
    }
  endclass

module top_tb;
  logic clk;
  logic rst;
  int i=0;
  int cyc_counter = 0;                    // Folosit in numararea ciclurilor
  string base_path = "/home/fananiae/disertatie_Anania/tb/tests/";   // Use this as a general path
  string general_path = "/home/fananiae/disertatie_Anania/tb/tests/test_general.hex";
  RISC_V risc5          (
                        .clk(clk),
                        .rst(rst)
                        );
 initial begin
   rst = 1;
 end
 initial begin
 #50  rst = 0;
 end

  initial begin
    $display("Seed = %0d", $urandom());
  end

  initial begin
   string testname;

    if (!$value$plusargs("testname=%s", testname)) begin
      $display("!!!!! Erorr: Specify +testname=nume");               // MAke sure tests are added. At least hexa programs
      $finish;
    end
    if      (testname == "general") generate_n_instr_to_hex(general_path,100);    
    else if  (testname == "add")    generate_add();
    else if (testname == "branch") generate_branch();
    else if (testname == "load")   generate_load();
    else begin
      $display("!!! Unknown Test: %s", testname);
      $finish;
    end
  end

function automatic [`INSTR_WIDTH-1:0] generate_instr(
    input  logic [`INSTR_TYPE_WIDTH-1:0]  instr_type,
    input  logic [6:0]  funct7,
    input  logic [`ADDR_IDX-1:0]  rs2,
    input  logic [`ADDR_IDX-1:0]  rs1,
    input  logic [2:0]  funct3,
    input  logic [`ADDR_IDX-1:0]  rd,
    input  logic [6:0]  opcode,
    input  logic [`DATA_WIDTH-1:0] imm           // I, S, B, U, J  (Data is 32 bits)
);    
  case (instr_type)
    `R_INSTR:            begin generate_instr = {funct7, rs2, rs1, funct3, rd, opcode}; end
    `I_INSTR, `L_INSTR:  begin generate_instr = {imm[11:0], rs1, funct3, rd, opcode}; end
    `S_INSTR:            begin generate_instr = {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode}; end
    `B_INSTR:            begin generate_instr = {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode}; end
    `U_INSTR:            begin generate_instr = {imm[31:12], rd, opcode};  end
    `J_INSTR:            begin generate_instr = {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode}; end
    default:             begin generate_instr = 32'hffff;  end
  endcase
    $display("ERRRORRRRRRRRRRRRRRRRRRRRR ,instr_TYPE = %03b, funct7=%06b, rs2 = %05b, rs1 = %05b, rd = %05d, opcode = %07b, funct3 = %03b, generated instruction = %032b",instr_type,funct7,rs2,rs1,rd,opcode,funct3, generate_instr);
 endfunction
    
 task generate_n_instr_to_hex(string filepath, int n); // Just a repeater 
   logic [31:0] instr;
   logic [3:0] testa;
   logic [`ADDR_IDX  -1:0] rd;
   logic [`ADDR_IDX  -1:0] rs1;
   logic [`ADDR_IDX  -1:0] rs2;
   logic [`DATA_WIDTH-1:0] imm;            
   logic [`INSTR_TYPE_WIDTH-1:0] instr_type;
   logic [6:0] funct7;
   logic [2:0] funct3;
   logic [6:0] opcode;
                                           
   logic signed [12:0] offset;
   logic signed [20:0] joffset;

   instr_packet pkt;
   int choice;

   int f = $fopen("/home/fananiae/disertatie_Anania/tb/tests/test_general.hex", "w");   //  Open the hexa file
   if (!f) begin
    $fatal("ERROR couldn't open %s for writing!", filepath);    
   end

  for (i = 0; i < n; i++) begin
  choice = $urandom_range(0, 6); // 0 to 6
      case (choice)
         1:  pkt = new i_instr_packet(); 
         2:  pkt = new l_instr_packet(); 
         3:  pkt = new s_instr_packet(); 
         4:  pkt = new b_instr_packet(); 
         0:  pkt = new r_instr_packet();          
         5:  pkt = new u_instr_packet(); 
         6:  pkt = new j_instr_packet(); 
      endcase
  
      if (!pkt.randomize()) begin
        $fatal("Randomization failed at index %0d", i);
      end
  
      instr = generate_instr(pkt.instr_type, pkt.funct7, pkt.rs2, pkt.rs1, pkt.funct3, pkt.rd, pkt.opcode, pkt.imm);
  
      pkt.display();
      $fdisplay(f, "%08h", instr);
    end
 endtask

  task generate_add();
  string full_path = {base_path,"test_add.hex"};

    int f = $fopen(full_path, "w");
    $display("Generate test_add.hex");

    $fdisplay(f, "00500293");                   // addi x5, x0, 5
    $fdisplay(f, "00600313");                   // addi x6, x0, 6
    $fdisplay(f, "00B304B3");                   // add x9, x6, x11
    $fdisplay(f, "0000006F");                   // jal x0, 0

    $fclose(f);
  endtask

  task generate_branch();
    int f = $fopen("test_branch.hex", "w");
    $display("¿? Generez test_branch.hex");

    $fdisplay(f, "00500293"); // addi x5, x0, 5
    $fdisplay(f, "00500293"); // addi x5, x0, 5
    $fdisplay(f, "0052A063"); // beq x5, x5, +4
    $fdisplay(f, "0000006F"); // jal x0, 0

    $fclose(f);
  endtask

  task generate_load();
  string full_path = {base_path,"test_load.hex"};  
    int f = $fopen(full_path, "w");
    $display("Generete Init every regfile entry using test_load.hex");
    $fdisplay(f,"00000000");
    $fdisplay(f,"00000000");
    $fdisplay(f,"00000000");
    $fdisplay(f,"04000083");
    $fdisplay(f,"05041083");
    $fdisplay(f,"060082C3");
    $fdisplay(f,"08085103");
    $fdisplay(f,"0C084143");
    $fdisplay(f,"10000183");
    $fdisplay(f,"110411C3");
    $fdisplay(f,"12008203");
    $fdisplay(f,"14085243");
    $fdisplay(f,"00000000");
    $fdisplay(f,"00000000");
    $fdisplay(f,"00000000");
    $fdisplay(f,"18008283");
    $fdisplay(f,"1C0002C3");
    $fdisplay(f,"1D041303");
    $fdisplay(f,"1E084343");
    $fdisplay(f,"20085383");
    $fdisplay(f,"240843C3");
    $fdisplay(f,"28000403");
    $fdisplay(f,"29041443");
    $fdisplay(f,"2A084483");
    $fdisplay(f,"2C0854C3");
    $fdisplay(f,"30008503");
    $fdisplay(f,"34000543");
    $fdisplay(f,"35041583");
    $fdisplay(f,"360085C3");
    $fdisplay(f,"38085603");
    $fdisplay(f,"3C089643");
    $fdisplay(f,"40000683");
    $fdisplay(f,"410416C3");
    $fdisplay(f,"42008703");
    $fdisplay(f,"44085743");
    $fdisplay(f,"00000000");
    $fdisplay(f,"00000000");
    $fdisplay(f,"00000000");
    $fdisplay(f,"48008783");
    $fdisplay(f,"4C0007C3");
    $fdisplay(f,"4396203C");
    $fdisplay(f,"83060040");
    $fdisplay(f,"83782048");
    $fdisplay(f,"00000000");
    $fdisplay(f,"00000000");
    $fdisplay(f,"C307004C");
    $fdisplay(f,"00002283"); // lw x5, 0(x0)
    $fdisplay(f,"0000006F"); // jal x0, 0

    $fclose(f);
  endtask

// initial begin
//   forever begin
//    #10  $display("%0d este ciclul la care ma aflu. Resetul este %0d",cyc_counter,rst);
//   end
// end
 initial begin
   clk = 0;
   forever begin
     #(`CLOCK_PERIOD/2) clk = ~clk;
     cyc_counter = cyc_counter+1;
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
endmodule
