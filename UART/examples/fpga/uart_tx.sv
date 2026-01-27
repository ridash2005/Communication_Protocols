/*
 * SystemVerilog UART Transceiver with Parity
 * Configuration: 8-P-1 (8 Data bits, Parity Enabled, 1 Stop bit)
 * 
 * Improvements:
 * - Converted to SystemVerilog (logic, enum).
 * - Added Parity Bit generation (Even/Odd) for error detection.
 * - Added `error_o` to indicate if data is overwritten while busy.
 */

module uart_tx #(
    parameter int CLK_FREQ = 50000000,
    parameter int BAUD_RATE = 115200,
    parameter bit PARITY_ODD = 0 // 0 = Even Parity, 1 = Odd Parity
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       tx_start_i, // Pulse high to start transmission
    input  logic [7:0] tx_data_i,  // Data to send
    output logic       tx_busy_o,  // High while transmitting
    output logic       tx_line_o,  // Serial Output
    output logic       error_o     // Pulse high if start requested while busy
);

    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    
    // SystemVerilog Enumerated types for State Machine
    typedef enum logic [2:0] {
        IDLE,
        START,
        DATA,
        PARITY,
        STOP
    } state_t;
    
    state_t state;
    logic [15:0] clk_count;
    logic [2:0]  bit_index;
    logic [7:0]  data_reg;
    logic        parity_bit;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state      <= IDLE;
            tx_busy_o  <= 0;
            tx_line_o  <= 1; // Idle High
            clk_count  <= 0;
            bit_index  <= 0;
            error_o    <= 0;
            parity_bit <= 0;
        end else begin
            // Default error clear
            error_o <= 0;

            case (state)
                IDLE: begin
                    tx_line_o  <= 1;
                    tx_busy_o  <= 0;
                    clk_count  <= 0;
                    bit_index  <= 0;
                    
                    if (tx_start_i) begin
                        data_reg   <= tx_data_i;
                        // Calculate Parity
                        parity_bit <= (PARITY_ODD) ? ~(^tx_data_i) : (^tx_data_i);
                        state      <= START;
                        tx_busy_o  <= 1;
                    end
                end
                
                START: begin
                    // Error Handling: If User tries to send again while busy
                    if (tx_start_i) error_o <= 1;

                    tx_line_o <= 0; // Start bit is Low
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= DATA;
                    end
                end
                
                DATA: begin
                    if (tx_start_i) error_o <= 1;

                    tx_line_o <= data_reg[bit_index]; // LSB First
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state     <= PARITY; // Go to Parity State
                        end
                    end
                end
                
                PARITY: begin
                    if (tx_start_i) error_o <= 1;
                    
                    tx_line_o <= parity_bit;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= STOP;
                    end
                end
                
                STOP: begin
                    if (tx_start_i) error_o <= 1;

                    tx_line_o <= 1; // Stop bit is High
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state     <= IDLE;
                        tx_busy_o <= 0;
                    end
                end
            endcase
        end
    end
endmodule
