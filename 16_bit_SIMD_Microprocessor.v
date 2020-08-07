////////////////////////////////////////////////////////////////////////////////
// Filename    : SIMD.v
// Author      : lihuang       6/4/2020
// Description : Verilog code of the SIMD mircoprocessort
////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module SIMD(clk,rst,opcode,funct3,funct7,rd_data1,rd_data2,rd_data3,w_add,immed,instrc_add,wr_add,wr_data );
input clk;  //clock
input rst;  //reset 
input [6:0] opcode; //opcode field
input [2:0] funct3; //funct3 field
input [6:0] funct7; //funct7 field
input [15:0] rd_data1;  //read_data1
input [15:0] rd_data2;  //read_data2
input [15:0] rd_data3;  //read_data3
input [4:0] w_add;  //input rd field (destinamtion register address value
input [11:0] immed; //immediate field


output [6:0]instrc_add;
output [4:0] wr_add;    //output rd field
output [15:0] wr_data;  //write data to register

wire [1:0]mode;
reg [12:0]op;
wire [3:0]scr_r;
wire scr;
wire [2:0]op_r;
wire [1:0]mac_hl;
wire [15:0]sig_ex;
wire [6:0]n_instrc_add;
wire [1:0]alu_mode;
wire [12:0]alu_op;
wire alu_scr;
wire signed[15:0]source1;
wire [15:0]data2;
wire signed[15:0]source3;
//wire [6:0] nex_instrc_add;    //next instruction address
wire [15:0]exsig_data;
wire signed[15:0]source2;
wire signed[7:0]source1_8_1;
wire signed[7:0]source1_8_2;
wire signed[7:0]source2_8_1;
wire signed[7:0]source2_8_2;
wire signed[7:0]source3_8_1;
wire signed[7:0]source3_8_2;
wire signed[3:0]source1_4_1;
wire signed[3:0]source1_4_2;
wire signed[3:0]source1_4_3;
wire signed[3:0]source1_4_4;
wire signed[3:0]source2_4_1;
wire signed[3:0]source2_4_2;
wire signed[3:0]source2_4_3;
wire signed[3:0]source2_4_4;
wire signed[3:0]source3_4_1;
wire signed[3:0]source3_4_2;
wire signed[3:0]source3_4_3;
wire signed[3:0]source3_4_4;

reg [15:0]result_reg;
reg [31:0]mul_reg;

reg[91:0] pip_reg;
reg [6:0] instrc_add;  

assign scr_r=opcode[3:0];
assign op_r=opcode[6:4];
assign mac_hl=funct7[1:0];

//----------program connter------------//
always @(posedge clk)
    begin
        if(!rst)
            instrc_add<=0;
        else
            instrc_add<=n_instrc_add;
    end

//------------control unit-------------//

