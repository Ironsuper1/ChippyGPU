`define WIDTH 32
`define CACHE_SIZE 1024


module processor;

    wire clk, rst, en, brn_en, write_enable, alu_imm, mem_read, mem_write, write_back;
    reg [31:0] instruction = "11";
    reg [15:0] value_in = "12";
    reg [4:0] result;
    reg mux_result;
    reg m2_Res;
    reg ins_result;
    wire [31:0] pc_temp, pc_in, pc_out, pc_brn, imm_out, rs1_data, rs2_data, rd_data;
    wire [7:0] opcode;
    wire[4:0] rs1, rs2, rd, control;

    // Fetch
    assign pc_temp = (brn_en) ? pc_brn : (pc_in + 4);
    program_counter p1 (
        .clk(clk),
        .rst(rst),
        .pc_in(pc_temp),
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
        .rd_addr(rd),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .rd_data(rd_data),
        .write_enable(write_enable)
    );

    controller alu_ctrl (
        .opcode(opcode),
        .funct3(opcode[14:12]),
        .funct7(opcode[31:25]),
        .control(control),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .write_back(write_back),
        .alu_imm(alu_imm),
    );
    // Execute + ALU
    alu exe (

    );

    // Memory Write/Data Memory
/*
    dataMem d (

    );*/
    // Writeback
endmodule


module program_counter (
    input wire clk,
    input wire rst,
    input wire [31:0] pc_in,
    output reg [31:0] pc_out
);

    always @(posedge clk or posedge rst) begin
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

module imm_parser (
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

// alu_imm = 1 when using immediate instead of second register
module controller (
    input wire [7:0] opcode,
    input wire [2:0] funct3,
    input wire [6:0] funct7,
    output wire write_back,
    output wire mem_write,
    output wire mem_read,
    output wire alu_imm,
    output wire [4:0] control
);
    assign write_back = (opcode == 7'b0110011 || opcode == 0010011 ||
                        opcode == 7'b0000011 || opcode == 7'b1101111 ||
                        opcode == 7'b1100111 || opcode == 7'b0110111 ||
                        opcode == 7'b0010111) ? 1 : 0;

    assign mem_write = (opcode == 7'b0100011) ? 1 : 0;

    assign mem_read = (opcode == 7'b0000011) ? 1 : 0;

    assign alu_imm = (opcode == 7'b0010011 || opcode == 7'b0000011 ||
                      opcode == 7'b1100111 || opcode == 7'b0100011 ||
                      opcode == 7'b1100011 || opcode == 7'b0110111 ||
                      opcode == 7'b0010111 || opcode == 7'b1101111) ? 1 : 0;

    always @(*) begin
        case (opcode)
            7'b0110011: begin  // R-type instructions (funct3 and funct7)
                case (funct3)
                    3'b000: begin  // ADD / SUB
                        if (funct7 == 7'b0100000)   // SUB
                            control = 5'd1;
                        else                          // ADD
                            control = 5'd0;
                    end
                    3'b001: control = 5'd2;      // SLL
                    3'b010: control = 5'd3;      // SLT
                    3'b011: control = 5'd4;      // SLTU
                    3'b100: control = 5'd5;      // XOR
                    3'b101: begin  // SRL / SRA
                        if (funct7 == 7'b0100000)  // SRA
                            control = 5'd7;
                        else                         // SRL
                            control = 5'd6;
                    end
                    3'b110: control = 5'd8;      // OR
                    3'b111: control = 5'd9;      // AND
                    default: control = 5'd0;     // Default case (NOP)
                endcase
            end
            7'b0010011: begin  // I-type instructions (funct3)
                case (funct3)
                    3'b000: control = 5'd0;      // ADDI
                    3'b001: control = 5'd2;      // SLLI
                    3'b010: control = 5'd3;      // SLTI
                    3'b011: control = 5'd4;      // SLTIU
                    3'b100: control = 5'd5;      // XORI
                    3'b101: control = 5'd6;      // SRLI
                    3'b110: control = 5'd8;      // ORI
                    3'b111: control = 5'd9;      // ANDI
                    default: control = 5'd0;     // Default case (NOP)
                endcase
            end
            7'b0000011: begin
                control = 5'd0;
            end
            7'b0100011: begin
                control = 5'd0;
            end
            default: control = 5'd0;  // Default for other opcodes (NOP)
        endcase
      end
endmodule

module alu_cmd (
    input wire [4:0] op,
    input wire [3:0] funct,
    input wire [4:0] alu_ctrl
);

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
    input  [31:0] a,      // First operand (rs1)
    input  [31:0] b,      // Second operand (rs2)
    input  [31:0] imm,    // Immediate value
    input  [4:0] control, // ALU operation control signal
    input        use_imm, // Select imm (1) or b (0)
    output reg [31:0] val,// ALU result
    output reg zero       // Zero flag
);
    wire [31:0] opB = use_imm ? imm : b; // Select between imm and b

    always @(*) begin
    case (control)
        5'd0:  val = a + opB;                     // ADD / ADDI
        5'd1:  val = a - opB;
        5'd2:  val = a << opB[4:0];               // SLL / SLLI
        5'd3:  val = ($signed(a) < $signed(opB)) ? 1 : 0; // SLT / SLTI
        5'd4:  val = (a < opB) ? 1 : 0;           // SLTU / SLTIU
        5'd5:  val = a ^ opB;                     // XOR / XORI
        5'd6:  val = a >> opB[4:0];               // SRL / SRLI
        5'd7:  val = $signed(a) >>> opB[4:0];     // SRA / SRAI
        5'd8:  val = a | opB;                     // OR / ORI
        5'd9:  val = a & opB;                     // AND / ANDI
        default: val = 32'b0;                     // Default case (NOP)
    endcase

    // Set zero flag
    zero = (val == 32'b0) ? 1'b1 : 1'b0;
end

endmodule

/*
module dataMem (
    input wire clk,
    input wire rst,
    input wire mem_write,
    input wire mem_read,
    input wire [31:0] addr,
    input wire [31:0] data,
    output wire [31:0] rd
);
    parameter int WIDTH = `WIDTH;
    parameter int CACHE_SIZE = `CACHE_SIZE;
    reg [WIDTH-1:0] cache[CACHE_SIZE];

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
*/
