module mips32(
	input[17:0]	SW, 	 	// Switches
	input		CLOCK_50,	// clock da placa
	input[3:0]		KEY, 	// Keys
	output[8:0]		LEDG,	// LEDs verdes
	output[0:6]		HEX0,	// Display de 7 segmentos 0
	output[0:6]		HEX1,	// Display de 7 segmentos 1
	output[0:6]		HEX2,	// Display de 7 segmentos 2
	output[0:6]		HEX3,	// Display de 7 segmentos 3
	output[0:6]		HEX4,	// Display de 7 segmentos 4
	output[0:6]		HEX5,	// Display de 7 segmentos 5
	output[0:6]		HEX6,	// Display de 7 segmentos 6
	output[0:6]		HEX7	// Display de 7 segmentos 7
);


// Banco de Registradores
reg [31:0] registers [31:0];//banco de registradores

// Controle
reg [31:0] clk;
reg [31:0] PC;
reg mem_write;
reg bitzero;
reg [1:0] desvio;			// 00 para nenhum desvio, 01 para desvio de branch, 10 para desvio de jump
integer i;

// Registradores de pipeline
reg [63:0] 	FD; 			// Fetch/Decode 		-	[32] PC - [32] Instrução
reg [127:0] DE;				// Decode/Execute 		-	[32] PC - [32] Conteúdo de Rs - [32] Conteúdo de Rt - [32] Instrução
reg [127:0] EM;				// Execute/Memory		- 	[32] PC - [32] Saída da ALU - [32] Conteúdo de Rt - [32] Instrução
reg [63:0] MW;				// Memory/Write Back	-	[32] Saída da ALU - [32] Instrução

// Auxiliares
reg [63:0] 	Buffer_FD; 		// Fetch/Decode 		- 	[32] PC - [32] Instrução
reg [127:0] Buffer_DE;		// Decode/Execute 		-	[32] PC - [32] Conteúdo de Rs - [32] Conteúdo de Rt - [32] Instrução
reg [127:0] Buffer_EM;		// Execute/Memory		- 	[32] PC - [32] Saída da ALU - [32] Conteúdo de Rt - [32] Instrução
reg [63:0] Buffer_MW;		// Memory/Write Back	-	[32] Saída da ALU - [32] Instrução
reg [95:0] Buffer_LW;		// Aux para escrita no WB - [32] Saída da memória - [32] Saída da ALU - [32] Instrução

reg [31:0] ImmedSE;
reg [31:0] ImmedZE;
reg [31:0] EndBranch;
reg [31:0] saida_ula;

// Memória 
// Impossível fazer uma memória de instruções com 2^32 posições, embora PC tenha 32 bits, a memória apenas recebe os 10 primeiros
wire [31:0] out_mem_inst;
wire [31:0] out_mem_data;

mem_inst mem_i(.address(PC),.clock(clk[25]),.q(out_mem_inst));
mem_data mem_d(.address(EM[73:64]),.clock(clk[25]),.data(EM[63:32]),.wren(mem_write),.q(out_mem_data));

// Display
reg [31:0] entradamux; 		//para selecionar a saída desejada nos dispays

always@(SW[5:0])
	begin
	case(SW[5:0])
		6'b000000: entradamux = registers[0];
		6'b000001: entradamux = registers[1];
		6'b000010: entradamux = registers[2];
		6'b000011: entradamux = registers[3];
		6'b000100: entradamux = registers[4];
		6'b000101: entradamux = registers[5];
		6'b000110: entradamux = registers[6];
		6'b000111: entradamux = registers[7];
		6'b001000: entradamux = registers[8];
		6'b001001: entradamux = registers[9];
		6'b001010: entradamux = registers[10];
		6'b001011: entradamux = registers[11];
		6'b001100: entradamux = registers[12];
		6'b001101: entradamux = registers[13];
		6'b001110: entradamux = registers[14];
		6'b001111: entradamux = registers[15];
		6'b010000: entradamux = registers[16];
		6'b010001: entradamux = registers[17];
		6'b010010: entradamux = registers[18];
		6'b010011: entradamux = registers[19];
		6'b010100: entradamux = registers[20];
		6'b010101: entradamux = registers[21];
		6'b010110: entradamux = registers[22];
		6'b010111: entradamux = registers[23];
		6'b011000: entradamux = registers[24];
		6'b011001: entradamux = registers[25];
		6'b011010: entradamux = registers[26];
		6'b011011: entradamux = registers[27];
		6'b011100: entradamux = registers[28];
		6'b011101: entradamux = registers[29];
		6'b011110: entradamux = registers[30];
		6'b011111: entradamux = registers[31];
		6'b100000: entradamux = PC; 					//32, só o 6o switch ativo
		6'b100001: entradamux = saida_ula; 				//33 é saida ula: 6o e 1o switches ativados
		default: entradamux = 32'b0;
	endcase
	end
	
