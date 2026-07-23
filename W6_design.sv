module multicycle_cpu (
    input clk,
    input reset
);

    wire pc_write, pc_write_cond, i_or_d, mem_read, mem_write;
    wire ir_write, mem_to_reg, alu_src_a, reg_write, reg_dst;
    wire [1:0] pc_source, alu_op, alu_src_b;

    reg [31:0] pc;
    reg [31:0] ir, mdr, a_reg, b_reg, alu_out_reg;

    wire [31:0] mem_addr = i_or_d ? alu_out_reg : pc;
    wire [31:0] mem_read_data;
    
    wire [4:0] write_reg = reg_dst ? ir[15:11] : ir[20:16];
    wire [31:0] write_back_data = mem_to_reg ? mdr : alu_out_reg;
    wire [31:0] reg_read1, reg_read2;

    wire [31:0] sign_imm = {{16{ir[15]}}, ir[15:0]};
    wire [31:0] sign_imm_sh2 = sign_imm << 2;

    reg [31:0] src_a, src_b;
    wire [2:0] alu_control;
    wire [31:0] alu_result;
    wire zero;

    wire pc_en = pc_write || (pc_write_cond && zero);

    control_fsm ctrl (
        .clk(clk),
        .reset(reset),
        .opcode(ir[31:26]),
        .pc_write(pc_write),
        .pc_write_cond(pc_write_cond),
        .i_or_d(i_or_d),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .ir_write(ir_write),
        .mem_to_reg(mem_to_reg),
        .pc_source(pc_source),
        .alu_op(alu_op),
        .alu_src_b(alu_src_b),
        .alu_src_a(alu_src_a),
        .reg_write(reg_write),
        .reg_dst(reg_dst)
    );

    unified_memory mem (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .address(mem_addr),
        .write_data(b_reg),
        .read_data(mem_read_data)
    );

    reg_file rf (
        .clk(clk),
        .reg_write(reg_write),
        .read_reg1(ir[25:21]),
        .read_reg2(ir[20:16]),
        .write_reg(write_reg),
        .write_data(write_back_data),
        .read_data1(reg_read1),
        .read_data2(reg_read2)
    );

    alu_control_unit alu_ctrl (
        .alu_op(alu_op),
        .funct(ir[5:0]),
        .alu_control(alu_control)
    );

    always @(*) begin
        src_a = alu_src_a ? a_reg : pc;
        case (alu_src_b)
            2'b00: src_b = b_reg;
            2'b01: src_b = 32'd4;
            2'b10: src_b = sign_imm;
            2'b11: src_b = sign_imm_sh2;
        endcase
    end

    alu main_alu (
        .a(src_a),
        .b(src_b),
        .alu_control(alu_control),
        .result(alu_result),
        .zero(zero)
    );

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc          <= 0;
            ir          <= 0;
            mdr         <= 0;
            a_reg       <= 0;
            b_reg       <= 0;
            alu_out_reg <= 0;
        end else begin
            if (pc_en) begin
                case (pc_source)
                    2'b00: pc <= alu_result;
                    2'b01: pc <= alu_out_reg;
                    2'b10: pc <= {pc[31:28], ir[25:0], 2'b00};
                endcase
            end

            if (ir_write) ir <= mem_read_data;
            mdr         <= mem_read_data;
            a_reg       <= reg_read1;
            b_reg       <= reg_read2;
            alu_out_reg <= alu_result;
        end
    end

endmodule


