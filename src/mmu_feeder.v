`default_nettype none

module mmu_feeder (
    input wire clk,
    input wire rst,
    input wire en,
    input wire [2:0] compute_cycles, // Renamed from mmu_cycle, adjusted to 3 bits

    /* Memory module interface */
    input wire [7:0] weights [0:3],
    input wire [7:0] inputs [0:3],

    /* systolic array -> feeder */
    input wire [15:0] c_out [0:3], // 16-bit accumulation

    /* feeder -> mmu */
    output reg clear,
    output reg [7:0] a_data0,
    output reg [7:0] a_data1,
    output reg [7:0] b_data0,
    output reg [7:0] b_data1,

    /* feeder -> rpi */
    output wire done, // Renamed from host_mat_wb
    output reg [7:0] host_outdata
);

    reg [7:0] out_buf;
    assign done = en && (compute_cycles >= 3'b010) && (compute_cycles <= 3'b101);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            clear <= 1;
            a_data0 <= 0;
            a_data1 <= 0;
            b_data0 <= 0;
            b_data1 <= 0;
            host_outdata <= 0;
        end else begin
            if (en) begin
                clear <= 0;
                case (compute_cycles)
                    3'b000: begin
                        a_data0  <= inputs[0];   
                        a_data1  <= 8'b0;         
                        b_data0  <= weights[0];   
                        b_data1  <= 8'b0;          
                        host_outdata <= 0;
                    end

                    3'b001: begin
                        a_data0  <= inputs[1];   
                        a_data1  <= inputs[2];   
                        b_data0  <= weights[2];   
                        b_data1  <= weights[1];   
                        host_outdata <= 0;
                    end

                    3'b010: begin
                        a_data0  <= 8'b0;         
                        a_data1  <= inputs[3];   
                        b_data0  <= 8'b0;          
                        b_data1  <= weights[3];   
                        host_outdata <= c_out[0][7:0]; // Lower 8 bits of 16-bit result
                    end

                    3'b011: begin
                        a_data0 <= 0;      
                        a_data1 <= 0;
                        b_data0 <= 0;       
                        b_data1 <= 0;   
                        host_outdata <= c_out[1][7:0];
                        out_buf <= c_out[2][7:0];
                    end

                    3'b100: begin
                        a_data0 <= 0;      
                        a_data1 <= 0;
                        b_data0 <= 0;       
                        b_data1 <= 0;   
                        host_outdata <= c_out[2][7:0];
                        out_buf <= c_out[3][7:0];
                    end

                    3'b101: begin
                        a_data0 <= 0;      
                        a_data1 <= 0;
                        b_data0 <= 0;       
                        b_data1 <= 0;   
                        host_outdata <= c_out[3][7:0];
                        out_buf <= 0;
                    end

                    default: begin
                        a_data0 <= 8'b0;
                        a_data1 <= 8'b0;
                        b_data0 <= 8'b0;
                        b_data1 <= 8'b0;
                        host_outdata <= 0;
                        out_buf <= 0;
                    end
                endcase
            end else begin
                clear <= 1;
                a_data0 <= 0;
                a_data1 <= 0;
                b_data0 <= 0;
                b_data1 <= 0;
            end
        end
    end

endmodule