`timescale 1ns / 1ps
`define CLOCK_PERIOD 10
`define SIM_CYCLES (1000 * `CLOCK_PERIOD)
`include "/home/fananiae/disertatie_Anania/src/Risc5.v"
`include "/home/fananiae/disertatie_Anania/src/CPU.v"
`include "/home/fananiae/disertatie_Anania/src/IMEM.v"
`include "/home/fananiae/disertatie_Anania/src/DMEM.v"
`include "/home/fananiae/disertatie_Anania/src/IF.v"
`include "/home/fananiae/disertatie_Anania/src/ID.v"
`include "/home/fananiae/disertatie_Anania/src/EXE.v"
`include "/home/fananiae/disertatie_Anania/src/MEM.v"
`include "/home/fananiae/disertatie_Anania/src/HU.v"
`include "/home/fananiae/disertatie_Anania/src/WRITEBACK_INSTR.v"
`include "/home/fananiae/disertatie_Anania/src/defines.v"
`include "/home/fananiae/disertatie_Anania/tb/tests/bubble_sort_prog.sv"

import bubble_sort_prog_pkg::*;

virtual class instr_packet;
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
      instr_type == `R_INSTR;                    // keep the class-specific type constant during randomize()
      rd  inside {[0:31]};
      rs1 inside {[0:31]};
      rs2 inside {[0:31]};
      funct3 inside {[0:7]};
      opcode == `OP_ARITM_R;
      imm    == 0;
      if (funct3 == 3'b000) funct7 inside {7'b0000000, 7'b0100000};   // ADD / SUB
      if (funct3 == 3'b101) funct7 inside {7'b0000000, 7'b0100000};   // SRL / SRA
      if (!(funct3 inside {3'b000,3'b101})) funct7 == 7'b0000000;
    }
  endclass

  class i_instr_packet extends instr_packet;
    function new();
      this.type_name = "I_TYPE";             // used only in logs
      this.instr_type = `I_INSTR;
    endfunction
  
    constraint fields {
      instr_type == `I_INSTR;                  // prevent the solver from retagging this packet
      rd  inside {[0:31]};
      rs1 inside {[0:31]};
      rs2 == 0;
      funct3 inside {[0:7]};
      opcode == `OP_ARITM_IMM;
      imm[31:12] == {20{imm[11]}};                    // keep immediate within 12-bit sign-extended range
      if (funct3 == 3'b001) funct7 == 7'b0000000;
      if (funct3 == 3'b001) imm[11:5] == 7'b0000000;
      if (funct3 == 3'b001) imm[4:0] inside {[0:31]};                 // SLLI shift amount

      if (funct3 == 3'b101) funct7 inside {7'b0000000, 7'b0100000};
      if (funct3 == 3'b101 && funct7 == 7'b0000000) imm[11:5] == 7'b0000000; // SRLI encoding
      if (funct3 == 3'b101 && funct7 == 7'b0100000) imm[11:5] == 7'b0100000; // SRAI encoding
      if (funct3 == 3'b101) imm[4:0] inside {[0:31]};

      if (!(funct3 inside {3'b001,3'b101})) funct7 == 7'b0000000;
      if (!(funct3 inside {3'b001,3'b101})) imm inside {[-16:-1], [0:31]};    // include small negatives
    }
  endclass

  class l_instr_packet extends instr_packet;
   function new();
     this.type_name = "L_TYPE";             // used only in logs
     this.instr_type = `L_INSTR;     
   endfunction
   
   constraint fields {
      instr_type == `L_INSTR;                 // retain load encoding classification
      rd  inside {[0:31]};
      rs1 == 5'd0;                            // use x0 as base to keep addresses aligned
      rs2 == 0;
      funct3 inside {3'h0, 3'h1, 3'h2, 3'h4, 3'h5};
      imm inside {[0:64]};
      if (funct3 inside {3'h1,3'h5}) imm[0] == 1'b0;   // halfword loads aligned
      if (funct3 == 3'h2)            imm[1:0] == 2'b00; // word loads aligned
      opcode == `OP_LOAD_IMM;
      funct7 == 7'b0000000;
    }
  endclass

  class s_instr_packet extends instr_packet;
    function new();
      this.type_name = "S_TYPE";             // used only in logs
      this.instr_type = `S_INSTR;     
    endfunction
  
   constraint fields {
      instr_type == `S_INSTR;                 // lock packet flavour for stores
      rs1 == 5'd0;
      rs2 inside {[0:31]};
      rd == 0;
      funct3 inside {3'h0, 3'h1, 3'h2};
      imm inside {[0:64]};
      if (funct3 == 3'h1) imm[0] == 1'b0;
      if (funct3 == 3'h2) imm[1:0] == 2'b00;
      opcode == `OP_STORE_IMM;
      funct7 == 7'b0000000;
    }
  endclass
   
  class b_instr_packet extends instr_packet;
    function new();
      this.type_name = "B_TYPE";           // used only in logs
      this.instr_type = `B_INSTR;
    endfunction
  
    constraint fields {
      instr_type == `B_INSTR;               // branch packets must stay branches
      rs1 inside {[0:31]};
      rs2 inside {[0:31]};
      rd == 0;
      funct3 inside {3'b000, 3'b001};
      imm inside {[-20:20]};
      imm[0] == 1'b0;                       // branch offsets must be even
      opcode == `OP_BRANCH;
      funct7 == 7'b0000000;
    }
    endclass

 class u_instr_packet extends instr_packet;
  function new();
    this.type_name = "U_TYPE";
    this.instr_type = `U_INSTR;
  endfunction

  constraint fields {
    instr_type == `U_INSTR;                 // preserve U-type identity
    rd inside {[0:31]};
    rs1 == 0;
    rs2 == 0;
    imm inside {[0:(2**20)-1]};
    opcode == `OP_ADD_UPPER_I;
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
      instr_type == `J_INSTR;               // ensure J packets stay as jumps
      rd inside {[0:31]};
      rs1 == 0;
      rs2 == 0;
      imm dist {[-(2**20):-2] :/ 5, [0:(2**6)-2] :/ 90, [(2**6):(2**20)-2] :/5};
      imm[0] == 1'b0;
      opcode == `OP_JUMP_LINK_J;
      funct3 == 0;
      funct7 == 0;
    }
  endclass

module top_tb;
  logic clk;
  logic rst;
  logic imem_load_done;
  bit   allow_unaligned_ls = 1'b0;
  int i=0;
  int cyc_counter = 0;                    // Folosit in numararea ciclurilor
  string base_path = "/home/fananiae/disertatie_Anania/tb/tests/";   // Use this as a general path
  string general_path = "/home/fananiae/disertatie_Anania/tb/tests/test_general.hex";
  RISC_V risc5          (
                        .clk(clk),
                        .rst(rst),
                        .imem_load_done(imem_load_done)
                        );
 initial begin
   rst = 1;
   imem_load_done = 1'b0;
 end
 initial begin
 #50  rst = 0;
 end

  initial begin
    $display("Seed = %0d", $urandom());
  end

  initial begin
   string testname;
   int allow_unaligned_arg;

    if ($value$plusargs("allow_unaligned_ls=%d", allow_unaligned_arg)) begin
      allow_unaligned_ls = (allow_unaligned_arg != 0);
      $display("allow_unaligned_ls=%0d (1 enables random unaligned load/store offsets)", allow_unaligned_ls);
    end

    if (!$value$plusargs("testname=%s", testname)) begin
      $display("!!!!! Erorr: Specify +testname=nume");               // MAke sure tests are added. At least hexa programs
      $finish;
    end
    if      (testname == "general") generate_n_instr_to_hex(general_path,200);    
/*    else if  (testname == "add")    generate_add(); */
    else if (testname == "branch") generate_branch();
    else if (testname == "load")   generate_load();
    else if (testname == "bubble_sort") generate_bubble_sort();
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
  logic [`INSTR_WIDTH-1:0] instr_word;
  logic [11:0]             imm_i_s;
  logic [12:0]             imm_b;
  logic [20:0]             imm_j;

  instr_word = '0;
  imm_i_s    = imm[11:0];
  imm_b      = imm[12:0];
  imm_j      = imm[20:0];

  unique case (instr_type)
    `R_INSTR: begin
      instr_word[`FUNCT7_RANGE] = funct7;
      instr_word[`RS2_RANGE]    = rs2;
      instr_word[`RS1_RANGE]    = rs1;
      instr_word[`FUNCT3_RANGE] = funct3;
      instr_word[`RD_RANGE]     = rd;
      instr_word[`OPCODE_RANGE] = opcode;
    end
    `I_INSTR,
    `L_INSTR: begin
      instr_word[`IMM_RANGE]    = imm_i_s;
      instr_word[`RS1_RANGE]    = rs1;
      instr_word[`FUNCT3_RANGE] = funct3;
      instr_word[`RD_RANGE]     = rd;
      instr_word[`OPCODE_RANGE] = opcode;
    end
    `S_INSTR: begin
      instr_word[`S_B_IMMHI_RANGE] = imm_i_s[11:5];
      instr_word[`RS2_RANGE]       = rs2;
      instr_word[`RS1_RANGE]       = rs1;
      instr_word[`FUNCT3_RANGE]    = funct3;
      instr_word[`S_B_IMMLO_RANGE] = imm_i_s[4:0];
      instr_word[`OPCODE_RANGE]    = opcode;
    end
    `B_INSTR: begin
      instr_word[`FUNCT7_RANGE] = {imm_b[12], imm_b[10:5]};
      instr_word[`RS2_RANGE]    = rs2;
      instr_word[`RS1_RANGE]    = rs1;
      instr_word[`FUNCT3_RANGE] = funct3;
      instr_word[`RD_RANGE]     = {imm_b[4:1], imm_b[11]};
      instr_word[`OPCODE_RANGE] = opcode;
    end
    `U_INSTR: begin
      instr_word[`UIMM_RANGE]   = imm[31:12];
      instr_word[`RD_RANGE]     = rd;
      instr_word[`OPCODE_RANGE] = opcode;
    end
    `J_INSTR: begin
      instr_word[31]            = imm_j[20];
      instr_word[30:21]         = imm_j[10:1];
      instr_word[20]            = imm_j[11];
      instr_word[19:12]         = imm_j[19:12];
      instr_word[`RD_RANGE]     = rd;
      instr_word[`OPCODE_RANGE] = opcode;
      /// debug
    end
    `N_INSTR: begin
      instr_word = '0;
    end
    default: begin
      instr_word = {`INSTR_WIDTH{1'b1}};
    end
  endcase

  return instr_word;
 endfunction
   
/*function string to_upper(string s);
  string result = "";
  for (int i = 0; i < s.len(); i++) begin
    if (s[i] >= "a" && s[i] <= "f") begin
      result[i] = byte'(s[i] - 32); // direct cu 8-bit literals
      $display("result now is=%h",result); 
    end else
      result[i] = s[i];
  end
  return result;
endfunction
*/
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
   r_instr_packet r_pkt;
   i_instr_packet i_pkt;
   l_instr_packet l_pkt;
   s_instr_packet s_pkt;
   b_instr_packet b_pkt;
   u_instr_packet u_pkt;
   j_instr_packet j_pkt; 

   int choice;
   string String_instr;
   longint unsigned temp;

   int f = $fopen("/home/fananiae/disertatie_Anania/tb/tests/test_general.hex", "w");   //  Open the hexa file
   if (!f) begin
    $fatal("ERROR couldn't open %s for writing!", filepath);    
   end
   imem_load_done = 1'b0;
  for (i = 0; i < n; i++) begin
      int curr_pc;
      int target_idx;
      int target_pc;
      int offset;
      choice = $urandom_range(0, 12); // 0 to 6
      case (choice)
         0,1,8:  begin r_pkt = new(); pkt = r_pkt; end     
         5,6,7:  begin i_pkt = new(); pkt = i_pkt; end
         3,4:        begin l_pkt = new(); pkt = l_pkt; end
         2:        begin s_pkt = new(); pkt = s_pkt; end
         10,9:       begin b_pkt = new(); pkt = b_pkt; end
         11:       begin u_pkt = new(); pkt = u_pkt; end
         12:       begin j_pkt = new(); pkt = j_pkt; end
      endcase
  
      if (!pkt.randomize()) begin
        $fatal("Randomization failed at index %0d", i);
      end

      curr_pc = i * `PC_INCR;

     /* if (pkt.instr_type == `B_INSTR) begin
        target_idx = $urandom_range(0, (n > 0) ? n-1 : 0);
        target_pc  = target_idx * `PC_INCR;
        offset     = $signed(target_pc) + $signed(curr_pc);

        pkt.imm = offset; // enforce in-range branch target
        $display("my Branch Imm is %d\n", pkt.imm );

      end else*/ if ((pkt.instr_type == `J_INSTR) || (pkt.instr_type == `B_INSTR)) begin
        target_idx = $urandom_range(0, (n > 0) ? 30 : 0);
    //    target_pc  = target_idx * `PC_INCR;
        offset     = $signed(target_idx) /*+ $signed(curr_pc)*/;

        pkt.imm = offset; // keep jump target inside instruction memory
        $display("on instr with the pc %d, target_idx =%d ,my Instruction is %s, Imm is %d\n", curr_pc,target_idx,pkt.instr_type,$signed(pkt.imm));
      end

      if ((pkt.instr_type == `L_INSTR) || (pkt.instr_type == `S_INSTR)) begin
        int align_bits;
        int max_offset;

        unique case (pkt.funct3)
          3'h0, 3'h4: align_bits = 0; // byte / unsigned byte
          3'h1, 3'h5: align_bits = 1; // halfword / unsigned halfword
          3'h2:       align_bits = 2; // word
          default:    align_bits = 0;
        endcase

        max_offset = 64 >> align_bits;
        pkt.imm = ($urandom_range(0, max_offset) << align_bits);
      end
  
      instr = generate_instr(pkt.instr_type, pkt.funct7, pkt.rs2, pkt.rs1, pkt.funct3, pkt.rd, pkt.opcode, pkt.imm);
  
      pkt.display();  // Detailed packet.
      // Problem the generated instruction must be converted on upper case string format
      temp = instr; // conversie explicit
      String_instr = $sformatf("%08X",temp);   // take the logic input and convert to Upper case string 
      $display("my generated instruction is %s", String_instr);
  //    if (i <= 3) begin
  //    $fdisplay(f,"00000000");      
  //    end else begin
      $fdisplay(f, "%08S", String_instr);      
  //    end
    end
  $fclose(f);
  #1 imem_load_done = 1'b1;
endtask

task generate_bubble_sort();
  string full_path = {base_path,"test_bubble_sort.hex"};
  $display("Generate bubble sort program at %s", full_path);
  imem_load_done = 1'b0;
  write_bubble_sort_hex(full_path);
  #1 imem_load_done = 1'b1;
endtask

/*  task generate_add();
  string full_path = {base_path,"test_add.hex"};

    int f = $fopen(full_path, "w");
    $display("Generate test_add.hex");
    imem_load_done = 1'b0;

    $fdisplay(f, "00500293");                   // addi x5, x0, 5
    $fdisplay(f, "00600313");                   // addi x6, x0, 6
    $fdisplay(f, "00B304B3");                   // add x9, x6, x11
    $fdisplay(f, "0000006F");                   // jal x0, 0

    $fclose(f);
    #1 imem_load_done = 1'b1;
  endtask */

  task generate_branch();
    int f = $fopen("test_branch.hex", "w");
    $display("Generez test_branch.hex");
    imem_load_done = 1'b0;

    $fdisplay(f, "00500293"); // addi x5, x0, 5
    $fdisplay(f, "00500293"); // addi x5, x0, 5
    $fdisplay(f, "0052A063"); // beq x5, x5, +4
    $fdisplay(f, "0000006F"); // jal x0, 0

    $fclose(f);
    #1 imem_load_done = 1'b1;
  endtask

  task generate_load();
  string full_path = {base_path,"test_load.hex"};  
    int f = $fopen(full_path, "w");
    $display("Generete Init every regfile entry using test_load.hex");
    imem_load_done = 1'b0;
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
    #1 imem_load_done = 1'b1;
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
