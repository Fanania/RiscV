`include "/home/fananiae/disertatie_Anania/src/defines.v"
  module LoadStore (
    output reg [`DATA_WIDTH-1:0] DataMasked,
    output reg             [1:0] Hwa,           // Hardware warning flags: [1] = word misalign, [0] = half misalign
    input                        MemWriteEn,    // 1 for writes
    input                  [3:0] LoadStoreCtrl, // [3] = valid, [2:0] = command
    input      [`DATA_WIDTH-1:0] RawLdDataIn,   // Unmasked Data seen on the output port of the memory
    input      [`DATA_WIDTH-1:0] WriteDataIn,   // Unmsaked Data which will be written in the memory
    input                  [1:0] Addr,          // Address offset for byte/half-word access
    input                        UnsignedFlag   // Based on the instr type (lhu/lbu vs shu/sbu)
  ); 
  
  wire                  LoadSoreValid;
  reg                   WordAddressingErr;
  reg                   HalfAddressingErr;
  reg                   IsByteAccess;
  reg                   IsHalfAccess;
  reg                   IsWordAccess;
  reg             [3:0] Sign;
  reg [`DATA_WIDTH-1:0] BAlgnData;
  reg [`DATA_WIDTH-1:0] HAlgnData;  
  reg   [`BYTES_NR-1:0] ByteAlignedSignBit;
  reg             [1:0] HalfAlignedSignBit;
  reg [`DATA_WIDTH-1:0] RawData;
  
  assign LoadSoreValid = LoadStoreCtrl[3];

  always @* begin   
      if (LoadSoreValid) begin
        IsByteAccess = ({2'b11,LoadStoreCtrl[2:0]} == `CMD_LB )
                     | ({2'b11,LoadStoreCtrl[2:0]} == `CMD_SB )
                     | ({2'b11,LoadStoreCtrl[2:0]} == `CMD_LBU)
                     ;
        IsHalfAccess = ({2'b11,LoadStoreCtrl[2:0]} == `CMD_LH)
                     | ({2'b11,LoadStoreCtrl[2:0]} == `CMD_SH)
                     | ({2'b11,LoadStoreCtrl[2:0]} == `CMD_LHU)
                     ;
        IsWordAccess = ({2'b11,LoadStoreCtrl[2:0]} == `CMD_LW)
                     | ({2'b11,LoadStoreCtrl[2:0]} == `CMD_SW)
                     ;
      end else begin
        IsByteAccess = 1'b0;
        IsHalfAccess = 1'b0;
        IsWordAccess = 1'b0;
      end
      // Load/Store is selected based on MemWriteEn signal
      RawData[`DATA_WIDTH-1:0] = MemWriteEn ? WriteDataIn[`DATA_WIDTH-1:0]
                                            : RawLdDataIn[`DATA_WIDTH-1:0]
                                            ;
      // If Unsigned the exetsion will be done with zero
      if (UnsignedFlag) begin
        Sign[3:0] = 4'b0; 
      end else begin
        Sign[3:0] = {
                     RawData[31]     // sign bit for byte 3
                    ,RawData[23]     // sign bit for byte 2
                    ,RawData[15]     // sign bit for byte 1
                    ,RawData[7]      // sign bit for byte 0
                    }; // Possible Sign Bits
      end
      // LB/SB data adressing have a byte granularity:
      // -> 00 : Byte lsb;
      // -> 01 : Byte 2;
      // -> 10 : Byte 3;
      // -> 11 : Byte Msb
      // Setup the mask for SB/LB; LH/SH; LW/SW
      case (Addr[1:0])
        2'b00   : begin 
                    BAlgnData[`DATA_WIDTH-1:0] = {{(3*`DATA_MASK_BYTE){Sign[0]}},RawData[`DATA_MASK_BYTE-1:0]};                                              // 3B sign ext + 1B data
                    HAlgnData[`DATA_WIDTH-1:0] = {{`DATA_MASK_HALF{Sign[1]}},RawData[`DATA_MASK_HALF-1:0]};                                                  // 2B sign ext + 2B data
                  end
        2'b01   : begin
                    BAlgnData[`DATA_WIDTH-1:0] = {{(2*`DATA_MASK_BYTE){Sign[1]}},RawData[2*`DATA_MASK_BYTE-1:`DATA_MASK_BYTE],{`DATA_MASK_BYTE{Sign[1]}}};   // 2B sign ext + 1B data + 1B sign ext
                    HAlgnData[`DATA_WIDTH-1:0] = {RawData[`DATA_WIDTH-1:`DATA_MASK_HALF],{`DATA_MASK_HALF{Sign[3]}}};                                        // 2B sign ext + 2B data
                  end
        2'b10   : begin
                    BAlgnData[`DATA_WIDTH-1:0] = {{`DATA_MASK_BYTE{Sign[2]}},RawData[3*`DATA_MASK_BYTE-1:2*`DATA_MASK_BYTE],{(2*`DATA_MASK_BYTE){Sign[2]}}}; // 1B sign ext + 1B data + 2B sign ext
                    HAlgnData[`DATA_WIDTH-1:0] = `DATA_WIDTH'hffff;                                                                                          // Imposible
                  end
        2'b11   : begin
                    BAlgnData[`DATA_WIDTH-1:0] = {RawData[`DATA_WIDTH-1:3*`DATA_MASK_BYTE],{(3*`DATA_MASK_BYTE){Sign[3]}}};                                  // 1B data + 3B sign ext
                    HAlgnData[`DATA_WIDTH-1:0] = `DATA_WIDTH'hffff;                                                                                          // Imposible                    
                  end
        default : begin
                    BAlgnData[`DATA_WIDTH-1:0] = RawData[`DATA_WIDTH-1:0];
                    HAlgnData[`DATA_WIDTH-1:0] = RawData[`DATA_WIDTH-1:0];
                  end
      endcase
      
      DataMasked[`DATA_WIDTH-1:0] = ({`DATA_WIDTH{IsByteAccess}} & BAlgnData[`DATA_WIDTH-1:0])   // Create the masked data with the selected byte
                                  | ({`DATA_WIDTH{IsHalfAccess}} & HAlgnData[`DATA_WIDTH-1:0])   // Create the masked data with the selected half-word
                                  | ({`DATA_WIDTH{IsWordAccess}} & RawData[`DATA_WIDTH-1:0])     // word addrersable load/store remains unchanged
                                  ;
   
    end

    always @* begin
     
      WordAddressingErr = IsWordAccess & (|Addr[1:0]);                         // Hardware assert if a non zero addr[1:0] is detected
      HalfAddressingErr = IsHalfAccess &   Addr[1];                            // Hardware assert if 2'b10 2'b11 are detected
  
      Hwa[1:0] = {
                  WordAddressingErr,
                  HalfAddressingErr
                 }
               ;
    end
   `ifdef SIMULATION_ON
    always @* begin
      if (IsWordAccess && Addr[1:0] != 2'b00)
        $error("Unaligned word access at address offset %b", Addr[1:0]);
      if (IsHalfAccess && Addr[0] != 1'b0)
        $error("Unaligned half-word access at address offset %b", Addr[1:0]);
    end
   `endif

  endmodule

 module MEMORATE_INSTR (
    output reg   [`DATA_WIDTH-1:0] MEM_ReadData,
    output reg   [`DATA_WIDTH-1:0] MEM_ALUResult,
    output reg                     MEM_RegWrite,
    output reg     [`PC_WIDTH-1:0] MEM_Pc,
    output reg     [`ADDR_IDX-1:0] MEM_Rdest,            // here we are writing the result
    output reg               [1:0] MEM_ResultSrc,        // Control the WB mux (ID_ResultSrc flopped)
    output    [`HWA_MEM_WIDTH-1:0] MEM_Hwa,              // Hardware Assert Bus which triggers an interruption

    input                          clk,
    input                          rst, 
    input          [`PC_WIDTH-1:0] EXE_Pc,
    input                          EXE_RegWrite,
    input                          EXE_MemWriteEn,
    input                          EXE_UnsignedFlag,    
    input        [`ADDR_WIDTH-1:0] EXE_AluResult,
    input        [`DATA_WIDTH-1:0] EXE_WriteData,
    input          [`ADDR_IDX-1:0] EXE_Rdest,            // here we are writing the result
    input                    [3:0] EXE_LoadStoreCtrl,    // Go straight to Load Store module
    input                    [1:0] EXE_ResultSrc         // Control the WB mux
 );

    reg             [31:0] data_mem [0:255];
    wire [`DATA_WIDTH-1:0] RdData;           // raw and unmasked Data
    wire [`DATA_WIDTH-1:0] ReadDataOut;      // final and masked data out 
    wire [`DATA_WIDTH-1:0] DataMasked;       // masked data in
    wire                   ClkEn;
    wire             [1:0] Hwa_LdSt;
    reg                    RegWrite_d1;

    assign ClkEn =1'b1;

    LoadStore LoadStore_inst (
    .DataMasked              (DataMasked[`DATA_WIDTH-1:0]),
    .Hwa                     (Hwa_LdSt[1:0]),              // Hardware Assert from Load store Module: [1] = word misalign, [0] = half misalign
    .MemWriteEn              (EXE_MemWriteEn),
    .LoadStoreCtrl           (EXE_LoadStoreCtrl[3:0]),     // [3] = valid, [2:0] = command
    .RawLdDataIn             (RdData[`DATA_WIDTH-1:0]),
    .WriteDataIn             (EXE_WriteData[`DATA_WIDTH-1:0]),
    .UnsignedFlag            (EXE_UnsignedFlag),    
    .Addr                    (EXE_AluResult[1:0])        // Address offset for byte/half-word access
    );

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
      if (EXE_MemWriteEn) begin
        data_mem[EXE_AluResult[`RAM_ALLIGN_RANGE]][`DATA_WIDTH-1:0] <= DataMasked[`DATA_WIDTH-1:0];  // Aliniere pe 32b
      end
    end

    // Memory Read 
    assign RdData     [`DATA_WIDTH-1:0] = data_mem[EXE_AluResult[`RAM_ALLIGN_RANGE]][`DATA_WIDTH-1:0];
    // Apply Data Mask
    assign ReadDataOut[`DATA_WIDTH-1:0] = DataMasked[`DATA_WIDTH-1:0] & {`DATA_WIDTH{~EXE_MemWriteEn}};
    // Hardware Assert Bus
    assign MEM_Hwa [`HWA_MEM_WIDTH-1:0] = {                       // Add new entries on top
                                           6'h0,                  // Reserved bits
                                           Hwa_LdSt[1:0]          // Load & Store Hardware Assert
                                          }
                                        ;
    always @(posedge clk) begin
      if (rst) begin
        MEM_ReadData [`DATA_WIDTH-1:0] <= `DATA_WIDTH'h0;
        MEM_ALUResult[`DATA_WIDTH-1:0] <= `ADDR_WIDTH'h0;
        MEM_ResultSrc            [1:0] <= 2'b0;
        MEM_RegWrite                   <= 1'b0;
        MEM_Pc         [`PC_WIDTH-1:0] <= `PC_WIDTH'h0;
        MEM_Rdest      [`ADDR_IDX-1:0] <= `ADDR_IDX'h0;
      end else if (ClkEn) begin
        MEM_ReadData [`DATA_WIDTH-1:0] <= ReadDataOut  [`DATA_WIDTH-1:0];
        MEM_ALUResult[`DATA_WIDTH-1:0] <= EXE_AluResult[`ADDR_WIDTH-1:0];
        MEM_ResultSrc            [1:0] <= EXE_ResultSrc            [1:0];
        MEM_RegWrite                   <= EXE_RegWrite;
        MEM_Pc         [`PC_WIDTH-1:0] <= EXE_Pc         [`PC_WIDTH-1:0];      
        MEM_Rdest      [`ADDR_IDX-1:0] <= EXE_Rdest      [`ADDR_IDX-1:0];
      end else begin
        MEM_ReadData [`DATA_WIDTH-1:0] <= MEM_ReadData [`DATA_WIDTH-1:0];
        MEM_ALUResult[`DATA_WIDTH-1:0] <= MEM_ALUResult[`DATA_WIDTH-1:0];
        MEM_ResultSrc            [1:0] <= MEM_ResultSrc            [1:0];
        MEM_RegWrite                   <= MEM_RegWrite;
        MEM_Pc         [`PC_WIDTH-1:0] <= MEM_Pc         [`PC_WIDTH-1:0];         
        MEM_Rdest      [`ADDR_IDX-1:0] <= MEM_Rdest      [`ADDR_IDX-1:0];        
      end
    end
    // Propagare spre WB

endmodule