//----countrol signal of the SIMD mode in the ALU-----//
//-------01:represent for 1 16_bit operation---------//
//-------10:represent for 2 8_bit operation----------//
//-------11:represent for 4 4_bit operation---------//
//-------00:represent for nothing-------------------//
assign mode=(funct3==3'b001)? 2'b01:
            (funct3==3'b010)? 2'b10:
            (funct3==3'b100)? 2'b11:2'b00;

//-----------control signal of ALU second source operand-----------------//
//--1: represent that the second source operand is from immediate field--//
//--0: represent that the second source operand is from register file----//
assign scr=(scr_r==4'b0011)? 1:0;

//-----------------control signal of ALU operation-----------------//
//--decode the opcode and funct7 then will get the operation sign--//
always @ (opcode or funct7 or mac_hl)
    begin
        case (opcode)
            7'b0111011:begin
                            case(funct7)
                                7'b0000000: op=13'b0000_0000_0000_1; //add
                                7'b0100000: op=13'b0000_0000_0001_0; //sub
                                7'b1000001: op=13'b0000_0000_0010_0; //mul
                                7'b1000010: op=13'b0000_0000_0100_0; //mulh
                                7'b0001000: op=13'b0000_0000_1000_0; //and
                                7'b0010000: op=13'b0000_0001_0000_0; //or
                                7'b0011000: op=13'b0000_0010_0000_0; //xor
                                7'b0110000: op=13'b0000_0100_0000_0; //not
                                default:op=13'b0000_0000_0000_0; //nothing
                            endcase
                        end
             7'b1001011:begin
                            case(mac_hl)
                                2'b01:op=13'b0000_1000_0000_0; //madd
                                2'b10:op=13'b0001_0000_0000_0; //maddh
                                default:op=13'b0000_0000_0000_0; //nothing
                            endcase
                        end
             7'b0100011:op=13'b0010_0000_0000_0; //shilt left logic immediate
             7'b1100011:op=13'b0100_0000_0000_0; //shilt right logic immediate
             7'b1010011:op=13'b1000_0000_0000_0; //shilt left arithematic immediate
             default:op=13'b0000_0000_0000_0; //nothing
        endcase                                   
    end
//---------control unit end --------------//

//------------sign extension-------------//
assign sig_ex={{4{immed[10]}},immed};
//--------sign extension end------------//

//------next instruction address----------//
assign n_instrc_add=instrc_add+3'b100;
//-----next instruction address end-------//

//----------seconde pipeline-------------//
always @(posedge clk)
    begin
        if(!rst)
            pip_reg <=0;
        else
            begin
                pip_reg[1:0]<=mode; //2 bit
                pip_reg[14:2]<=op; //13 bit
                pip_reg[15]<=scr; //1 bit
                pip_reg[31:16]<= rd_data1; //16 bit
                pip_reg[47:32]<= rd_data2; //16 bit
                pip_reg[63:48]<= rd_data3; //16 bit
                pip_reg[68:64]<= w_add; //5 bit
                //pip_reg[75:69]<= n_instrc_add;//7 bit
                pip_reg[91:76]<= sig_ex;//16 bit
            end 
    end



assign alu_mode=pip_reg[1:0];
assign alu_op=pip_reg[14:2];
assign alu_scr=pip_reg[15];
assign source1=pip_reg[31:16];
assign data2=pip_reg[47:32];
assign source3=pip_reg[63:48];
assign wr_add=pip_reg[68:64];
//assign nex_instrc_add=pip_reg[75:69];
assign exsig_data=pip_reg[91:76];

//----------mux for second source operand definition--------//
assign source2=(alu_scr==1'b0)? data2:exsig_data;

//-----------------------------ALU unit----------------------------//
//-----------------Below is the ALU unit which carrys -------------//
//-------------------all the calculation operation-----------------//
assign source1_8_1=source1[7:0];
assign source1_8_2=source1[15:8];
assign source2_8_1=source2[7:0];
assign source2_8_2=source2[15:8];
assign source3_8_1=source3[7:0];
assign source3_8_2=source3[15:8];
assign source1_4_1=source1[3:0];
assign source1_4_2=source1[7:4];
assign source1_4_3=source1[11:8];
assign source1_4_4=source1[15:12];
assign source2_4_1=source2[3:0];
assign source2_4_2=source2[7:4];
assign source2_4_3=source2[11:8];
assign source2_4_4=source2[15:12];
assign source3_4_1=source3[3:0];
assign source3_4_2=source3[7:4];
assign source3_4_3=source3[11:8];
assign source3_4_4=source3[15:12];


always @(alu_op or alu_mode or source1 or source2 or source3 or source1_8_1 or source1_8_2 or 
         source2_8_1 or source2_8_2 or source3_8_1 or source3_8_2 or source1_4_1 or source1_4_2 or
         source1_4_3 or source1_4_4 or source2_4_1 or source2_4_2 or source2_4_3 or source2_4_4 or
         source3_4_1 or source3_4_2 or source3_4_3 or source3_4_3 or source3_4_4)
    begin
        mul_reg=0;
        result_reg=0;
        case(alu_op)
           13'b0000_0000_0000_1:begin
                                    case(alu_mode)
                                        2'b01:result_reg=source1+source2; //1 16-bit add
                                        2'b10:result_reg={source1_8_2+source2_8_2,source1_8_1+source2_8_1}; //2 8_bit add
                                        2'b11:result_reg={source1_4_4+source2_4_4,source1_4_3+source2_4_3,source1_4_2+source2_4_2,source1_4_1+source2_4_1}; //4 4_bit add
                                        default:result_reg=0;
                                    endcase
                                end
           13'b0000_0000_0001_0:begin
                                    case(alu_mode)
                                        2'b01:result_reg=source1-source2; //1 16-bit add
                                        2'b10:result_reg={source1_8_2-source2_8_2,source1_8_1-source2_8_1}; //2 8_bit add
                                        2'b11:result_reg={source1_4_4-source2_4_4,source1_4_3-source2_4_3,source1_4_2-source2_4_2,source1_4_1-source2_4_1}; //4 4_bit sub
                                        default:result_reg=0;                       
                                    endcase
                                end
           13'b0000_0000_0010_0:begin
                                    case(alu_mode)
                                        2'b01:begin
                                                mul_reg=source1*source2; //1 16_bit mul
                                                result_reg=mul_reg[15:0]; //get tthe lower 16bit result of the multiplication
                                              end
                                        2'b10:begin
                                                mul_reg[15:0]=source1_8_1*source2_8_1; //2 8-bit mul
                                                mul_reg[31:16]=source1_8_2*source2_8_2;
                                                result_reg={mul_reg[23:16],mul_reg[7:0]};//get the lower 8bit result of each multiplication
                                              end
                                        2'b11:begin
                                                mul_reg[7:0]=source1_4_1*source2_4_1; // 4 4_bit mul
                                                mul_reg[15:8]=source1_4_2*source2_4_2;
                                                mul_reg[23:16]=source1_4_3*source2_4_3;
                                                mul_reg[31:24]=source1_4_4*source2_4_4;
                                                result_reg={mul_reg[27:24],mul_reg[19:16],mul_reg[11:8],mul_reg[3:0]};//get the lower 4bit result of each multiplication
                                              end
                                        default:begin
                                                    result_reg=0;
                                                    mul_reg=0;
                                                end
                                    endcase
                                end
           13'b0000_0000_0100_0:begin
                                    case(alu_mode)
                                        2'b01:begin 
                                                mul_reg=source1*source2; //1 16_bit mulh
                                                result_reg=mul_reg[31:16]; //get tthe higher 16bit result of the multiplication
                                              end
                                        2'b10:begin
                                                mul_reg[15:0]=source1_8_1*source2_8_1; //2 8-bit mulh
                                                mul_reg[31:16]=source1_8_2*source2_8_2;
                                                result_reg={mul_reg[31:24],mul_reg[15:8]};//get the higher 8bit result of each multiplication
                                              end
                                        2'b11:begin
                                                mul_reg[7:0]=source1_4_1*source2_4_1; // 4 4_bit mulh
                                                mul_reg[15:8]=source1_4_2*source2_4_2;
                                                mul_reg[23:16]=source1_4_3*source2_4_3;
                                                mul_reg[31:24]=source1_4_4*source2_4_4;
                                                result_reg={mul_reg[31:28],mul_reg[23:20],mul_reg[15:12],mul_reg[7:4]};//get the higher 4bit result of each multiplication
                                              end
                                        default:begin
                                                    result_reg=0;
                                                    mul_reg=0;
                                                end
                                    endcase
                                end
           13'b0000_0000_1000_0:result_reg=source1&source2; //bitwise and
           13'b0000_0001_0000_0:result_reg=source1|source2; //bitwise or
           13'b0000_0010_0000_0:result_reg=source1^source2; //bitwise xor
           13'b0000_0100_0000_0:result_reg=~source1; //bitwise not
           13'b0000_1000_0000_0:begin
                                    case(alu_mode)
                                        2'b01:begin
                                                mul_reg=source1*source2+{{16{1'b0}},source3}; //1 16_bit mac
                                                result_reg=mul_reg[15:0]; //get tthe lower 16bit result of the multiplication and addition
                                              end
                                        2'b10:begin
                                                mul_reg[15:0]=source1_8_1*source2_8_1+{{8{1'b0}},source3_8_1}; //2 8-bit mac
                                                mul_reg[31:16]=source1_8_2*source2_8_2+{{8{1'b0}},source3_8_2};
                                                result_reg={mul_reg[23:16],mul_reg[7:0]};//get the lower 8bit result of each multiplication and addition
                                              end
                                        2'b11:begin
                                                mul_reg[7:0]=source1_4_1*source2_4_1+{{4{1'b0}},source3_4_1}; // 4 4_bit mac
                                                mul_reg[15:8]=source1_4_2*source2_4_2+{{4{1'b0}},source3_4_2};
                                                mul_reg[23:16]=source1_4_3*source2_4_3+{{4{1'b0}},source3_4_3};
                                                mul_reg[31:24]=source1_4_4*source2_4_4+{{4{1'b0}},source3_4_4};
                                                result_reg={mul_reg[27:24],mul_reg[19:16],mul_reg[11:8],mul_reg[3:0]};//get the lower 4bit result of each multiplication and addition+source3_4_1
                                              end
                                        default:begin
                                                    result_reg=0;
                                                    mul_reg=0;
                                                end
                                    endcase
                                end
           13'b0001_0000_0000_0:begin
                                    case(alu_mode)
                                        2'b01:begin
                                                mul_reg=source1*source2+{{16{1'b0}},source3}; //1 16_bit mach
                                                result_reg=mul_reg[31:16]; //get tthe higher 16bit result of the multiplication and addition
                                              end
                                        2'b10:begin
                                                mul_reg[15:0]=source1_8_1*source2_8_1+{{8{1'b0}},source3_8_1}; //2 8-bit mach
                                                mul_reg[31:16]=source1_8_2*source2_8_2+{{8{1'b0}},source3_8_2};
                                                result_reg={mul_reg[31:24],mul_reg[15:8]};//get the higher 8bit result of each multiplication and addition
                                              end
                                        2'b11:begin
                                                mul_reg[7:0]=source1_4_1*source2_4_1+{{4{1'b0}},source3_4_1}; // 4 4_bit mach
                                                mul_reg[15:8]=source1_4_2*source2_4_2+{{4{1'b0}},source3_4_2};
                                                mul_reg[23:16]=source1_4_3*source2_4_3+{{4{1'b0}},source3_4_3};
                                                mul_reg[31:24]=source1_4_4*source2_4_4+{{4{1'b0}},source3_4_4};
                                                result_reg={mul_reg[31:28],mul_reg[23:20],mul_reg[15:12],mul_reg[7:4]};//get the higher 4bit result of each multiplication and addition
                                              end
                                        default:begin
                                                    result_reg=0;
                                                    mul_reg=0;
                                                end                                    
                                    endcase
                                end
           13'b0010_0000_0000_0:result_reg=(source1<<source2); //shift left logical immediate
           13'b0100_0000_0000_0:result_reg=(source1>>source2); //shift right logical immediate
           13'b1000_0000_0000_0:result_reg=(source1<<<source2); //shilt left arithematic immediate=result_reg;
           default:result_reg=0;
        endcase
    end
    
assign wr_data=result_reg;
endmodule
