`define WIDTH 32
`define CACHE_SIZE 1024 // 4Byte Width Data -> 128Byte Cache
module processor;

    wire clk, rst, en;
    reg [31:0] instruction = "11";
    reg [15:0] value_in = "12";
    reg [4:0] result;
    reg mux_result;
    reg m2_Res;

    // program counter
    progCount p1 (
        clk,
        rst,
        en,
        m2_Res
    );
    assign result = instruction[5:1] & value_in[5:1];
    mux one (
        clk,
        rst,
        result[0],
        en,
        mux_result
    );
    // Instruction Memory

    // Decode + Registers

    // Execute + ALU

    // Memory Write/Data Memory



endmodule
;

module progCount (
    input  clk,
    input  rst,
    input  en,
    output pc
);
    parameter width = `WIDTH;
    reg [width-1:0] Q;
    always @(posedge rst, posedge clk) begin
        if (rst) begin
            Q <= 0;
        end else if (en) begin
            Q <= Q + 1;
        end
    end
endmodule
;


module insMem (
    input [31:0]  addr,
    output [31:0] ins
);
    parameter width = `WIDTH;
    parameter cache_size = `CACHE_SIZE;
    reg [width-1:0] imem  [0:cache_size-1]; // 1024 entries
    initial begin
        imem[0]   = 32'h00000093; // ADDI x1, x0, 0
        imem[1]   = 32'h00100113; // ADDI x2, x0, 1
        imem[2]   = 32'h00300193; // ADDI x3, x0, 3
        imem[3]   = 32'h00420293; // ADDI x5, x1, 4
        imem[4]   = 32'h00C30333; // ADD x6, x6, x6
        imem[5]   = 32'hFF5FF06F; // JAL x0, -5
    end

    always @(addr) begin
        ins = imem[addr[11:2]];
    end
endmodule
;

module registers (
    input  clk,
    input  rw,   // Reg Write
    input  rst,
    input  rr1,
    input  rr2,
    input  wr,
    input  wd,
    output rd1,
    output rd2
);
    parameter width = `WIDTH;
    parameter rwidth = 6;
    reg [width-1:0] cpu_reg[width-1:0];
    integer rr1i = rr1;  // Read Reg 1
    integer rr2i = rr2;  // Read Reg 2
    integer wri = wr;  //
    integer wdi = wd;

    always @(posedge rst, posedge clk) begin
        if (rst) begin
            //rst
            rd1 <= 32'b0;
            rd2 <= 32'b0;
        end else if (rw) begin
            // rw
        end else begin
            rd1 <= cpu_reg[rr1i];
            rd2 <= cpu_reg[rr2i];
        end
    end

endmodule
;

// Control, 0 -> Add
// Control, 1 -> Sub
// Control, 2 -> Mul
// Control, 3 -> Div
module alu (
    input  clk,
    input  rst,
    input  first,
    input  second,
    input  control[1:0],
    output val,
    output zero
);
    reg [width-1:0] temp;

    always @(posedge rst, posedge clk) begin
        if (rst) begin
            zero <= "0";
        end else if (control == 0) begin  // Add
            temp <= first + second;
            if (temp < first) begin
                zero = 1'b1;
            end
            val <= temp;
        end else if (control == 1) begin  // Sub
            temp <= first - second;
            if (temp < first) begin
                zero = 1'b1;
            end
        end else if (control == 2) begin  // Mul
            temp <= first * second;
            if (temp < first) begin
                zero = 1'b1;
            end
        end else if (control == 3) begin  // Div
            temp <= first / second;
            if (temp < first) begin
                zero = 1'b1;
            end
        end
    end

endmodule
;

module dataMem (
    input wire clk,
    input wire rst,
    input wire mem_write,
    input wire mem_read,
    input wire [31:0] addr,
    input wire [31:0] data,
    output wire [31:0] rd
);
    parameter width = `WIDTH;
    parameter cache_size = `CACHE_SIZE;
    reg [width-1:0] cache[0:cache_size-1];
    
    always @(posedge clk or posedge rst) begin
        if (reset) begin
            rd <= 32'b0;
        end else if (mem_write) begin
            cache[addr[11:2]] <= data;
        end else if (mem_read) begin
            rd <= cache[addr[11:2]];
        end
    end 

endmodule
;
