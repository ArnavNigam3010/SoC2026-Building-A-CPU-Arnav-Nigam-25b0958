module datapath (
    input clk,
    input reset,
    input [31:0] instr,
    input [31:0] read_data,
    output [31:0] alu_out,
    output [31:0] write_data,
    output mem_write,
    output mem_read
);

    // Control wires
    wire reg_dst, alu_src, mem_to_reg, reg_write, branch;
    wire [1:0] alu_op;
    wire [2:0] alu_control;
    wire zero;

    // Control Unit (from Week 4)
    decoder main_decoder (
        .opcode(instr[31:26]),
        .reg_dst(reg_dst),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .alu_op(alu_op)
    );

    // ALU Control Unit
    alu_control_unit alu_ctrl (
        .alu_op(alu_op),
        .funct(instr[5:0]),
        .alu_control(alu_control)
    );

    // Register File Mux and Wires
    wire [4:0] write_reg = reg_dst ? instr[15:11] : instr[20:16];
    wire [31:0] reg_data1, reg_data2;
    wire [31:0] reg_write_data = mem_to_reg ? read_data : alu_out;

    reg_file register_file (
        .clk(clk),
        .reg_write(reg_write),
        .read_reg1(instr[25:21]),
        .read_reg2(instr[20:16]),
        .write_reg(write_reg),
        .write_data(reg_write_data),
        .read_data1(reg_data1),
        .read_data2(reg_data2)
    );

    // Sign Extension
    wire [31:0] sign_imm = {{16{instr[15]}}, instr[15:0]};

    // ALU Source Mux and Wires
    wire [31:0] src_b = alu_src ? sign_imm : reg_data2;
    assign write_data = reg_data2; 

    // Execution Unit
    alu main_alu (
        .a(reg_data1),
        .b(src_b),
        .alu_control(alu_control),
        .result(alu_out),
        .zero(zero)
    );

endmodule

// ==========================================================
// Helper Sub-modules
// ==========================================================

module alu_control_unit (
    input [1:0] alu_op,
    input [5:0] funct,
    output reg [2:0] alu_control
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_control = 3'b010; // add for lw/sw
            2'b01: alu_control = 3'b110; // sub for beq
            2'b10: begin                 // R-type
                case (funct)
                    6'b100000: alu_control = 3'b010; // add
                    6'b100010: alu_control = 3'b110; // sub
                    6'b100100: alu_control = 3'b000; // and
                    6'b100101: alu_control = 3'b001; // or
                    default:   alu_control = 3'b010;
                endcase
            end
            default: alu_control = 3'b010;
        endcase
    end
endmodule

module reg_file (
    input clk,
    input reg_write,
    input [4:0] read_reg1,
    input [4:0] read_reg2,
    input [4:0] write_reg,
    input [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2
);
    reg [31:0] rf [31:0];

    assign read_data1 = (read_reg1 == 0) ? 32'b0 : rf[read_reg1];
    assign read_data2 = (read_reg2 == 0) ? 32'b0 : rf[read_reg2];

    always @(posedge clk) begin
        if (reg_write && (write_reg != 0)) begin
            rf[write_reg] <= write_data;
        end
    end
endmodule

module alu (
    input [31:0] a,
    input [31:0] b,
    input [2:0] alu_control,
    output reg [31:0] result,
    output zero
);
    always @(*) begin
        case (alu_control)
            3'b000: result = a & b;
            3'b001: result = a | b;
            3'b010: result = a + b;
            3'b110: result = a - b;
            default: result = 32'b0;
        endcase
    end

    assign zero = (result == 0);
endmodule
