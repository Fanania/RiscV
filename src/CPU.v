`include "/home/fananiae/disertatie_Anania/src/defines.v"

module CPU (
  output [`PC_WIDTH      -1:0] ReadAddrInstrMem,
  output [`ADDR_WIDTH    -1:0] EXE_AluResult,
  output [`DATA_WIDTH    -1:0] DataMasked,
  output                       EXE_MemWriteEn,
  output                       Flush,
  input                        clk,
  input                        rst,
  input  [`INSTR_WIDTH   -1:0] FetchedInstr,
  input  [`DATA_WIDTH     -1:0] RdData
);

  wire [`INSTR_WIDTH     -1:0] IF_Instr; 
  wire [`PC_WIDTH        -1:0] IF_Pc;
  wire                         EXE_PcSrc;
  wire [`PC_WIDTH        -1:0] EXE_PcTgt;
  wire                         CountStall;
 
  wire [`DATA_WIDTH      -1:0] ID_Rd1;
  wire [`DATA_WIDTH      -1:0] ID_Rd2;
  wire [`PC_WIDTH        -1:0] ID_Pc;
  wire [`DATA_WIDTH      -1:0] ID_ImmExt;
  wire                         ID_AluSrc;
  wire                   [3:0] ID_AluControl;
  wire                         ID_RegWrite;
  wire                         ID_MemWriteEn;
  wire                   [3:0] ID_LoadStoreCtrl;
  wire                   [3:0] EXE_LoadStoreCtrl;
  wire [`ADDR_IDX        -1:0] ID_Rdest;
  wire [`ADDR_IDX        -1:0] ID_Rs1;
  wire [`ADDR_IDX        -1:0] ID_Rs2;  
  wire                   [1:0] ID_ResultSrc;
  wire                         ID_Jump;
  wire                         ID_Branch;
  wire                         WB_WriteEn;
  wire [`DATA_WIDTH      -1:0] WB_Result;
  wire [`ADDR_IDX        -1:0] Wr_Addr;

  wire                         EXE_Overflow;
  wire [`PC_WIDTH        -1:0] EXE_Pc;
  wire                         EXE_RegWrite;
  wire [`DATA_WIDTH      -1:0] EXE_WriteData;
  wire                   [1:0] EXE_ResultSrc;
  wire [`ADDR_IDX        -1:0] EXE_Rdest;
  wire [`DATA_WIDTH      -1:0] ID_ImmIn;

  wire [`DATA_WIDTH      -1:0] MEM_ReadData;
  wire [`ADDR_WIDTH      -1:0] MEM_ALUResult;
  wire                   [1:0] MEM_ResultSrc;
  wire                         MEM_RegWrite;
  wire [`PC_WIDTH        -1:0] MEM_Pc;
  wire [`ADDR_IDX        -1:0] MEM_Rdest;
  wire [`HWA_WIDTH       -1:0] Hwa;

  wire [`FW_WIDTH        -1:0] HU_ForwardA;
  wire [`FW_WIDTH        -1:0] HU_ForwardB;  
  wire                         HU_Stall;
  wire                         Flush;

  wire [`PC_WIDTH        -1:0] WB_PcJumpBack;
  wire                         BpbMiss;
  assign CountStall = HU_Stall; // BOZO fixme
  assign Flush      = HU_Stall
                    `ifndef BPB_ENABLE
                    | EXE_PcSrc
                    `else
                    | BpbMiss | ID_Jump              // Flush if branch predictor is wrong
                    `endif
                    ;

  FETCH_INSTR Fetch_Stage_1 (
  .IF_Instr                 (IF_Instr          ),
  .IF_Pc                    (IF_Pc             ),
  .IF_Hwa                   (Hwa[`HWA_IF_RANGE]),  
  .BpbMiss                  (BpbMiss           ),
  .ProgramCounter_d0        (ReadAddrInstrMem  ),  
  .FetchedInstr             (FetchedInstr      ),
  .ID_Branch                (ID_Branch         ),
  .ID_Pc                    (ID_Pc             ),
  .EXE_PcSrc                (EXE_PcSrc         ),  
  .EXE_PcTgt                (EXE_PcTgt         ),
  .CountStall               (CountStall        ),
  .Flush                    (Flush             ),      
  .clk                      (clk               ),
  .rst                      (rst               )
  );

  DECODE_INSTR Decode_Stage_2 (
  .ID_Rd1                     (ID_Rd1               ), 
  .ID_Rd2                     (ID_Rd2               ),
  .ID_Pc                      (ID_Pc                ),
  .ID_ImmExt                  (ID_ImmExt            ), 
  .ID_AluSrc                  (ID_AluSrc            ), 
  .ID_AluControl              (ID_AluControl        ), 
  .ID_RegWrite                (ID_RegWrite          ),
  .ID_MemWriteEn              (ID_MemWriteEn        ),
  .ID_Rdest                   (ID_Rdest             ),
  .ID_ResultSrc               (ID_ResultSrc         ),
  .ID_Jump                    (ID_Jump              ),
  .ID_Branch                  (ID_Branch            ),  
  .ID_LoadStoreCtrl           (ID_LoadStoreCtrl     ),
  .ID_UnsignedFlag            (ID_UnsignedFlag      ), 
  .ID_Rs1                     (ID_Rs1               ),
  .ID_Rs2                     (ID_Rs2               ),
  .ID_Hwa                     (Hwa[`HWA_ID_RANGE]   ),
  .IF_Instr                   (IF_Instr             ), 
  .IF_Pc                      (IF_Pc                ),
  .Flush                      (Flush                ),  
  .WB_WriteEn                 (WB_WriteEn           ), 
  .WB_Result                  (WB_Result            ),
  .Wr_Addr                    (MEM_Rdest            ),
  .clk                        (clk                  ),
  .rst                        (rst                  )
  );

  EXECUTE_INSTR Execute_Stage_3 (
  .EXE_AluResult                (EXE_AluResult    ),
  .EXE_Overflow                 (EXE_Overflow     ),
  .EXE_Pc                       (EXE_Pc           ),
  .EXE_RegWrite                 (EXE_RegWrite     ),
  .EXE_MemWriteEn               (EXE_MemWriteEn   ),
  .EXE_WriteData                (EXE_WriteData    ),
  .EXE_ResultSrc                (EXE_ResultSrc    ),  
  .EXE_LoadStoreCtrl            (EXE_LoadStoreCtrl),  
  .EXE_Rdest                    (EXE_Rdest        ),
  .EXE_PcSrc                    (EXE_PcSrc        ),  
  .EXE_PcTgt                    (EXE_PcTgt        ),
  .EXE_UnsignedFlag             (EXE_UnsignedFlag ),
  .Flush                        (Flush            ),        
  .EXE_Hwa                      (Hwa[`HWA_EXE_RANGE]),
  .ID_Pc                        (ID_Pc            ),
  .ID_ImmIn                     (ID_ImmExt        ),
  .ID_Rd1                       (ID_Rd1           ), 
  .ID_Rd2                       (ID_Rd2           ),
  .ID_AluSrc                    (ID_AluSrc        ),
  .ID_Jump                      (ID_Jump          ),
  .ID_Branch                    (ID_Branch        ),
  .ID_AluControl                (ID_AluControl    ),
  .ID_LoadStoreCtrl             (ID_LoadStoreCtrl ),
  .ID_RegWrite                  (ID_RegWrite      ),
  .ID_ResultSrc                 (ID_ResultSrc     ),
  .ID_MemWriteEn                (ID_MemWriteEn    ),
  .ID_Rdest                     (ID_Rdest         ),
  .ID_UnsignedFlag              (ID_UnsignedFlag  ),
  .WB_Result                    (WB_Result        ),
  .HU_ForwardA                  (HU_ForwardA      ),
  .HU_ForwardB                  (HU_ForwardB      ),
  .clk                          (clk              ),
  .rst                          (rst              )
  );

 MEMORATE_INSTR Mem_Stage_4 (
 .MEM_ReadData              (MEM_ReadData       ),
 .MEM_ALUResult             (MEM_ALUResult      ),
 .MEM_ResultSrc             (MEM_ResultSrc      ),
 .MEM_RegWrite              (MEM_RegWrite       ),
 .MEM_Pc                    (MEM_Pc             ),
 .MEM_Rdest                 (MEM_Rdest          ),
 .DataMasked                (DataMasked         ),
 .RdData                    (RdData             ), 
 .MEM_Hwa                   (Hwa[`HWA_MEM_RANGE]),
 .EXE_AluResult             (EXE_AluResult      ),
 .EXE_MemWriteEn            (EXE_MemWriteEn     ), 
 .EXE_RegWrite              (EXE_RegWrite       ),
 .EXE_ResultSrc             (EXE_ResultSrc      ),
 .EXE_LoadStoreCtrl         (EXE_LoadStoreCtrl  ),  
 .EXE_WriteData             (EXE_WriteData      ),
 .EXE_Rdest                 (EXE_Rdest          ),
 .EXE_UnsignedFlag          (EXE_UnsignedFlag   ), 
 .EXE_Pc                    (EXE_Pc             ),  
 .clk                       (clk                ),
 .rst                       (rst                ) 
 );
 
 HAZARD_UNIT Hu_Detect (
 .HU_ForwardA           (HU_ForwardA         ),
 .HU_ForwardB           (HU_ForwardB         ),
 .HU_Stall              (HU_Stall            ),
 .HU_Hwa                (Hwa[`HWA_HU_RANGE]  ),
 .IF_Rs2                (IF_Instr[`RS2_RANGE]),
 .IF_Rs1                (IF_Instr[`RS1_RANGE]),
 .ID_Rs2                (ID_Rs2              ),
 .ID_Rs1                (ID_Rs1              ),
 .ID_ResultSrc          (ID_ResultSrc        ),
 .ID_Rdest              (ID_Rdest            ), 
 .ID_RegWrite           (ID_RegWrite         ),
 .EXE_Rdest             (EXE_Rdest           ),
 .EXE_RegWrite          (EXE_RegWrite        ),
 .MEM_Rdest             (MEM_Rdest           ),
 .MEM_RegWrite          (MEM_RegWrite        )
);

 WRITEBACK_INSTR WriteBack_Stage_5 (
 .WB_WriteEn                 (WB_WriteEn           ),
 .WB_PcJumpBack              (WB_PcJumpBack        ),
 .WB_Result                  (WB_Result            ),
 .MEM_RegWrite               (MEM_RegWrite         ),
 .MEM_ResultSrc              (MEM_ResultSrc        ),
 .MEM_ALUResult              (MEM_ALUResult        ),
 .MEM_ReadData               (MEM_ReadData         ),
 .MEM_Pc                     (MEM_Pc               )
 );
endmodule
