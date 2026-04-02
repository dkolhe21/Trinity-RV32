`default_nettype none

`timescale 1 ns / 1 ps

module rv32i_jtag_tb;
	reg clock;
    reg RSTB;
	reg CSB;

	reg power1, power2;

	wire gpio;
	wire uart_tx;
	wire [37:0] mprj_io;
	wire [15:0] checkbits;

	// JTAG signals mapped to mprj_io
	reg jtag_tck;
	reg jtag_tms;
	reg jtag_tdi;
	reg jtag_trst_n;
	wire jtag_tdo;

	assign mprj_io[0] = jtag_tck;
	assign mprj_io[1] = jtag_tms;
	assign mprj_io[2] = jtag_tdi;
	assign mprj_io[4] = jtag_trst_n;
	assign jtag_tdo   = mprj_io[3];

	// BIST signals mapped to mprj_io
	reg bist_mode_ext;
	wire bist_done_ext;
	wire bist_pass_ext;

	assign mprj_io[5] = bist_mode_ext;
	assign bist_done_ext = mprj_io[6];
	assign bist_pass_ext = mprj_io[7];

	assign checkbits  = mprj_io[31:16];
	assign uart_tx = mprj_io[6];

	always #12.5 clock <= (clock === 1'b0);

	initial begin
		clock = 0;
		jtag_tck = 0;
		jtag_tms = 1;
		jtag_tdi = 0;
		jtag_trst_n = 0;
		bist_mode_ext = 0;
	end

	`ifdef ENABLE_SDF
		initial begin
			$sdf_annotate("../../../sdf/user_proj_example.sdf", uut.mprj) ;
			$sdf_annotate("../../../sdf/user_project_wrapper.sdf", uut.mprj.mprj) ;
			$sdf_annotate("../../../mgmt_core_wrapper/sdf/DFFRAM.sdf", uut.soc.DFFRAM_0) ;
			$sdf_annotate("../../../mgmt_core_wrapper/sdf/mgmt_core.sdf", uut.soc.core) ;
			$sdf_annotate("../../../caravel/sdf/housekeeping.sdf", uut.housekeeping) ;
			$sdf_annotate("../../../caravel/sdf/chip_io.sdf", uut.padframe) ;
			$sdf_annotate("../../../caravel/sdf/mprj_logic_high.sdf", uut.mgmt_buffers.mprj_logic_high_inst) ;
			$sdf_annotate("../../../caravel/sdf/mprj2_logic_high.sdf", uut.mgmt_buffers.mprj2_logic_high_inst) ;
			$sdf_annotate("../../../caravel/sdf/mgmt_protect_hv.sdf", uut.mgmt_buffers.powergood_check) ;
			$sdf_annotate("../../../caravel/sdf/mgmt_protect.sdf", uut.mgmt_buffers) ;
			$sdf_annotate("../../../caravel/sdf/caravel_clocking.sdf", uut.clocking) ;
			$sdf_annotate("../../../caravel/sdf/digital_pll.sdf", uut.pll) ;
			$sdf_annotate("../../../caravel/sdf/xres_buf.sdf", uut.rstb_level) ;
			$sdf_annotate("../../../caravel/sdf/user_id_programming.sdf", uut.user_id_value) ;
			$sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_1[0] ) ;
			$sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_1[1] ) ;
			$sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_2[0] ) ;
			$sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_2[1] ) ;
			$sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_bidir_2[2] ) ;
			$sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[0] ) ;
			$sdf_annotate("../../../caravel/sdf/gpio_control_block.sdf", uut.\gpio_control_in_1[1] ) ;
		end
	`endif 

	initial begin
		$dumpfile("rv32i_jtag.vcd");
		$dumpvars(0, rv32i_jtag_tb);

		// Repeat cycles of 1000 clock edges as needed to complete testbench
		repeat (350) begin
			repeat (1000) @(posedge clock);
		end
		$display("%c[1;31m",27);
		`ifdef GL
			$display ("Monitor: Timeout, Test (GL) Failed");
		`else
			$display ("Monitor: Timeout, Test (RTL) Failed");
		`endif
		$display("%c[0m",27);
		$finish;
	end

	// Test sequence
	reg [31:0] read_idcode;
	initial begin
		wait(checkbits == 16'hAB40);
		$display("Management SoC has configured the GPIOs. Starting JTAG Test...");
		
		#100;
		jtag_trst_n = 1;
		#100;
		
		// Reset TAP (5 clocks with TMS=1)
		repeat (5) begin
			jtag_tms = 1;
			#50 jtag_tck = 1; #50 jtag_tck = 0;
		end

		// Goto Shift-DR (IDCODE is default)
		// Run-Test/Idle
		jtag_tms = 0; #50 jtag_tck = 1; #50 jtag_tck = 0;
		// Select-DR-Scan
		jtag_tms = 1; #50 jtag_tck = 1; #50 jtag_tck = 0;
		// Capture-DR
		jtag_tms = 0; #50 jtag_tck = 1; #50 jtag_tck = 0;
		// Shift-DR
		jtag_tms = 0; #50 jtag_tck = 1; #50 jtag_tck = 0;

		// Read 32 bits
		read_idcode = 32'b0;
		for (integer i = 0; i < 32; i = i + 1) begin
			if (i == 31) jtag_tms = 1; // Exit-DR on last bit
			else         jtag_tms = 0;
			
			#25 read_idcode[i] = jtag_tdo; // sample in the middle of TCK low
			#25 jtag_tck = 1; #50 jtag_tck = 0;
		end

		$display("Read IDCODE: 0x%08h", read_idcode);
		if (read_idcode == 32'h00000001) begin
			$display("Test Passed!");
		end else begin
			$display("Test Failed! Expected 0x00000001");
		end

		#2000;
		$finish;
	end

	initial begin
		RSTB <= 1'b0;
		CSB  <= 1'b1;		// Force CSB high
		#2000;
		RSTB <= 1'b1;	    	// Release reset
		#170000;
		CSB = 1'b0;		// CSB can be released
	end

	initial begin		// Power-up sequence
		power1 <= 1'b0;
		power2 <= 1'b0;
		#200;
		power1 <= 1'b1;
		#200;
		power2 <= 1'b1;
	end

	wire flash_csb;
	wire flash_clk;
	wire flash_io0;
	wire flash_io1;

	wire VDD1V8;
	wire VDD3V3;
	wire VSS;
    
	assign VDD3V3 = power1;
	assign VDD1V8 = power2;
	assign VSS = 1'b0;

	// Removed hardcoded mprj_io[3]=1 and mprj_io[0]=0 from original la_test!

	caravel uut (
		.vddio	  (VDD3V3),
		.vddio_2  (VDD3V3),
		.vssio	  (VSS),
		.vssio_2  (VSS),
		.vdda	  (VDD3V3),
		.vssa	  (VSS),
		.vccd	  (VDD1V8),
		.vssd	  (VSS),
		.vdda1    (VDD3V3),
		.vdda1_2  (VDD3V3),
		.vdda2    (VDD3V3),
		.vssa1	  (VSS),
		.vssa1_2  (VSS),
		.vssa2	  (VSS),
		.vccd1	  (VDD1V8),
		.vccd2	  (VDD1V8),
		.vssd1	  (VSS),
		.vssd2	  (VSS),
		.clock    (clock),
		.gpio     (gpio),
		.mprj_io  (mprj_io),
		.flash_csb(flash_csb),
		.flash_clk(flash_clk),
		.flash_io0(flash_io0),
		.flash_io1(flash_io1),
		.resetb	  (RSTB)
	);

	spiflash #(
		.FILENAME("rv32i_jtag.hex")
	) spiflash (
		.csb(flash_csb),
		.clk(flash_clk),
		.io0(flash_io0),
		.io1(flash_io1),
		.io2(),			// not used
		.io3()			// not used
	);

endmodule
`default_nettype wire
