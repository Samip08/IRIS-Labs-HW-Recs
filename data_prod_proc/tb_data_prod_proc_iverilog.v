`timescale 1ns/1ps

module tb_data_prod_proc;
    
    reg clk = 0;
    reg sensor_clk = 0;
    
    always #5 clk = ~clk;            
    always #2.5 sensor_clk = ~sensor_clk; 

    reg [5:0] r_cnt = 0;
    reg [5:0] s_cnt = 0;
    wire rstn = &r_cnt;       // Processing domain reset
    wire srstn = &s_cnt;      // Sensor domain reset

    always @(posedge clk) if(!rstn) r_cnt <= r_cnt + 1'b1;
    always @(posedge sensor_clk) if(!srstn) s_cnt <= s_cnt + 1'b1;

    wire [7:0] s_pixel;      // From Producer
    wire       s_valid;      
    wire [7:0] f_pixel;      // From FIFO
    wire       f_empty, f_full;
    wire [7:0] p_out;        // From Processor
    wire       p_valid;      
    wire       p_ready;      // Ready from Processor to FIFO
    wire       status;       // Processor busy status
    
    reg [1:0]  mode = 2'b00;
    reg [71:0] kernel = {8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1}; // All 1s

    initial begin
        integer f, i;
        f = $fopen("image.hex", "w");
        for (i=0; i<1024; i=i+1) begin
            $fwrite(f, "%02x\n", i % 256);
        end
        $fclose(f);

        $dumpfile("dump.vcd");
        $dumpvars(0, tb_data_prod_proc);

        $display("--- Starting Simulation: Mode Bypass (00) ---");
        #10000; 
        
        $display("--- Switching to Mode: Invert (01) ---");
        mode = 2'b01;
        #10000;

        $display("--- Switching to Mode: Convolution (10) ---");
        mode = 2'b10;
        #100000; // Give it time to fill line buffers (2048+ cycles)

        $display("--- Simulation Finished ---");
        $finish;
    end

    // Data Producer: Streams data at 200MHz
    data_producer #(.IMAGE_SIZE(1024)) producer (
        .sensor_clk(sensor_clk),
        .rst_n(srstn),
        .ready(!f_full),     
        .pixel(s_pixel),
        .valid(s_valid)
    );

    // Async FIFO: The Bridge
    async_fifo #(.WIDTH(8), .DEPTH(16)) fifo (
        .wclk(sensor_clk),
        .wrst_n(srstn),
        .wr_en(s_valid),
        .wdata(s_pixel),
        .rclk(clk),
        .rrst_n(rstn),
        .rd_en(p_ready && !f_empty), // Only read if processor is ready and data exists
        .rdata(f_pixel),
        .full(f_full),
        .empty(f_empty)
    );

    // Data Processor: Processes at 100MHz
    data_proc processor (
        .clk(clk),
        .rstn(rstn),
        .pixel_in(f_pixel),
        .valid_in(!f_empty),
        .ready_out(p_ready),
        .mode(mode),
        .kernel(kernel),
        .pixel_out(p_out),
        .valid_out(p_valid),
        .ready_in(1'b1),     // Consumer is always ready
        .status(status)
    );

// monitor for debugging   
//    always @(posedge clk) begin
//        if (p_valid) begin
//            $display("Time: %0t | Mode: %b | Out: %h | Status: %b", $time, mode, p_out, status);
//        end
//   end

endmodule