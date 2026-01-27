/*
 * Simple SPI Master (Verilog)
 * Mode 0 (CPOL=0, CPHA=0)
 * 
 * functionality:
 * - Sends 8 bits on MOSI.
 * - Receives 8 bits on MISO.
 * - Generates SCK only when active.
 */

module spi_master #(
    parameter CLK_DIV = 4 // CLK_FREQ / (2 * SPI_FREQ)
)(
    input wire clk,
    input wire rst,
    input wire start,           // Pulse high to start transaction
    input wire [7:0] data_in,   // Data to send to slave
    output reg [7:0] data_out,  // Data received from slave
    output reg done,            // High when transaction complete
    
    // SPI Interface
    output reg sck,
    output reg mosi,
    input wire miso,
    output reg cs_n             // Chip Select (Active Low)
);

    // States
    localparam IDLE = 0;
    localparam TRANSFER = 1;
    
    reg state;
    reg [7:0] shift_reg;
    reg [3:0] bit_cnt;    // 0 to 7
    reg [15:0] clk_cnt;   // Clock divider counter
    
    // SPI Clock Logic (Mode 0: Idle Low, Capture Rising)
    // We toggle SCK based on clk_cnt
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            cs_n <= 1;
            sck <= 0;
            mosi <= 0;
            done <= 0;
            bit_cnt <= 0;
            shift_reg <= 0;
            clk_cnt <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    cs_n <= 1;
                    sck <= 0;
                    if (start) begin
                        shift_reg <= data_in;
                        state <= TRANSFER;
                        cs_n <= 0; // Select Slave
                        bit_cnt <= 0;
                        clk_cnt <= 0;
                        // Setup first bit (MSB First)
                        mosi <= data_in[7];
                    end
                end
                
                TRANSFER: begin
                    if (clk_cnt < CLK_DIV - 1) begin
                        clk_cnt <= clk_cnt + 1;
                    end else begin
                        clk_cnt <= 0;
                        sck <= ~sck; // Toggle Clock
                        
                        if (sck == 1) begin 
                            // Falling Edge (Setup next bit or finish)
                            // We just finished a full clock cycle (Rising then Falling)
                            if (bit_cnt == 7) begin
                                state <= IDLE;
                                cs_n <= 1;
                                done <= 1;
                                data_out <= shift_reg;
                            end else begin
                                bit_cnt <= bit_cnt + 1;
                                mosi <= shift_reg[6]; // Shift out next bit
                                shift_reg <= {shift_reg[6:0], 1'b0};
                            end
                        end else begin 
                            // Rising Edge (Sample MISO)
                            shift_reg[0] <= miso;
                        end
                    end
                end
            endcase
        end
    end
endmodule
