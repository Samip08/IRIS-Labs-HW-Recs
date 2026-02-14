`timescale 1ns/1ps

module data_proc (
    input clk, rstn,
    input [7:0] pixel_in,
    input valid_in,
    input ready_in,
    input [1:0] mode,
    input [71:0] kernel,
    output reg [7:0] pixel_out,
    output reg ready_out,
    output reg valid_out,
    output status 
);
    reg [20:0] pixel_count;
    reg [7:0] lb1 [0:1023], lb2 [0:1023];
    reg [9:0] ptr;
    reg [7:0] p11,p12,p13,p21,p22,p23,p31,p32,p33;

    assign status = (mode == 2'b10 && pixel_count < 2051) || !ready_in;

    wire [19:0] conv_sum = (p11*kernel[7:0]   + p12*kernel[15:8]  + p13*kernel[23:16] +
                            p21*kernel[31:24] + p22*kernel[39:32] + p23*kernel[47:40] +
                            p31*kernel[55:48] + p32*kernel[63:56] + p33*kernel[71:64]);

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            {valid_out, pixel_out, ptr, pixel_count} <= 0;
            ready_out <= 1'b1;
            {p11,p12,p13,p21,p22,p23,p31,p32,p33} <= 0;
        end else if (valid_in && ready_out) begin
            p11<=p12; p12<=p13; p13<=lb2[ptr];
            p21<=p22; p22<=p23; p23<=lb1[ptr];
            p31<=p32; p32<=p33; p33<=pixel_in;
            
            lb1[ptr] <= pixel_in; lb2[ptr] <= lb1[ptr];
            ptr <= (ptr == 1023) ? 0 : ptr + 1;
            pixel_count <= pixel_count + 1;

            case(mode)
                2'b00: pixel_out <= pixel_in;
                2'b01: pixel_out <= ~pixel_in;
                2'b10: pixel_out <= conv_sum / 9;
                default: pixel_out <= pixel_in;
            endcase
            valid_out <= (mode == 2'b10) ? (pixel_count >= 2051) : 1'b1;
        end else if (ready_in && valid_out) begin
            valid_out <= 1'b0;
        end
    end
endmodule


module async_fifo #(parameter WIDTH = 8, DEPTH = 16) (
    input wclk, wrst_n, wr_en,
    input [WIDTH-1:0] wdata,
    input rclk, rrst_n, rd_en,
    output [WIDTH-1:0] rdata,
    output reg full, empty
);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [3:0] wptr, rptr;
    reg [3:0] wptr_gray, rptr_gray;
    reg [3:0] wq2_rptr, rq2_wptr; 
    reg [3:0] wq1_rptr, rq1_wptr;

    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin wptr <= 0; wptr_gray <= 0; end
        else if (wr_en && !full) begin
            mem[wptr[3:0]] <= wdata;
            wptr <= wptr + 1;
            wptr_gray <= (wptr + 1) ^ ((wptr + 1) >> 1);
        end
    end

    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin rptr <= 0; rptr_gray <= 0; end
        else if (rd_en && !empty) begin
            rptr <= rptr + 1;
            rptr_gray <= (rptr + 1) ^ ((rptr + 1) >> 1);
        end
    end
    assign rdata = mem[rptr[3:0]];

    always @(posedge wclk) {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr_gray};
    always @(posedge rclk) {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr_gray};

    always @(*) full = (wptr_gray == {~wq2_rptr[3:2], wq2_rptr[1:0]});
    always @(*) empty = (rptr_gray == rq2_wptr);
endmodule


module data_producer #(parameter IMAGE_SIZE = 1024) (
    input sensor_clk, rst_n, ready,
    output reg [7:0] pixel,
    output reg valid
);
    reg [7:0] image_mem [0:IMAGE_SIZE-1];
    reg [$clog2(IMAGE_SIZE):0] pixel_index;

    initial begin 
    $readmemh("image.hex", image_mem);
    $display("TB CHECK: First hex value is %h", image_mem[0]); 
    end

    always @(posedge sensor_clk or negedge rst_n) begin
        if (!rst_n) begin
            pixel_index <= 0;
            valid <= 0;
            pixel <= 8'h00;
        end else if (ready) begin
            pixel <= image_mem[pixel_index];
            valid <= 1'b1;
            pixel_index <= (pixel_index < IMAGE_SIZE-1) ? pixel_index + 1 : 0;
        end else begin
            valid <= (pixel_index == 0) ? 1'b0 : 1'b1;
        end
    end
endmodule