//exibe nos 8 displays
displayDecoder DP_0(.entrada(entradamux[3:0]), .saida(HEX0));
displayDecoder DP_1(.entrada(entradamux[7:4]), .saida(HEX1));
displayDecoder DP_2(.entrada(entradamux[11:8]), .saida(HEX2));
displayDecoder DP_3(.entrada(entradamux[15:12]), .saida(HEX3));
displayDecoder DP_4(.entrada(entradamux[19:16]), .saida(HEX4));
displayDecoder DP_5(.entrada(entradamux[23:20]), .saida(HEX5));
//displayDecoder DP_6(.entrada(entradamux[27:24]), .saida(HEX6));
//displayDecoder DP_7(.entrada(entradamux[31:28]), .saida(HEX7));

//Para testes da saida_ula, bitzero e registradores:
displayDecoder DP_6(.entrada(PC[3:0]), .saida(HEX6));
displayDecoder DP_7(.entrada(PC[7:4]), .saida(HEX7));

//Exibe o bitzero: sempre que for ativo, o led verde ao lado do clock acende,
//e quando estiver inativo o led verde ao lado do clock fica apagado
assign LEDG[1] = bitzero;

//pra acompanhar o clock
assign LEDG[0] = clk[25];

// Clock
always@(posedge CLOCK_50)begin
	clk = clk + 1;
end

// Pipeline
always@(posedge clk[25])
begin

// ~~~~~~~*~~~~ Fetch ~~~~*~~~~~~~~ //

	Buffer_FD[31:0] = out_mem_inst;  			//instrução
	Buffer_FD[63:32] = PC + 1;					//PC da próxima instrução
		
