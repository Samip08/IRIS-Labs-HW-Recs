`timescale 1ns/1ps

module tb_data_prod_proc;
    parameter WIDTH = 1024;
    
    reg clk = 0;
    reg sensor_clk = 0;
    reg [5:0] r_cnt = 0, s_cnt = 0;
    
    always #5 clk = ~clk;
    always #2.5 sensor_clk = ~sensor_clk;

    wire rstn = &r_cnt;       
    wire srstn = &s_cnt;      
    always @(posedge clk) if(!rstn) r_cnt <= r_cnt + 1'b1;
    always @(posedge sensor_clk) if(!srstn) s_cnt <= s_cnt + 1'b1;

    wire [7:0] s_pixel, f_pixel, p_out;
    wire s_valid, f_empty, f_full, p_valid, p_ready, status;
    reg [1:0] mode = 2'b00;
    reg [71:0] kernel = {8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1, 8'd1}; 

    initial begin

    //explicitly added an image generation block remove ifvalidation image called 'image.hex' is present
    // otherwise it overwrites the values of 'image.hex'
        integer f, i;
        f = $fopen("image.hex", "w");
        for (i=0; i<WIDTH; i=i+1) $fwrite(f, "%02x\n", i % 256);
        $fclose(f);

        #10000; 
        mode = 2'b01; 
        #10000;
        mode = 2'b10; 
        #10000; 
        $finish;
    end

    data_producer #(.IMAGE_SIZE(WIDTH)) producer (
        .sensor_clk(sensor_clk), 
        .rst_n(srstn),
        .ready(!f_full), 
        .pixel(s_pixel), 
        .valid(s_valid)
    );

    async_fifo #(.WIDTH(8), .DEPTH(16)) fifo (
        .wclk(sensor_clk), 
        .wrst_n(srstn), 
        .wr_en(s_valid), 
        .wdata(s_pixel),
        .rclk(clk), 
        .rrst_n(rstn), 
        .rd_en(p_ready && !f_empty), 
        .rdata(f_pixel),
        .full(f_full), 
        .empty(f_empty)
    );

    data_proc #(.IMG_WIDTH(WIDTH)) processor (
        .clk(clk), 
        .rstn(rstn), 
        .pixel_in(f_pixel), 
        .valid_in(!f_empty),
        .ready_out(p_ready), 
        .mode(mode), 
        .kernel(kernel),
        .pixel_out(p_out), 
        .valid_out(p_valid), 
        .ready_in(1'b1), 
        .status(status)
    );

endmodule