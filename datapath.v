// 1. MAIN TOP-LEVEL DATAPATH
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

    wire reg_dst, alu_src, mem_to_reg, reg_write, branch;
    wire [1:0] alu_op;
    wire [2:0] alu_control;
    wire zero;

    // Control Unit Decoder
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

    // Register File Infrastructure
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

    // Sign Extension 16 to 32 bits
    wire [31:0] sign_imm = {{16{instr[15]}}, instr[15:0]};

    // ALU Path Routing
    wire [31:0] src_b = alu_src ? sign_imm : reg_data2;
    assign write_data = reg_data2; 

    // Execution Core
    alu main_alu (
        .a(reg_data1),
        .b(src_b),
        .alu_control(alu_control),
        .result(alu_out),
        .zero(zero)
    );

endmodule

// 2. INSTRUCTION DECODER (Truth-Table Compliant)
module decoder (
    input [5:0] opcode,
    output reg reg_dst,
    output reg alu_src,
    output reg mem_to_reg,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg branch,
    output reg [1:0] alu_op
);

    always @(*) begin
        // Reset every single line to prevent latch generation/state leakage
        reg_dst    = 0;
        alu_src    = 0;
        mem_to_reg = 0;
        reg_write  = 0;
        mem_read   = 0;
        mem_write  = 0;
        branch     = 0;
        alu_op     = 2'b00;

        case (opcode)
            6'b000000: begin // R-type
                reg_dst   = 1;
                reg_write = 1;
                alu_op    = 2'b10;
            end
            6'b100011: begin // lw
                reg_dst    = 0; // Explicitly pull rt path
                alu_src    = 1;
                mem_to_reg = 1;
                reg_write  = 1;
                mem_read   = 1;
            end
            6'b101011: begin // sw
                reg_dst    = 0; 
                alu_src    = 1;
                mem_to_reg = 0; 
                reg_write  = 0; // Fixed: Protect RF from garbage overwrite
                mem_write  = 1;
            end
            6'b000100: begin // beq
                branch = 1;
                alu_op = 2'b01;
            end
            default: begin
                // Safe defaults maintained
            end
        endcase
    end
endmodule

// 3. ALU CONTROL UNIT
module alu_control_unit (
    input [1:0] alu_op,
    input [5:0] funct,
    output reg [2:0] alu_control
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_control = 3'b010; // add for memory addresses
            2'b01: alu_control = 3'b110; // subtract for comparisons
            2'b10: begin                 // R-types
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

// 4. REGISTER FILE
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

    // Constrain address 0 to constant zero ground
    assign read_data1 = (read_reg1 == 0) ? 32'b0 : rf[read_reg1];
    assign read_data2 = (read_reg2 == 0) ? 32'b0 : rf[read_reg2];

    always @(posedge clk) begin
        if (reg_write && (write_reg != 0)) begin
            rf[write_reg] <= write_data;
        end
    end
endmodule

// 5. ALU
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
