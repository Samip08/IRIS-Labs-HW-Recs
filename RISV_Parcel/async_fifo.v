`timescale 1ns/1ps

module async_fifo #(parameter WIDTH = 8, DEPTH = 16) (
    input wclk, wrst_n, wr_en,
    input [WIDTH-1:0] wdata,
    input rclk, rrst_n, rd_en,
    output [WIDTH-1:0] rdata,
    output reg full, empty
);
    reg [WIDTH-1:0] mem [0:DEPTH-1];
    reg [4:0] wptr, rptr;
    reg [3:0] wptr_gray, rptr_gray;
    reg [3:0] wq2_rptr, rq2_wptr; 
    reg [3:0] wq1_rptr, rq1_wptr;

    // Write Logic (Sensor Clock)
    always @(posedge wclk or negedge wrst_n) begin
        if (!wrst_n) begin wptr <= 0; wptr_gray <= 0; end
        else if (wr_en && !full) begin
            mem[wptr[3:0]] <= wdata;
            wptr <= wptr + 1;
            wptr_gray <= (wptr + 1) ^ ((wptr + 1) >> 1);
        end
    end

    // Read Logic (Processor Clock)
    always @(posedge rclk or negedge rrst_n) begin
        if (!rrst_n) begin rptr <= 0; rptr_gray <= 0; end
        else if (rd_en && !empty) begin
            rptr <= rptr + 1;
            rptr_gray <= (rptr + 1) ^ ((rptr + 1) >> 1);
        end
    end
    assign rdata = mem[rptr[3:0]];

    // Cross-domain Synchronization (Double Flopping)
    always @(posedge wclk) {wq2_rptr, wq1_rptr} <= {wq1_rptr, rptr_gray};
    always @(posedge rclk) {rq2_wptr, rq1_wptr} <= {rq1_wptr, wptr_gray};

    // Status Generation
    always @(*) full = (wptr_gray == {~wq2_rptr[3:2], wq2_rptr[1:0]});
    always @(*) empty = (rptr_gray == rq2_wptr);
endmodule