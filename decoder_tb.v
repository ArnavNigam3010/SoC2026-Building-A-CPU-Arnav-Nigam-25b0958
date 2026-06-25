`timescale 1ns / 1ps

module decoder_tb;

    reg [5:0] opcode;
    wire reg_dst;
    wire alu_src;
    wire mem_to_reg;
    wire reg_write;
    wire mem_read;
    wire mem_write;
    wire branch;
    wire [1:0] alu_op;

    decoder uut (
        .opcode(opcode),
        .reg_dst(reg_dst),
        .alu_src(alu_src),
        .mem_to_reg(mem_to_reg),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .alu_op(alu_op)
    );

    initial begin
        $monitor("Time=%0dns | Op=%b | RegDst=%b ALUSrc=%b MemToReg=%b RegWr=%b MemRd=%b MemWr=%b Branch=%b ALUOp=%b", 
                 $time, opcode, reg_dst, alu_src, mem_to_reg, reg_write, mem_read, mem_write, branch, alu_op);

        // Run through each instruction from the table
        opcode = 6'b000000; #10; // R-type
        opcode = 6'b100011; #10; // lw
        opcode = 6'b101011; #10; // sw
        opcode = 6'b000100; #10; // beq
        opcode = 6'b111111; #10; // default check
        
        $finish;
    end

endmodule
