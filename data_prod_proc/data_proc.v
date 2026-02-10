module data_proc (

    input clk,
    input rstn,

    input [7:0]      pixel_in,   
    input            valid_in,   
    input            ready_in,
    input [1:0]      mode,       
    input [71:0]     kernel,     

    output reg [7:0] pixel_out,  
    output reg       ready_out, 
    output reg       valid_out
);

reg [1:0] mode_reg;
reg [71:0] kernel_reg;
reg [7:0] pixel_reg;
reg [20:0] pixel_count;

reg [7:0] line_buf_1 [0:1023];
reg [7:0] line_buf_2 [0:1023];
reg [9:0] ptr; 

reg [7:0] p11, p12, p13, p21, p22, p23, p31, p32, p33;

wire [7:0] k11 = kernel[7:0];   wire [7:0] k12 = kernel[15:8];  wire [7:0] k13 = kernel[23:16];
wire [7:0] k21 = kernel[31:24];   wire [7:0] k22 = kernel[39:32];  wire [7:0] k23 = kernel[47:40];
wire [7:0] k31 = kernel[55:48];   wire [7:0] k32 = kernel[63:56];  wire [7:0] k33 = kernel[71:64];

wire [7:0] lb1_out = line_buf_1[ptr];
wire [7:0] lb2_out = line_buf_2[ptr];

wire [19:0] conv_sum = (p11*k11 + p12*k12 + p13*k13 +p21*k21 + p22*k22 + p23*k23 +p31*k31 + p32*k32 + p33*k33);
wire [7:0] conv_result = (conv_sum / 9); //normalization step

always@(*)begin
    case(mode_reg)
        2'b00:   pixel_reg = pixel_in;           
        2'b01:   pixel_reg = ~pixel_in;          
        2'b10:   pixel_reg = conv_result;        
        default: pixel_reg = pixel_in;
    endcase
end

always@(posedge clk or negedge rstn) begin
    if (!rstn) begin
        mode_reg <= 2'b00;
        ready_out <= 1'b1;
        kernel_reg <= 72'h0;
        pixel_out <= 8'h0;
        valid_out <= 1'b0;
    end else begin
        mode_reg <= mode;
        kernel_reg <= kernel;

            if (valid_in && ready_out) begin
            
                p11 <= p12; p12 <= p13; p13 <= lb2_out;
                p21 <= p22; p22 <= p23; p23 <= lb1_out;
                p31 <= p32; p32 <= p33; p33 <= pixel_in;

                line_buf_1[ptr] <= pixel_in;
                line_buf_2[ptr] <= lb1_out;

                ptr <= (ptr == 1023) ? 10'd0 : ptr + 10'd1;
                if (pixel_count < 21'h1FFFFF) pixel_count <= pixel_count + 1;

                pixel_out <= pixel_reg;
                
                if (mode_reg == 2'b10)
                    valid_out <= (pixel_count >= 2051);
                else
                    valid_out <= 1'b1;

            end else if (ready_in) begin
                valid_out <= 1'b0;
            end
        end
    end

endmodule



/* --------------------------------------------------------------------------
Purpose of this module : This module should perform certain operations
based on the mode register and pixel values streamed out by data_prod module.

mode[1:0]:
00 - Bypass
01 - Invert the pixel
10 - Convolution with a kernel of your choice (kernel is 3x3 2d array)
11 - Not implemented

Memory map of registers:

0x00 - Mode (2 bits)    [R/W]
0x04 - Kernel (9 * 8 = 72 bits)     [R/W]
0x10 - Status reg   [R]
----------------------------------------------------------------------------*/