// ~~~~~~~*~~~~ Decode ~~~~*~~~~~~~~ //

	Buffer_DE[31:0] = FD[31:0];					//instrução
	Buffer_DE[63:32] = registers[FD[20:16]];	//conteúdo do registrador rt
	Buffer_DE[95:64] = registers[FD[25:21]];	//conteúdo do registrador rs
	
	if(FD[31:26]==6'b000010) 					//jump
	begin
		Buffer_DE[127:96] = {6'b0, FD[25:0]};	//novo PC
	end
	else
	begin
		Buffer_DE[127:96] = FD[63:32];			//mantém PC antigo
	end

// ~~~~~~~*~~~~ Execute ~~~~*~~~~~~~~ //

	// Instruções Tipo R
	if(DE[31:26] == 6'b000000) //opcode
	begin
		case(DE[5:0]) //funct
			6'b100000: saida_ula = DE[95:64] + DE[63:32];			//add;
			6'b100010: saida_ula = DE[95:64] - DE[63:32]; 			//sub;
			6'b100100: saida_ula = DE[95:64] & DE[63:32]; 			//and;
			6'b100101: saida_ula = DE[95:64] | DE[63:32]; 			//or;
			6'b100111: saida_ula = ~ (DE[95:64] | DE[63:32]);		//nor;
			6'b100110: saida_ula = DE[95:64] ^ DE[63:32]; 			//xor;
			6'b101010: 
						begin										//slt;								
							if (DE[95:64] < DE[63:32])
							begin
								saida_ula = 1;
							end
							else
							begin
								saida_ula = 0;
							end
						end
			6'b000000: saida_ula = DE[63:32] << DE[10:6];			//sll;
			6'b000010: saida_ula = DE[63:32] >> DE[10:6];			//srl;
		endcase
	end			
		
	// Instruções do Tipo I
	else
	begin

		ImmedSE = {{16{DE[15]}}, DE[15:0]};
		ImmedZE = {16'b0, DE[15:0]};  						
		EndBranch = {{16{DE[15]}}, DE[15:0]};	//**compilar depois

		case (DE[31:26])   //opcode
			6'b001000: saida_ula = DE[95:64] + ImmedSE;				//addi
			6'b100011: saida_ula = DE[95:64] + ImmedSE;				//lw
			6'b101011: saida_ula = DE[95:64] + ImmedSE;				//sw
			6'b001100: saida_ula = DE[95:64] & ImmedZE;				//andi
			6'b001101: saida_ula = DE[95:64] | ImmedZE;				//ori
			6'b001010: 	
						begin										//slti
							if (DE[95:64] < ImmedSE)
							begin
								saida_ula = 1;
							end
							else
							begin
								saida_ula = 0;
							end
						end
			6'b000100: saida_ula = DE[95:64] - DE[63:32];			//beq
			6'b000101: saida_ula = DE[95:64] - DE[63:32];			//bne
			6'b111111: saida_ula = 32'b1;							//stall, só p nao ativar o bitzero por acaso
		endcase
		
		// Cáculo do PC

		case(DE[31:26]) //opcode
			6'b000100: Buffer_EM[127:96] = DE[127:96] + EndBranch;	//beq
			6'b000101: Buffer_EM[127:96] = DE[127:96] + EndBranch;	//bne
			default: Buffer_EM[127:96] = DE[127:96];				//outras
		endcase	
	end
	
	// Bit Zero

	if (saida_ula == 0)
	begin
		bitzero = 1;
	end
	else
	begin
		bitzero = 0;
	end
	
	Buffer_EM[31:0] = DE[31:0];			//instrução lida
	Buffer_EM[63:32] = DE[63:32];		//conteúdo de rt ---lido no decode---
	Buffer_EM[95:64] = saida_ula;		//saida_ula
		
// ~~~~~~~*~~~~ Memory ~~~~*~~~~~~~~ //

	Buffer_MW[31:0] = EM[31:0];			//instrução lida
	Buffer_MW[63:32] = EM[95:64];		//saida_ula
		
// ~~~~~~*~~~ Write Back ~~~*~~~~~~~ //
		
	Buffer_LW [63:0] = MW [63:0];
	Buffer_LW [95:64] = out_mem_data;
	
end


// Escrita dos Registradores de Pipeline
always@(negedge clk[25])
begin
	
	//Reseta a máquina ao apertar a key[0]
	if(KEY[0] == 0)
	begin
		
		//gerando stall nos estágios do pipeline quando resetado
		//instrução stall (opcode stall)
		FD[31:26] = 6'b1;
		DE[31:26] = 6'b1;
		EM[31:26] = 6'b1;
		MW[31:26] = 6'b1;
		
		PC = 32'b0;
		desvio = 00;
		
		for(i = 0; i < 32; i = i + 1)
			begin
			registers[i] = 32'b0;
			end
		
		registers[0] = 4'h0001;
	end

	else
	begin
	
	//execução do multiciclo
	
	//~~~~~~~*~~~~ Seleção do proximo PC ~~~~~~*~~~~//

		if(Buffer_DE[31:26]==6'b000010) 		//Se é um jump, jump. Se a instrução no estágio execute era um branch tomado, ela sobrescreve o jump
		begin
			PC = Buffer_DE[127:96];
			desvio = 01;
		end


		if(Buffer_EM[31:26]==6'b000101) 		//Se são branches, verifica a saída da ula. Se é branch tomado, executa o branch.
		begin
		   if(Buffer_EM[95:64]!=0)
			begin
				PC = Buffer_EM[127:96];
				desvio = 10;
			end			
		end
		else if(Buffer_EM[31:26]==6'b000100)
		begin
			if(Buffer_EM[95:64]==0)
			begin
				PC = Buffer_EM[127:96];
				desvio = 10;
			end			
		end
		else 									//sem desvios ou branches
		begin
			PC = Buffer_FD[63:32];
			desvio = 00;
		end
	
	// ~~~~~~~*~~~~ Fetch ~~~~*~~~~~~~~ //
	
		//após a execução do fetch
		if (desvio == 00)
		begin
			FD = Buffer_FD;
		end
		else									//jump e branch geram stall na instrução buscada no estágio em que eles foram tomados
		begin
			FD[31:26] = 6'b1;
		end

	// ~~~~~~~*~~~~ Decode ~~~~*~~~~~~~~ //
	
		//após a execução do decode
		if ((desvio == 00) || (desvio == 01))
		begin
			DE = Buffer_DE;
		end
		else									//branches geram stall na instrução que foi decodificada quando ele foi tomado.
		begin
			DE[31:26] = 6'b1;
		end

	// ~~~~~~~*~~~~ Execute ~~~~*~~~~~~~~ //

		//após a execução do execute
		EM = Buffer_EM;

	// ~~~~~~~*~~~~ Memory ~~~~*~~~~~~~~ //
		
		//após a execução do memory
		MW = Buffer_MW;
		
	// ~~~~~~*~~~ Write Back ~~~*~~~~~~~ //
		
		case(Buffer_LW[31:26])
			6'b000000: registers[Buffer_LW[15:11]] = Buffer_LW[63:32];				//tipo R
			6'b001000: registers[Buffer_LW[20:16]] = Buffer_LW[63:32];				//addi
			6'b001100: registers[Buffer_LW[20:16]] = Buffer_LW[63:32];				//andi
			6'b001101: registers[Buffer_LW[20:16]] = Buffer_LW[63:32];				//ori
			6'b001010: registers[Buffer_LW[20:16]] = Buffer_LW[63:32];				//slti
			6'b100011: registers[Buffer_LW[20:16]] = Buffer_LW[95:64];				//lw
			default: Buffer_LW = 0;													//stall, jumps, branches, stores
		endcase
	
	end
end


// Controle de escrita na memória de dados
always@(EM)
begin
	if (EM[31:26] == 6'b101011)
		begin
		mem_write = 1;
		end

	else
		begin
		mem_write = 0;
		end
end

endmodule
