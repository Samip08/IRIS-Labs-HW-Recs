`timescale 1 ns / 1 ps

module uart_tb;
    reg clk = 0;
    always #5 clk = ~clk;

    reg [5:0] reset_cnt = 0;
    wire resetn = &reset_cnt;

    always @(posedge clk) begin
        reset_cnt <= reset_cnt + !resetn;
    end

    wire ser_rx, ser_tx;
    wire flash_csb, flash_clk;
    wire flash_io0, flash_io1, flash_io2, flash_io3;

    integer pixel_out_count = 0;
    reg [7:0] expected_val;

    rvsoc_wrapper #(.MEM_WORDS(256)) uut (
        .clk(clk), 
        .resetn(resetn), 
        .sensor_clk(clk),
        .ser_rx(ser_rx), 
        .ser_tx(ser_tx),
        .flash_csb(flash_csb), 
        .flash_clk(flash_clk),
        .flash_io0(flash_io0), 
        .flash_io1(flash_io1),
        .flash_io2(flash_io2), 
        .flash_io3(flash_io3)
    );
    
    spiflash spiflash (
        .csb(flash_csb), 
        .clk(flash_clk),
        .io0(flash_io0), 
        .io1(flash_io1),
        .io2(flash_io2), 
        .io3(flash_io3)
    );

    initial begin
        $dumpfile("uart_sim.vcd");
        $dumpvars(0, uart_tb);
        
        wait(resetn);
        #1000;
          
        $display("\nNUM  | VALUE | EXPECTED");
        $display("-----------------------");

        $display("--- MODE 00 (BYPASS) ---");
        wait(pixel_out_count >= 50); 
    
        @(posedge clk);
        force uut.soc.my_engine.reg_mode = 2'b01;
        $display("--- MODE 01 (INVERT) ---");
        wait(pixel_out_count >= 150);

        @(posedge clk);
        force uut.soc.my_engine.reg_mode = 2'b10;
        $display("--- MODE 10 (CONVOLUTION) ---");
        wait(pixel_out_count >= 2500); 
        
        $finish;
    end

    always @(posedge clk) begin
        if (resetn && uut.soc.my_engine.proc_valid) begin
            // Determine expected value based on current mode
            case (uut.soc.my_engine.reg_mode)
                2'b00:   expected_val = uut.soc.my_engine.fifo_pixel; // Bypass
                2'b01:   expected_val = 8'hFF - uut.soc.my_engine.fifo_pixel; // Invert
                default: expected_val = 8'hxx; // Convolution math is too complex for simple TB print
            endcase

            // Print format: PIXEL_NUMBER | ACTUAL_VALUE | EXPECTED_VALUE
            if (uut.soc.my_engine.reg_mode == 2'b10)
                $display("%4d |  %02h   | --", pixel_out_count, uut.soc.my_engine.proc_pixel);
            else
                $display("%4d |  %02h   |   %02h", pixel_out_count, uut.soc.my_engine.proc_pixel, expected_val);
            
            pixel_out_count <= pixel_out_count + 1;
        end
    end

endmodule