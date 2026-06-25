`timescale 1ns / 1ps

module datapath_tb;

    reg clk;
    reg reset;
    reg [31:0] instr;
    reg [31:0] read_data;

    wire [31:0] alu_out;
    wire [31:0] write_data;
    wire mem_write;
    wire mem_read;

    datapath uut (
        .clk(clk),
        .reset(reset),
        .instr(instr),
        .read_data(read_data),
        .alu_out(alu_out),
        .write_data(write_data),
        .mem_write(mem_write),
        .mem_read(mem_read)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        instr = 0;
        read_data = 0;
        #10;
        
        reset = 0;

        // 1. ADD: add $t0, $s1, $s2
        instr = 32'b000000_10001_10010_01000_00000_100000; 
        #10;

        // 2. LW: lw $t1, 4($s3)
        instr = 32'b100011_10011_01001_0000000000000100;
        read_data = 32'hA5A5A5A5; 
        #10;

        // 3. SW: sw $t1, 8($s4)
        instr = 32'b101011_10100_01001_0000000000001000;
        #10;

        $finish;
    end

endmodule
