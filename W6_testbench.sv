`timescale 1ns / 1ps

module cpu_tb;

    reg clk;
    reg reset;

    multicycle_cpu uut (
        .clk(clk),
        .reset(reset)
    );

    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, cpu_tb);

        clk = 0;
        reset = 1;
        #10;
        reset = 0;

        // lw $t0, 16($zero)
        uut.mem.mem_array[0] = 32'b100011_00000_01000_0000000000010000;
        
        // lw $t1, 20($zero)
        uut.mem.mem_array[1] = 32'b100011_00000_01001_0000000000010100;
        
        // add $t2, $t0, $t1
        uut.mem.mem_array[2] = 32'b000000_01000_01001_01010_00000_100000;
        
        // sw $t2, 24($zero)
        uut.mem.mem_array[3] = 32'b101011_00000_01010_0000000000011000;

        // Data initial values
        uut.mem.mem_array[4] = 32'd25;
        uut.mem.mem_array[5] = 32'd15;
        uut.mem.mem_array[6] = 32'd0;

        #300;

        $display("R8 ($t0)  = %d", uut.rf.rf[8]);
        $display("R9 ($t1)  = %d", uut.rf.rf[9]);
        $display("R10 ($t2) = %d", uut.rf.rf[10]);
        $display("Mem[24]   = %d", uut.mem.mem_array[6]);

        $finish;
    end

endmodule
