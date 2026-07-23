// ==========================================================
// Week 8: 5-Stage Pipelined i281 CPU Core
// ==========================================================

module pipelined_i281_cpu (
    input clk,
    input reset
);

    // ------------------------------------------------------
    // 1. IF Stage (Instruction Fetch)
    // ------------------------------------------------------
    reg [5:0] pc;
    wire [5:0] pc_next;
    wire [5:0] pc_seq = pc + 1'b1;
    wire [15:0] if_instruction;

    // Code Memory (Instruction Fetch)
    code_memory code_mem (
        .address(pc),
        .instruction(if_instruction)
    );

    // ------------------------------------------------------
    // IF/ID Pipeline Register
    // ------------------------------------------------------
    reg [15:0] IF_ID_instruction;
    reg [5:0]  IF_ID_pc;

    wire data_stall;
    wire branch_taken; // ID_EX_c[2] equivalent (branch taken signal)

    always @(posedge clk or posedge reset) begin
        if (reset || branch_taken) begin
            IF_ID_instruction <= 16'h0000;
            IF_ID_pc          <= 6'b000000;
        end else if (!data_stall) begin
            IF_ID_instruction <= if_instruction;
            IF_ID_pc          <= pc;
        end
    end

    // PC Update Logic
    wire [5:0] pc_branch;
    assign pc_next = branch_taken ? pc_branch : pc_seq;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 6'b100000; // Reset address
        end else if (!data_stall) begin
            pc <= pc_next;
        end
    end

    // ------------------------------------------------------
    // 2. ID Stage (Instruction Decode & Register Read)
    // ------------------------------------------------------
    wire [18:1] id_c; // Control signals array
    wire swap_en;

    // Main Control Unit Decoder
    i281_control_unit ctrl_unit (
        .opcode(IF_ID_instruction[15:12]),
        .funct(IF_ID_instruction[3:0]),
        .c(id_c),
        .swap_en(swap_en)
    );

    wire [7:0] reg_a_out, reg_b_out, reg_c_out, reg_d_out;
    wire [7:0] rf_read_data1, rf_read_data2;

    // Register File Inputs
    wire [1:0] read_reg1_sel = IF_ID_instruction[11:10];
    wire [1:0] read_reg2_sel = IF_ID_instruction[9:8];

    // Pipeline Writeback signals from MEM/WB stage
    wire MEM_WB_reg_write;
    wire [1:0] MEM_WB_write_reg;
    wire [7:0] MEM_WB_write_data;

    reg_file register_file (
        .clk(clk),
        .reg_write(MEM_WB_reg_write),
        .write_reg(MEM_WB_write_reg),
        .write_data(MEM_WB_write_data),
        .read_reg1(read_reg1_sel),
        .read_reg2(read_reg2_sel),
        .read_data1(rf_read_data1),
        .read_data2(rf_read_data2),
        .A(reg_a_out), .B(reg_b_out), .C(reg_c_out), .D(reg_d_out)
    );

    // ------------------------------------------------------
    // ID/EX Pipeline Register
    // ------------------------------------------------------
    reg [18:1] ID_EX_c;
    reg [15:0] ID_EX_instruction;
    reg [7:0]  ID_EX_reg1_out, ID_EX_reg2_out;
    reg [5:0]  ID_EX_pc;
    reg        ID_EX_swap_en;

    always @(posedge clk or posedge reset) begin
        if (reset || data_stall || branch_taken) begin
            ID_EX_c           <= 18'b0;
            ID_EX_instruction <= 16'h0000;
            ID_EX_reg1_out    <= 8'h00;
            ID_EX_reg2_out    <= 8'h00;
            ID_EX_pc          <= 6'b000000;
            ID_EX_swap_en     <= 1'b0;
        end else begin
            ID_EX_c           <= id_c;
            ID_EX_instruction <= IF_ID_instruction;
            ID_EX_reg1_out    <= rf_read_data1;
            ID_EX_reg2_out    <= rf_read_data2;
            ID_EX_pc          <= IF_ID_pc;
            ID_EX_swap_en     <= swap_en;
        end
    end

    // ------------------------------------------------------
    // 3. EX Stage (Execute & Forwarding & Swap)
    // ------------------------------------------------------
    // Data Forwarding Logic
    reg [7:0] ID_EX_reg1_forw, ID_EX_reg2_forw;
    
    wire EX_MEM_reg_write;
    wire [1:0] EX_MEM_write_reg;
    wire [7:0] EX_MEM_alu_result;

    always @(*) begin
        ID_EX_reg1_forw = ID_EX_reg1_out;
        ID_EX_reg2_forw = ID_EX_reg2_out;

        // EX Hazard (EX/MEM Forwarding)
        if (EX_MEM_reg_write) begin
            if (EX_MEM_write_reg == ID_EX_instruction[11:10])
                ID_EX_reg1_forw = EX_MEM_alu_result;
            if (EX_MEM_write_reg == ID_EX_instruction[9:8])
                ID_EX_reg2_forw = EX_MEM_alu_result;
        end

        // MEM Hazard (MEM/WB Forwarding)
        if (MEM_WB_reg_write) begin
            if ((MEM_WB_write_reg == ID_EX_instruction[11:10]) && 
                (!EX_MEM_reg_write || (EX_MEM_write_reg != ID_EX_instruction[11:10])))
                ID_EX_reg1_forw = MEM_WB_write_data;

            if ((MEM_WB_write_reg == ID_EX_instruction[9:8]) && 
                (!EX_MEM_reg_write || (EX_MEM_write_reg != ID_EX_instruction[9:8])))
                ID_EX_reg2_forw = MEM_WB_write_data;
        end
    end

    // Swap Block Application
    wire [7:0] alu_in_a, alu_in_b;
    swap_block swap_unit (
        .swap_en(ID_EX_swap_en),
        .in1(ID_EX_reg1_forw),
        .in2(ID_EX_reg2_forw),
        .out1(alu_in_a),
        .out2(alu_in_b)
    );

    // ALU Execution
    wire [7:0] alu_result;
    wire [3:0] alu_flags;

    alu main_alu (
        .a(alu_in_a),
        .b(ID_EX_c[11] ? {4'b0000, ID_EX_instruction[3:0]} : alu_in_b), // ALUSrc mux
        .select({ID_EX_c[13], ID_EX_c[12]}),
        .result(alu_result),
        .flags(alu_flags)
    );

    // Branch Condition Target Evaluation in EX
    assign pc_branch = ID_EX_instruction[5:0];
    assign branch_taken = ID_EX_c[2] && (alu_flags[0] || alu_flags[1]); // Example branch evaluation

    // ------------------------------------------------------
    // EX/MEM Pipeline Register
    // ------------------------------------------------------
    reg [18:1] EX_MEM_c;
    reg [15:0] EX_MEM_instruction;
    reg [7:0]  EX_MEM_alu_result_reg;
    reg [7:0]  EX_MEM_write_data;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            EX_MEM_c           <= 18'b0;
            EX_MEM_instruction <= 16'h0000;
            EX_MEM_alu_result_reg <= 8'h00;
            EX_MEM_write_data  <= 8'h00;
        end else begin
            EX_MEM_c           <= ID_EX_c;
            EX_MEM_instruction <= ID_EX_instruction;
            EX_MEM_alu_result_reg <= alu_result;
            EX_MEM_write_data  <= alu_in_b;
        end
    end

    assign EX_MEM_reg_write  = EX_MEM_c[10];
    assign EX_MEM_write_reg  = {EX_MEM_c[8], EX_MEM_c[9]};
    assign EX_MEM_alu_result = EX_MEM_alu_result_reg;

    // ------------------------------------------------------
    // 4. MEM Stage (Data Memory)
    // ------------------------------------------------------
    wire [7:0] dmem_read_data;

    data_memory dmem (
        .clk(clk),
        .mem_write(EX_MEM_c[17]),
        .address(EX_MEM_instruction[3:0]),
        .write_data(EX_MEM_write_data),
        .read_data(dmem_read_data)
    );

    // ------------------------------------------------------
    // MEM/WB Pipeline Register
    // ------------------------------------------------------
    reg [18:1] MEM_WB_c;
    reg [15:0] MEM_WB_instruction;
    reg [7:0]  MEM_WB_alu_out;
    reg [7:0]  MEM_WB_dmem_out;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            MEM_WB_c           <= 18'b0;
            MEM_WB_instruction <= 16'h0000;
            MEM_WB_alu_out     <= 8'h00;
            MEM_WB_dmem_out    <= 8'h00;
        end else begin
            MEM_WB_c           <= EX_MEM_c;
            MEM_WB_instruction <= EX_MEM_instruction;
            MEM_WB_alu_out     <= EX_MEM_alu_result_reg;
            MEM_WB_dmem_out    <= dmem_read_data;
        end
    end

    assign MEM_WB_reg_write = MEM_WB_c[10];
    assign MEM_WB_write_reg = {MEM_WB_c[8], MEM_WB_c[9]};
    assign MEM_WB_write_data = MEM_WB_c[15] ? MEM_WB_dmem_out : MEM_WB_alu_out; // DMEM Input Mux

    // ------------------------------------------------------
    // Hazard Detection / Stall Logic
    // ------------------------------------------------------
    reg data_stall_reg;
    always @(*) begin
        data_stall_reg = 0;
        
        // Load-Use Stall Condition
        if (ID_EX_c[17]) begin
            if (ID_EX_instruction[11:10] == IF_ID_instruction[11:10] || 
                ID_EX_instruction[11:10] == IF_ID_instruction[9:8]) begin
                data_stall_reg = 1;
            end
        end

        // Flag-Use Branch Stall Condition
        if ((IF_ID_instruction[15:13] == 3'b111) && ID_EX_c[14]) begin
            data_stall_reg = 1;
        end
    end

    assign data_stall = data_stall_reg;

endmodule

// ==========================================================
// Helper Sub-modules
// ==========================================================

module swap_block (
    input swap_en,
    input [7:0] in1,
    input [7:0] in2,
    output [7:0] out1,
    output [7:0] out2
);
    assign out1 = swap_en ? in2 : in1;
    assign out2 = swap_en ? in1 : in2;
endmodule

module code_memory (
    input [5:0] address,
    output reg [15:0] instruction
);
    reg [15:0] mem [0:63];

    always @(*) begin
        instruction = mem[address];
    end
endmodule

module data_memory (
    input clk,
    input mem_write,
    input [3:0] address,
    input [7:0] write_data,
    output reg [7:0] read_data
);
    reg [7:0] dmem [0:15];

    always @(*) begin
        read_data = dmem[address];
    end

    always @(posedge clk) begin
        if (mem_write) begin
            dmem[address] <= write_data;
        end
    end
endmodule

module reg_file (
    input clk,
    input reg_write,
    input [1:0] write_reg,
    input [7:0] write_data,
    input [1:0] read_reg1,
    input [1:0] read_reg2,
    output [7:0] read_data1,
    output [7:0] read_data2,
    output [7:0] A, B, C, D
);
    reg [7:0] rf [0:3];

    assign read_data1 = rf[read_reg1];
    assign read_data2 = rf[read_reg2];

    assign A = rf[0];
    assign B = rf[1];
    assign C = rf[2];
    assign D = rf[3];

    always @(posedge clk) begin
        if (reg_write) begin
            rf[write_reg] <= write_data;
        end
    end
endmodule

module alu (
    input [7:0] a,
    input [7:0] b,
    input [1:0] select,
    output reg [7:0] result,
    output [3:0] flags
);
    always @(*) begin
        case (select)
            2'b00: result = a + b;
            2'b01: result = a - b;
            2'b10: result = a & b;
            2'b11: result = a | b;
        endcase
    end

    assign flags[0] = (result == 0); // ZF
    assign flags[1] = result[7];    // NF
    assign flags[2] = 0;            // OF
    assign flags[3] = 0;            // CF
endmodule

module i281_control_unit (
    input [3:0] opcode,
    input [3:0] funct,
    output reg [18:1] c,
    output reg swap_en
);
    always @(*) begin
        c = 18'b0;
        swap_en = 0;

        case (opcode)
            4'b0001: begin // ADD / R-Type
                c[10] = 1; // reg_write
                c[8]  = 0; c[9] = 0;
            end
            4'b0100: begin // LOAD
                c[10] = 1; // reg_write
                c[15] = 1; // mem_to_reg
                swap_en = 1;
            end
            4'b0101: begin // STORE
                c[17] = 1; // mem_write
                swap_en = 1;
            end
            4'b0110: begin // MOVEE
                c[10] = 1;
                swap_en = 1;
            end
            default: ;
        endcase
    end
endmodule
