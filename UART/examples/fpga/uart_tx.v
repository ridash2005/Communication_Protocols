/*
 * Simple UART Transceiver (Verilog)
 * Configuration: 8-N-1 (8 Data bits, No Parity, 1 Stop bit)
 * 
 * Parameters:
 * - CLK_FREQ: System clock frequency in Hz.
 * - BAUD_RATE: Target baud rate (e.g., 9600, 115200).
 */

module uart_tx #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
)(
    input wire clk,
    input wire rst,
    input wire tx_start,      // Pulse high to start transmission
    input wire [7:0] tx_data, // Data to send
    output reg tx_busy,       // High while transmitting
    output reg tx_line        // Serial Output
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // States
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;
    
    reg [1:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_index;
    reg [7:0] data_reg;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx_busy <= 0;
            tx_line <= 1; // Idle High
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx_line <= 1;
                    tx_busy <= 0;
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_start) begin
                        data_reg <= tx_data;
                        state <= START;
                        tx_busy <= 1;
                    end
                end
                
                START: begin
                    tx_line <= 0; // Start bit is Low
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= DATA;
                    end
                end
                
                DATA: begin
                    tx_line <= data_reg[bit_index]; // LSB First
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP;
                        end
                    end
                end
                
                STOP: begin
                    tx_line <= 1; // Stop bit is High
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= IDLE;
                        tx_busy <= 0;
                    end
                end
            endcase
        end
    end
endmodule
