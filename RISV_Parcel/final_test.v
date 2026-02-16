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
    reg dots_printed = 0;

    rvsoc_wrapper #(.MEM_WORDS(256)) uut (
        .clk(clk), .resetn(resetn), .sensor_clk(clk),
        .ser_rx(ser_rx), .ser_tx(ser_tx),
        .flash_csb(flash_csb), .flash_clk(flash_clk),
        .flash_io0(flash_io0), .flash_io1(flash_io1),
        .flash_io2(flash_io2), .flash_io3(flash_io3)
    );
    
    spiflash spiflash (
        .csb(flash_csb), .clk(flash_clk),
        .io0(flash_io0), .io1(flash_io1),
        .io2(flash_io2), .io3(flash_io3)
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
        
        wait(pixel_out_count >= 2220); 
        $display("--- TEST FINISHED ---");
        $finish;
    end

    // --- THE HARDCODED LOGGER ---
    always @(posedge clk) begin
        if (resetn && uut.soc.my_engine.proc_valid) begin
            
            if (uut.soc.my_engine.reg_mode == 2'b10) begin
                if (pixel_out_count > 2200) begin
                    $display("%4d |   %02h  | --", pixel_out_count, uut.soc.my_engine.proc_pixel);
                end 
                else if (!dots_printed) begin
                    $display(" ... |   ..  |  ..");
                    dots_printed <= 1;
                end
            end 
            else begin
                // Normal printing for Bypass and Invert
                case (uut.soc.my_engine.reg_mode)
                    2'b00:   expected_val = uut.soc.my_engine.fifo_pixel; 
                    2'b01:   expected_val = 8'hFF - uut.soc.my_engine.fifo_pixel; 
                    default: expected_val = 8'hxx; 
                endcase
                $display("%4d |   %02h  |   %02h", pixel_out_count, uut.soc.my_engine.proc_pixel, expected_val);
                dots_printed <= 0; // Reset for next transition
            end
            
            pixel_out_count <= pixel_out_count + 1;
        end
    end
endmodule