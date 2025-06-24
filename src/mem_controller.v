module mem_controller (
    input  wire        clk,
    input  wire        rst,

    // Request inputs
    input  wire        wght_req,
    input  wire        mtrx_req,
    input  wire        inst_req,

    // Handshake outputs to Raspberry Pi
    output reg [1:0] req_type,    // 01 = wght, 10 = mtrx, 11 = inst
    output reg req_valid,         // Request strobe

    // Handshake inputs from RPI
    input  wire  rpi_ready,
    input  wire [7:0]  rpi_in_data,

    output  wire [1:0]  output_sel, // 01 = wght, 10 = mtr, 11 = inst
    output wire [7:0]  out_data,
    output reg data_ready
);

    always @ (posedge clk) begin
        if (rst) begin
            data_ready <= 0;
            req_type <= 2'b00;
            req_valid <= 0;
        end else if (wght_req) begin
            req_type = 2'b01;
            req_valid = 1;
            while(!rpi_ready)begin
            end
            out_data = rpi_in_data;
            output_sel = 2'b01;
        end else if (mtrx_req) begin
            req_type = 2'b10;
            req_valid = 1;
            while(!rpi_ready)begin
            end
            out_data = rpi_in_data;
            output_sel = 2'b10;
        end else if (inst_req) begin
            req_type = 2'b11;
            req_valid = 1;
            while(!rpi_ready)begin
            end
            out_data = rpi_in_data;
            output_sel = 2'b11;
        end
    end
    
endmodule
