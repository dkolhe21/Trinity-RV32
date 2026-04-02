`timescale 1ns/1ps
module tb_bist_debug;
    parameter DEPTH = 4;
    parameter ADDR_BITS = 2;
    reg clk, rst_n, bist_start;
    wire bist_done, bist_pass, imem_fail, dmem_fail;
    wire imem_bist_en, imem_bist_we;
    wire [ADDR_BITS-1:0] imem_bist_addr;
    wire [31:0] imem_bist_wdata;
    wire [31:0] imem_bist_rdata;
    wire dmem_bist_en, dmem_bist_we;
    wire [ADDR_BITS-1:0] dmem_bist_addr;
    wire [31:0] dmem_bist_wdata;
    wire [31:0] dmem_bist_rdata;

    bist_ctrl #(.DEPTH(DEPTH), .ADDR_BITS(ADDR_BITS)) uut (
        .clk(clk), .rst_n(rst_n), .bist_start(bist_start),
        .bist_done(bist_done), .bist_pass(bist_pass),
        .imem_fail(imem_fail), .dmem_fail(dmem_fail),
        .imem_bist_en(imem_bist_en), .imem_bist_addr(imem_bist_addr),
        .imem_bist_wdata(imem_bist_wdata), .imem_bist_we(imem_bist_we),
        .imem_bist_rdata(imem_bist_rdata),
        .dmem_bist_en(dmem_bist_en), .dmem_bist_addr(dmem_bist_addr),
        .dmem_bist_wdata(dmem_bist_wdata), .dmem_bist_we(dmem_bist_we),
        .dmem_bist_rdata(dmem_bist_rdata)
    );

    reg [31:0] imem [0:DEPTH-1];
    reg [31:0] dmem [0:DEPTH-1];
    reg [31:0] imem_rdata_q, dmem_rdata_q;

    always @(posedge clk) begin
        if (imem_bist_en) begin
            if (imem_bist_we) imem[imem_bist_addr] <= imem_bist_wdata;
            imem_rdata_q <= imem[imem_bist_addr];
        end
    end
    always @(posedge clk) begin
        if (dmem_bist_en) begin
            if (dmem_bist_we) dmem[dmem_bist_addr] <= dmem_bist_wdata;
            dmem_rdata_q <= dmem[dmem_bist_addr];
        end
    end
    assign imem_bist_rdata = imem_rdata_q;
    assign dmem_bist_rdata = dmem_rdata_q;

    always #5 clk = ~clk;
    integer cyc;
    
    // Monitor BIST FSM
    always @(posedge clk) begin
        if (uut.state_q != 0 && uut.state_q != 8)
            $display("cyc=%3d st=%0d addr=%0d mem_sel=%0d march=%0d en=%b we=%b wdata=%08h rdata=%08h fail=%b",
                cyc, uut.state_q, uut.addr_q, uut.mem_sel_q, uut.march_q,
                imem_bist_en, imem_bist_we, imem_bist_wdata, imem_bist_rdata, uut.fail_flag_q);
    end

    initial begin
        clk=0; rst_n=0; bist_start=0;
        #20; rst_n=1;
        @(posedge clk); bist_start=1; @(posedge clk); bist_start=0;
        for (cyc=0; cyc<200 && !bist_done; cyc=cyc+1) @(posedge clk);
        $display("DONE: pass=%b imem_fail=%b dmem_fail=%b cycles=%0d", bist_pass, imem_fail, dmem_fail, cyc);
        $finish;
    end
endmodule