module control_fsm (
    input clk,
    input reset,
    input [5:0] opcode,
    output reg pc_write,
    output reg pc_write_cond,
    output reg i_or_d,
    output reg mem_read,
    output reg mem_write,
    output reg ir_write,
    output reg mem_to_reg,
    output reg [1:0] pc_source,
    output reg [1:0] alu_op,
    output reg [1:0] alu_src_b,
    output reg alu_src_a,
    output reg reg_write,
    output reg reg_dst
);

    localparam FETCH     = 4'd0,
               DECODE    = 4'd1,
               MEM_ADDR  = 4'd2,
               MEM_READ  = 4'd3,
               MEM_WB    = 4'd4,
               MEM_WRITE = 4'd5,
               EXEC_R    = 4'd6,
               R_WB      = 4'd7,
               BRANCH    = 4'd8,
               JUMP      = 4'd9;

    reg [3:0] state, next_state;

    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= FETCH;
        else
            state <= next_state;
    end

    always @(*) begin
        case (state)
            FETCH: next_state = DECODE;
            
            DECODE: begin
                case (opcode)
                    6'b100011, 6'b101011: next_state = MEM_ADDR;
                    6'b000000:           next_state = EXEC_R;
                    6'b000100:           next_state = BRANCH;
                    6'b000010:           next_state = JUMP;
                    default:             next_state = FETCH;
                endcase
            end

            MEM_ADDR: begin
                if (opcode == 6'b100011)     next_state = MEM_READ;
                else if (opcode == 6'b101011) next_state = MEM_WRITE;
                else                         next_state = FETCH;
            end

            MEM_READ:  next_state = MEM_WB;
            MEM_WB:    next_state = FETCH;
            MEM_WRITE: next_state = FETCH;
            EXEC_R:    next_state = R_WB;
            R_WB:      next_state = FETCH;
            BRANCH:    next_state = FETCH;
            JUMP:      next_state = FETCH;
            default:   next_state = FETCH;
        endcase
    end

    always @(*) begin
        pc_write      = 0;
        pc_write_cond = 0;
        i_or_d        = 0;
        mem_read      = 0;
        mem_write     = 0;
        ir_write      = 0;
        mem_to_reg    = 0;
        pc_source     = 2'b00;
        alu_op        = 2'b00;
        alu_src_b     = 2'b00;
        alu_src_a     = 0;
        reg_write     = 0;
        reg_dst       = 0;

        case (state)
            FETCH: begin
                mem_read  = 1;
                ir_write  = 1;
                alu_src_a = 0;
                alu_src_b = 2'b01;
                alu_op    = 2'b00;
                pc_source = 2'b00;
                pc_write  = 1;
            end

            DECODE: begin
                alu_src_a = 0;
                alu_src_b = 2'b11;
                alu_op    = 2'b00;
            end

            MEM_ADDR: begin
                alu_src_a = 1;
                alu_src_b = 2'b10;
                alu_op    = 2'b00;
            end

            MEM_READ: begin
                i_or_d   = 1;
                mem_read = 1;
            end

            MEM_WB: begin
                reg_dst    = 0;
                mem_to_reg = 1;
                reg_write  = 1;
            end

            MEM_WRITE: begin
                i_or_d    = 1;
                mem_write = 1;
            end

            EXEC_R: begin
                alu_src_a = 1;
                alu_src_b = 2'b00;
                alu_op    = 2'b10;
            end

            R_WB: begin
                reg_dst    = 1;
                mem_to_reg = 0;
                reg_write  = 1;
            end

            BRANCH: begin
                alu_src_a     = 1;
                alu_src_b     = 2'b00;
                alu_op        = 2'b01;
                pc_source     = 2'b01;
                pc_write_cond = 1;
            end

            JUMP: begin
                pc_source = 2'b10;
                pc_write  = 1;
            end
        endcase
    end

endmodule


module unified_memory (
    input clk,
    input mem_read,
    input mem_write,
    input [31:0] address,
    input [31:0] write_data,
    output reg [31:0] read_data
);
    reg [31:0] mem_array [0:255];

    always @(*) begin
        if (mem_read)
            read_data = mem_array[address >> 2];
        else
            read_data = 32'b0;
    end

    always @(posedge clk) begin
        if (mem_write) begin
            mem_array[address >> 2] <= write_data;
        end
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
    reg [31:0] rf [0:31];

    assign read_data1 = (read_reg1 == 0) ? 32'b0 : rf[read_reg1];
    assign read_data2 = (read_reg2 == 0) ? 32'b0 : rf[read_reg2];

    always @(posedge clk) begin
        if (reg_write && (write_reg != 0)) begin
            rf[write_reg] <= write_data;
        end
    end
endmodule


module alu_control_unit (
    input [1:0] alu_op,
    input [5:0] funct,
    output reg [2:0] alu_control
);
    always @(*) begin
        case (alu_op)
            2'b00: alu_control = 3'b010;
            2'b01: alu_control = 3'b110;
            2'b10: begin
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
