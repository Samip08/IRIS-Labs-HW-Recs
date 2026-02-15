module rvsoc (
	input clk,
	input resetn,
	input sensor_clk,

	output        iomem_valid,
	input         iomem_ready,
	output [ 3:0] iomem_wstrb,
	output [31:0] iomem_addr,
	output [31:0] iomem_wdata,
	input  [31:0] iomem_rdata,

	input  irq_5,
	input  irq_6,
	input  irq_7,

	output ser_tx,
	input  ser_rx,

	output flash_csb,
	output flash_clk,

	output flash_io0_oe,
	output flash_io1_oe,
	output flash_io2_oe,
	output flash_io3_oe,

	output flash_io0_do,
	output flash_io1_do,
	output flash_io2_do,
	output flash_io3_do,

	input  flash_io0_di,
	input  flash_io1_di,
	input  flash_io2_di,
	input  flash_io3_di
);
	parameter [0:0] BARREL_SHIFTER = 1;
	parameter [0:0] ENABLE_MUL = 1;
	parameter [0:0] ENABLE_DIV = 1;
	parameter [0:0] ENABLE_FAST_MUL = 0;
	parameter [0:0] ENABLE_COMPRESSED = 1;
	parameter [0:0] ENABLE_COUNTERS = 1;
	parameter [0:0] ENABLE_IRQ_QREGS = 0;

	parameter integer MEM_WORDS = 256;
	parameter [31:0] STACKADDR = (4*MEM_WORDS);
	parameter [31:0] PROGADDR_RESET = 32'h 0010_0000;
	parameter [31:0] PROGADDR_IRQ = 32'h 0000_0000;

	reg [31:0] irq;
	wire irq_stall = 0;
	wire irq_uart = 0;

	always @* begin
		irq = 0;
		irq[3] = irq_stall;
		irq[4] = irq_uart;
		irq[5] = irq_5;
		irq[6] = irq_6;
		irq[7] = irq_7;
	end

	wire mem_valid;
	wire mem_instr;
	wire mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	wire [31:0] mem_rdata;

	wire spimem_ready;
	wire [31:0] spimem_rdata;

	reg ram_ready;
	wire [31:0] ram_rdata;

	assign iomem_valid = mem_valid && (mem_addr[31:24] > 8'h 01);
	assign iomem_wstrb = mem_wstrb;
	assign iomem_addr = mem_addr;
	assign iomem_wdata = mem_wdata;

	wire spimemio_cfgreg_sel = mem_valid && (mem_addr == 32'h 0200_0000);
	wire [31:0] spimemio_cfgreg_do;

	wire        simpleuart_reg_div_sel = mem_valid && (mem_addr == 32'h 0200_0004);
	wire [31:0] simpleuart_reg_div_do;

	wire        simpleuart_reg_dat_sel = mem_valid && (mem_addr == 32'h 0200_0008);
	wire [31:0] simpleuart_reg_dat_do;
	wire        simpleuart_reg_dat_wait;

	wire [31:0] dataproc_rdata;
	wire dataproc_sel = mem_valid && (mem_addr == 32'h0200000C);

	assign mem_ready =
    (iomem_valid && iomem_ready) ||
    spimem_ready ||
    ram_ready ||
    spimemio_cfgreg_sel ||
    simpleuart_reg_div_sel ||
    (simpleuart_reg_dat_sel && !simpleuart_reg_dat_wait)||
	dataproc_sel;

	assign mem_rdata =
    (iomem_valid && iomem_ready) ? iomem_rdata :
    spimem_ready                ? spimem_rdata :
    ram_ready                   ? ram_rdata :
    spimemio_cfgreg_sel         ? spimemio_cfgreg_do :
    simpleuart_reg_div_sel      ? simpleuart_reg_div_do :
    simpleuart_reg_dat_sel      ? simpleuart_reg_dat_do :
	dataproc_sel            ? dataproc_rdata        :
    32'h0;

	picorv32 #(
		.STACKADDR(STACKADDR),
		.PROGADDR_RESET(PROGADDR_RESET),
		.PROGADDR_IRQ(PROGADDR_IRQ),
		.BARREL_SHIFTER(BARREL_SHIFTER),
		.COMPRESSED_ISA(ENABLE_COMPRESSED),
		.ENABLE_COUNTERS(ENABLE_COUNTERS),
		.ENABLE_MUL(ENABLE_MUL),
		.ENABLE_DIV(ENABLE_DIV),
		.ENABLE_FAST_MUL(ENABLE_FAST_MUL),
		.ENABLE_IRQ(1),
		.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS)
	) cpu (
		.clk         (clk),
		.resetn      (resetn),
		.mem_valid   (mem_valid),
		.mem_instr   (mem_instr),
		.mem_ready   (mem_ready),
		.mem_addr    (mem_addr),
		.mem_wdata   (mem_wdata),
		.mem_wstrb   (mem_wstrb),
		.mem_rdata   (mem_rdata),
		.irq         (irq)
	);

	spimemio spimemio (
		.clk    (clk),
		.resetn (resetn),
		.valid  (mem_valid && mem_addr >= 4*MEM_WORDS && mem_addr < 32'h 0200_0000),
		.ready  (spimem_ready),
		.addr   (mem_addr[23:0]),
		.rdata  (spimem_rdata),

		.flash_csb    (flash_csb),
		.flash_clk    (flash_clk),

		.flash_io0_oe (flash_io0_oe),
		.flash_io1_oe (flash_io1_oe),
		.flash_io2_oe (flash_io2_oe),
		.flash_io3_oe (flash_io3_oe),

		.flash_io0_do (flash_io0_do),
		.flash_io1_do (flash_io1_do),
		.flash_io2_do (flash_io2_do),
		.flash_io3_do (flash_io3_do),

		.flash_io0_di (flash_io0_di),
		.flash_io1_di (flash_io1_di),
		.flash_io2_di (flash_io2_di),
		.flash_io3_di (flash_io3_di),

		.cfgreg_we(spimemio_cfgreg_sel ? mem_wstrb : 4'b 0000),
		.cfgreg_di(mem_wdata),
		.cfgreg_do(spimemio_cfgreg_do)
	);

	simpleuart simpleuart (
		.clk         (clk),
		.resetn      (resetn),

		.ser_tx      (ser_tx),
		.ser_rx      (ser_rx),

		.reg_div_we  (simpleuart_reg_div_sel ? mem_wstrb : 4'b 0000),
		.reg_div_di  (mem_wdata),
		.reg_div_do  (simpleuart_reg_div_do),

		.reg_dat_we  (simpleuart_reg_dat_sel ? mem_wstrb[0] : 1'b 0),
		.reg_dat_re  (simpleuart_reg_dat_sel && !mem_wstrb),
		.reg_dat_di  (mem_wdata),
		.reg_dat_do  (simpleuart_reg_dat_do),
		.reg_dat_wait(simpleuart_reg_dat_wait)
	);

	image_engine_soc_top my_engine (
    .clk(clk),
    .rstn(resetn),
    .sensor_clk(sensor_clk), 
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_wstrb(dataproc_sel ? mem_wstrb : 4'b0000),
    .mem_sel(dataproc_sel),
    .mem_rdata(dataproc_rdata)
);

	//----------------------------------------------------------------

	always @(posedge clk)
		ram_ready <= mem_valid && !mem_ready && mem_addr < 4*MEM_WORDS;

	soc_mem #(
		.WORDS(MEM_WORDS)
	) memory (
		.clk(clk),
		.wen((mem_valid && !mem_ready && mem_addr < 4*MEM_WORDS) ? mem_wstrb : 4'b0),
		.addr(mem_addr[23:2]),
		.wdata(mem_wdata),
		.rdata(ram_rdata)
	);
endmodule

module soc_mem #(
	parameter integer WORDS = 256
) (
	input clk,
	input [3:0] wen,
	input [21:0] addr,
	input [31:0] wdata,
	output reg [31:0] rdata
);
	reg [31:0] mem [0:WORDS-1];

	always @(posedge clk) begin
		rdata <= mem[addr];
		if (wen[0]) mem[addr][ 7: 0] <= wdata[ 7: 0];
		if (wen[1]) mem[addr][15: 8] <= wdata[15: 8];
		if (wen[2]) mem[addr][23:16] <= wdata[23:16];
		if (wen[3]) mem[addr][31:24] <= wdata[31:24];
	end
endmodule

module image_engine_soc_top (
    input clk,          
    input rstn,         
    input sensor_clk,   
    
    input [31:0] mem_addr,
    input [31:0] mem_wdata,
    input [3:0]  mem_wstrb,
    input        mem_sel,   
    output [31:0] mem_rdata
);

    reg [1:0]  reg_mode;
    reg [71:0] reg_kernel;
	reg reg_ready_in;
    
    always @(posedge clk) begin
        if (!rstn) begin
            reg_mode <= 2'b00;        
            reg_ready_in <= 1'b1;
            reg_kernel <= 72'h010101010101010101; 
        end else if (mem_sel && |mem_wstrb) begin
            if (mem_addr[3:0] == 4'h0) begin
                reg_mode     <= mem_wdata[1:0]; 
                reg_ready_in <= mem_wdata[2];
            end
        end
    end

    wire [7:0] prod_pixel, fifo_pixel, proc_pixel;
    wire prod_valid, fifo_empty, fifo_full, proc_valid, proc_status, proc_ready_out;
    
    // Simple: read when FIFO has data
    wire fifo_read = !fifo_empty;
    
    // Module 3: Producer
    data_producer #(.IMAGE_SIZE(1024)) producer_inst (
        .sensor_clk(sensor_clk),
        .rst_n(rstn),
        .ready(!fifo_full),
        .pixel(prod_pixel),
        .valid(prod_valid)
    );

    // Module 2: FIFO
    async_fifo fifo_inst (
        .wclk(sensor_clk), .wrst_n(rstn), .wr_en(prod_valid && !fifo_full), .wdata(prod_pixel),
        .rclk(clk),        .rrst_n(rstn), .rd_en(fifo_read), .rdata(fifo_pixel),
        .full(fifo_full),  .empty(fifo_empty)
    );

    // Module 1: Processor - always ready to process
    data_proc processor_inst (
        .clk(clk), .rstn(rstn),
        .pixel_in(fifo_pixel),
        .valid_in(fifo_read),
        .ready_in(1'b1),  
        .mode(reg_mode),
        .kernel(reg_kernel),
        .pixel_out(proc_pixel),
        .ready_out(proc_ready_out),
        .valid_out(proc_valid),
        .status(proc_status)
    );

    // 3. Bus Read Logic (Hardware -> CPU)
    // CPU reads from 0x0200_000c
    // bit [7:0]   : Processed Pixel
    // bit [8]     : Valid Flag
    // bit [9]     : Status (Warm-up flag)
	assign mem_rdata = {22'b0, proc_status, proc_valid, proc_pixel};
endmodule