`timescale 1ns/1ps

module tb_data_prod_proc;

    reg clk = 0;
    reg sensor_clk = 0;

    // 100MHz
    always #5 clk = ~clk;

    // 200MHz
    always #2.5 sensor_clk = ~sensor_clk;

    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt;

    always @(posedge clk) begin
        if (!resetn)
            reset_cnt <= reset_cnt + 1'b1;
    end

    reg [5:0] sensor_reset_cnt = 0;
    wire sensor_resetn = &sensor_reset_cnt;

    always @(posedge sensor_clk) begin
        if (!sensor_resetn)
            sensor_reset_cnt <= sensor_reset_cnt + 1'b1;
    end

    // Connection Wires
    wire [7:0] pixel_bus;
    wire       valid_bus;
    wire       ready_bus;
    
    reg [1:0]  tb_mode;
    reg [71:0] tb_kernel;
    
    // Output Side Wires
    wire [7:0] out_pixel;
    wire       out_valid;
    reg        out_ready;


	/* Write your tb logic for your combined design here */
initial begin
        tb_mode = 2'b00;   
        tb_kernel = 0;
        out_ready = 0;    

        wait(resetn && sensor_resetn);
        #100;
        
        out_ready = 1;

        tb_mode = 2'b00;
        #5000;

        tb_mode = 2'b01;
        #5000;

        tb_kernel = {8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1};
        tb_mode = 2'b10;
        
        // Note: Convolution needs >2051 pixels to start showing valid_out
        #50000; 

        $display("Simulation Finished");
        $finish;
    end

    /* Data Processor (UUT) */
    data_proc data_processing (
        .clk(clk),
        .rstn(resetn),
        .pixel_in(pixel_bus),  // From Producer
        .valid_in(valid_bus),  // From Producer
        .ready_out(ready_bus), // To Producer
        .mode(tb_mode),
        .kernel(tb_kernel),
        .pixel_out(out_pixel),
        .valid_out(out_valid),
        .ready_in(out_ready)   // Driven by TB
    );

    /* Data Producer */
    data_prod data_producer (
        .sensor_clk(sensor_clk),
        .rstn(sensor_resetn),
        .ready(ready_bus),     // From Processor
        .pixel(pixel_bus),     // To Processor
        .valid(valid_bus)      // To Processor
    );

endmodule
