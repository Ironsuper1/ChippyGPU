`define WIDTH 32
`define CACHE_SIZE 1024


module processor;

    wire clk, rst, en, brn_en;
    reg [31:0] instruction = "11";
    reg [15:0] value_in = "12";
    reg [4:0] result;
    reg mux_result;
    reg m2_Res;
    reg ins_result;
    wire [31:0] pc_in, pc_out, pc_brn, imm_out;
    wire [7:0] opcode;
    wire[4:0] rs1, rs2, rd;

    // Fetch
    assign pc_in = (brn_en) ? pc_brn : (pc_in + 4);
    program_counter p1 (
        .clk(clk),
        .rst(rst),
        .pc_in(pc_in),
        .pc_out(pc_out)
    );

    assign pc_in = pc_out;

    // Instruction Memory
    insMem ins (
        .addr(mux_result),
        .ins(ins_result)
    );
    // Decode
    op_parser op_p (
        .ins(ins_result),
        .opcode(opcode),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd)
    );

    imm_parser imm_p (
        .ins(ins_result),
        .imm_out(imm_out)
    );

    register_file rf (
        .clk(clk),
        .rst(rst),
        .rs1_addr(rs1),
        .rs2_addr(rs2),
        .rd_addr(rd)
    );
    // Execute + ALU
    alu exe (

    );

    // Memory Write/Data Memory

    dataMem d (

    );
    // Writeback
endmodule


module program_counter (
    input wire clk,
    input wire rst,
    input wire [31:0] pc_in,
    output reg [31:0] pc_out
);

    always @(posedge clk or posedge reset) begin
        if (rst) begin
            pc_out <= 32'b0;
        end else begin
            pc_out <= pc_in;
        end
    end

endmodule


module insMem (
    input [31:0] addr,
    output [31:0] ins
);
    parameter int WIDTH = `WIDTH;
    parameter int CACHE = `CACHE_SIZE;
    reg [WIDTH-1:0] imem  [CACHE]; // 1024 entries
    initial begin
        imem[0] = 32'h00000093; // ADDI x1, x0, 0
        imem[1] = 32'h00100113; // ADDI x2, x0, 1
        imem[2] = 32'h00300193; // ADDI x3, x0, 3
        imem[3] = 32'h00420293; // ADDI x5, x1, 4
        imem[4] = 32'h00C30333; // ADD x6, x6, x6
        imem[5] = 32'hFF5FF06F; // JAL x0, -5
    end

    always @(addr) begin
        ins = imem[addr[11:2]];
    end
endmodule

module op_parser (
    input  [31:0] ins,
    output [7:0] opcode,
    output [4:0] rs1,
    output [4:0] rs2,
    output [4:0] rd
);

    assign opcode = ins[7:0];
    assign rs1 = ins[19:15];
    assign rs2 = ins[24:20];
    assign rd = ins[11:7];

endmodule

module immediate_parser (
    input [31:0] ins,
    output [31:0] imm_out
);
    wire [7:0] op = ins[7:0];
    // Extract and sign-extend immediates using assign
    wire [31:0] imm_i = {{20{ins[31]}}, ins[31:20]}; // I-type
    wire [31:0] imm_s = {{20{ins[31]}}, ins[31:25], ins[11:7]}; // S-type
    wire [31:0] imm_b = {{19{ins[31]}}, ins[31], ins[7], ins[30:25], ins[11:8], 1'b0}; // B-type
    wire [31:0] imm_u = {ins[31:12], 12'b0}; // U-type (zero-extended)
    wire [31:0] imm_j = {{11{ins[31]}}, ins[31], ins[19:12], ins[20], ins[30:21], 1'b0}; // J-type

    // Assign output based on instruction format
    assign imm_out =  (op == 7'b0010011 || op == 7'b0000011 || op == 7'b1100111) ? imm_i :
                      (op == 7'b0100011) ? imm_s :
                      (op == 7'b1100011) ? imm_b :
                      (op == 7'b0110111 || op == 7'b0010111) ? imm_u :
                      (op == 7'b1101111) ? imm_j :
                      32'b0; // Default case: return 0 if format is unknown

endmodule

module register_file (
    input wire clk,
    input wire rst,
    input wire [4:0] rs1_addr,    // Address of source register 1
    input wire [4:0] rs2_addr,    // Address of source register 2
    input wire [4:0] rd_addr,     // Address of destination register
    input wire [31:0] rd_data,    // Data to write to destination register
    input wire write_enable,      // Write enable signal
    output wire [31:0] rs1_data,  // Data from source register 1
    output wire [31:0] rs2_data   // Data from source register 2
);

    // 32 registers, 32bits
    reg [31:0] registers [32];

    // Asynchronous read
    assign rs1_data = (rs1_addr == 0) ? 32'b0 : registers[rs1_addr]; // x0 is always 0
    assign rs2_data = (rs2_addr == 0) ? 32'b0 : registers[rs2_addr]; // x0 is always 0

    // Synchronous write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all registers to 0
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else if (write_enable && rd_addr != 0) begin
            registers[rd_addr] <= rd_data;
        end
    end

endmodule



// Control, 0 -> Add
// Control, 1 -> Sub
// Control, 2 -> SLL
// Control, 3 -> SLT
// Control, 4 -> SLTU
// Control, 5 -> XOR
// Control, 6 -> SRL
// Control, 7 -> SRA
// Control, 8 -> OR
// Control, 9 -> AND
// Control, 10 -> ADDI
// Control, 11 -> SLTI
// Control, 12 -> SLTIU
// Control, 13 -> XORI
// Control, 14 -> ORI
// Control, 15 -> ANDI
// Control, 16 -> SLLI
// Control, 17 -> SRLI
// Control, 18 -> SRAI
module alu (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [31:0] imm,
    input wire [4:0] control,
    output reg [31:0] val,
    output zero
);
    reg [width-1:0] temp;

    assign zero = (val == 32'b0);

    always(*) begin
      case (control)
        0: val = a+b;

        2: val = a<<b;
        3: val = (a<b) ? 1 : 0;
        4: val = (unsigned(a)<unsigned(b)) ? 1 : 0;
        5: val = a^b;
        6: val = a>>b;
        7: val = a>>>b;
        8: val = a|b;
        9: val = a&b;
        10: val = a+imm;
        11: val = (a<imm) ? 1 : 0;
        12: val = (unsigned(a)<unsigned(imm)) ? 1 : 0;
        13: val = a^imm;
        14: val = a|imm;
        15: val = a&imm;
        16: val = a<<imm;
        17: val = a>>imm;
        18: val = a>>>imm;
    end

endmodule


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

