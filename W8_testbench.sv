`timescale 1ns / 1ps

module pipelined_cpu_tb;

    reg clk;
    reg reset;

    // Instantiate the CPU Core
    pipelined_i281_cpu uut (
        .clk(clk),
        .reset(reset)
    );

    // Clock Generation (10ns period)
    always #5 clk = ~clk;

    initial begin
        // VCD Waveform Output Setup
        $dumpfile("dump.vcd");
        $dumpvars(0, pipelined_cpu_tb);

        // Signal Initialization
        clk   = 0;
        reset = 1;
        #10;
        reset = 0;

        // --------------------------------------------------
        // 1. Seed Unsorted Array into Data Memory
        // --------------------------------------------------
        uut.dmem.dmem[0] = 8'd42;
        uut.dmem.dmem[1] = 8'd12;
        uut.dmem.dmem[2] = 8'd88;
        uut.dmem.dmem[3] = 8'd05;

        // --------------------------------------------------
        // 2. Load i281 Instructions starting at PC = 32 (6'b100000)
        // --------------------------------------------------
        uut.code_mem.mem[32] = 16'h4000; // Load element 0
        uut.code_mem.mem[33] = 16'h4101; // Load element 1
        uut.code_mem.mem[34] = 16'h1001; // Compare / Add ops
        uut.code_mem.mem[35] = 16'h5000; // Store back

        // Pad trailing addresses with NOPs (0x0000) so operations clear WB stage
        uut.code_mem.mem[36] = 16'h0000;
        uut.code_mem.mem[37] = 16'h0000;
        uut.code_mem.mem[38] = 16'h0000;

        // Run simulation for enough cycles
        #500;

        // --------------------------------------------------
        // 3. Print Memory & Register Results
        // --------------------------------------------------
        $display("========================================");
        $display("       PIPELINED CPU TESTBENCH OUTPUT   ");
        $display("========================================");
        $display("Data Memory[0] = %d", uut.dmem.dmem[0]);
        $display("Data Memory[1] = %d", uut.dmem.dmem[1]);
        $display("Data Memory[2] = %d", uut.dmem.dmem[2]);
        $display("Data Memory[3] = %d", uut.dmem.dmem[3]);
        $display("----------------------------------------");
        $display("Register A (0) = %d", uut.register_file.rf[0]);
        $display("Register B (1) = %d", uut.register_file.rf[1]);
        $display("Register C (2) = %d", uut.register_file.rf[2]);
        $display("Register D (3) = %d", uut.register_file.rf[3]);
        $display("========================================");

        $finish;
    end

endmodule
