/*
 * SystemVerilog SPI Master
 * Mode 0 (CPOL=0, CPHA=0)
 * 
 * Improvements:
 * - Converted to SystemVerilog.
 * - Added `failed_o` error flag.
 * - Implemented timeout safety logic (watchdog).
 */

module spi_master #(
    parameter int CLK_DIV = 4 // CLK_FREQ / (2 * SPI_FREQ)
)(
    input  logic       clk,
    input  logic       rst,
    input  logic       start_i,     // Pulse high to start transaction
    input  logic [7:0] data_i,      // Data to send to slave
    output logic [7:0] data_o,      // Data received from slave
    output logic       done_o,      // High when transaction complete
    output logic       error_o,     // Error flag (e.g., unexpected state/timeout)
    
    // SPI Interface
    output logic       sck_o,
    output logic       mosi_o,
    input  logic       miso_i,
    output logic       cs_n_o       // Chip Select (Active Low)
);

    // Enumerated State Type
    typedef enum logic {
        IDLE,
        TRANSFER
    } state_t;
    
    state_t state;
    logic [7:0]  shift_reg;
    logic [3:0]  bit_cnt;
    logic [15:0] clk_cnt;
    
    // Safety Watchdog
    logic [31:0] watchdog_timer;
    localparam int WATCHDOG_LIMIT = 100000; // Arbitrary cycle limit

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state    <= IDLE;
            cs_n_o   <= 1;
            sck_o    <= 0;
            mosi_o   <= 0;
            done_o   <= 0;
            error_o  <= 0;
            bit_cnt  <= 0;
            shift_reg <= 0;
            clk_cnt  <= 0;
            watchdog_timer <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done_o   <= 0;
                    cs_n_o   <= 1;
                    sck_o    <= 0;
                    error_o  <= 0; // Clear error on new idle
                    watchdog_timer <= 0;
                    
                    if (start_i) begin
                        shift_reg <= data_i;
                        state     <= TRANSFER;
                        cs_n_o    <= 0;
                        bit_cnt   <= 0;
                        clk_cnt   <= 0;
                        mosi_o    <= data_i[7];
                    end
                end
                
                TRANSFER: begin
                    // Watchdog: If stuck in transfer too long, reset and error
                    if (watchdog_timer > WATCHDOG_LIMIT) begin
                        state   <= IDLE;
                        error_o <= 1;
                        cs_n_o  <= 1; // Release bus
                    end else begin
                         watchdog_timer <= watchdog_timer + 1;
                    
                        if (clk_cnt < CLK_DIV - 1) begin
                            clk_cnt <= clk_cnt + 1;
                        end else begin
                            clk_cnt <= 0;
                            sck_o   <= ~sck_o; // Toggle Clock
                            
                            if (sck_o == 1) begin 
                                // Falling Edge (Setup next bit or finish)
                                if (bit_cnt == 7) begin
                                    state   <= IDLE;
                                    cs_n_o  <= 1;
                                    done_o  <= 1;
                                    data_o  <= shift_reg;
                                end else begin
                                    bit_cnt <= bit_cnt + 1;
                                    mosi_o  <= shift_reg[6];
                                    shift_reg <= {shift_reg[6:0], 1'b0};
                                end
                            end else begin 
                                // Rising Edge (Sample MISO)
                                shift_reg[0] <= miso_i;
                            end
                        end
                    end
                end
            endcase
        end
    end
endmodule
