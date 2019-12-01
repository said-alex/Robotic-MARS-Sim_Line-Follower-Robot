### DEFINICAO DOS REGISTRADORES E CONSTANTES  ###

#Constantes de deslocamento entre pixel
.eqv right 		4
.eqv left 		-4
.eqv down 		512
.eqv up 		-512
#Constantes para os limites dos geradores de posição aleatoria
.eqv lo_limit	268698632
.eqv hi_limit	268729320
#Registradores para as cores
.eqv white 		$s0
.eqv green 		$s1
.eqv blue 		$s2
.eqv pink 		$s3
.eqv black 		$s4
.eqv colorful	$t0
.eqv color_tmp 	$t1
#Registradores para o endereco dos pixels
.eqv position 	$s5
.eqv pos_tmp 	$s6
#Registradores para os estados de deslocamento 
.eqv curr_st 	$s7
.eqv next_st 	$t2
.eqv right_pix 	$t3
.eqv left_pix 	$t4
.eqv bottom_pix	$t5
.eqv upper_pix 	$t6
#Registradores para iteradores e variaveis temporarias
.eqv i1 		$t7
.eqv i2 		$t8
.eqv i3			$t9

### DEFINICAO DAS MACRO FUNCOES ###

#Loop for generico
.macro For (%it, %from, %to, %begin, %end)	
	li %it, %from								#Inicializa o iterador em %from
loop:
	bgt %it, %to, %end 							#Sai do loop quando o iterador for maior que %to
	jal %begin									#Executa %begin a cada loop
	addi %it, %it, 1							#Incrementa o iterador em 1
	j loop
.end_macro

#Funcao sleep para controlar a velocidade dos eventos
.macro Sleep (%milisec)
	li $v0, 32
	li $a0, %milisec
	syscall
.end_macro

#Gera um numero aleatorio de %from a % t o - 1
.macro Get_rnd (%rnd, %from, %to) 
	li $a1, %to		
	sub $a1, $a1, %from							#Ajusta o limite superior
	li $v0, 42
	syscall
	add $a0, $a0, %from							#Ajusta o limite inferior
	move %rnd, $a0 								#Move o valor aleatorio de $a0 para %rnd
.end_macro 

#Sincroniza a posicao aleatoria  do pixel para uma posicao valida dentro das configuracoes do bitmap
.macro Sync_pos (%position) 
	div %position, %position, right
	mul %position, %position, right
.end_macro

#Pinta o pixel em %position com %color 
.macro Paint_pix (%position, %color)
	sw %color, (%position)	
.end_macro

# Desloca posicao atual um pixel para a direcao  %direction
.macro Shift_pos (%position, %direction)
	add %position, %position, %direction	
.end_macro

#Armazena em %var a cor do pixel proximo a %position em %direction
.macro Get_pix_color (%v, %position, %direction)
	add %v, %position, %direction
	lw %v, (%v)
.end_macro

#Move o robo 1 pixel para %dierction
.macro Move_robot (%direction, %color)
	Sleep (15)
	Paint_pix (position, %color)				#Pinta o pixel da posicao atual com %color
	Shift_pos (position, %direction)			#Desloca a posicao 1 pixel para %direction
	Paint_pix (position, pink)					#Pinta o pixel da nova posicao com a cor do robo
.end_macro 

#Pinta os pixels do trajeto de azul
.macro Paint_line (%direction, %steps, %state)
	move i3, $ra
	For (i2, 1, %steps, begin, end)
begin:
	li pos_tmp, %direction
	mul pos_tmp, pos_tmp, 2
	add pos_tmp, pos_tmp, position
	lw color_tmp, (pos_tmp)
	bne color_tmp, black, end 
	addi pos_tmp, pos_tmp, %direction
	lw color_tmp, (pos_tmp)
	bne color_tmp, black, end
	Shift_pos (position, %direction) 			#Pinta os 2 pixels a frente a cada passo se os proximos 3 forem pretos
	Paint_pix (position, blue)
	Shift_pos (position, %direction)
	Paint_pix (position, blue)
	jr $ra
end:
	move $ra, i3
	beq i2, 1, exit
	li curr_st, %state							#Atualiza o estado atual se houve mudanca de direcao:
	
exit:
.end_macro 

#Controla o movimento do robo durante a localizacao do trajeto
.macro Get_moving  (%direction, %steps)
	For (i1, 1, %steps, begin, end)
begin:
	Get_pix_color (color_tmp, position, right)
	beq color_tmp, blue, end
	Get_pix_color (color_tmp, position, left)
	beq color_tmp, blue, end
	Get_pix_color (color_tmp, position, down)
	beq color_tmp, blue, end
	Get_pix_color (color_tmp, position, up)
	beq color_tmp, blue, end
	Get_pix_color (color_tmp, position, %direction)
	beq color_tmp, white, end
	beq color_tmp, green, end
	Move_robot (%direction, black)				#Move o robo se nao houver borda a frente ou nao estiver proximo ao trajeto
	jr $ra
end:
.end_macro 

#Desenha uma borda branca 
.macro Draw_edge (%direction, %size)
	For (i1, 1, %size, begin, end) 
begin:
	Paint_pix (position, white)
	Shift_pos (position, %direction)
	jr $ra
end:
.end_macro

#Define o inicio do trajeto
.macro Set_route_start ()
	Get_rnd (position, lo_limit, hi_limit)
	Sync_pos (position)
	lw color_tmp, (position)
	bne color_tmp, white, shift_left
	li i1, 3
	mul  i1, i1, right
	Shift_pos (position, i1)		 			#Corrige para 3 pixels a direita se position estiver sobre a borda
	j exit
	
shift_left:
	addi pos_tmp, position, right
	lw pos_tmp, (pos_tmp)
	bne pos_tmp, white, shift_right
	Shift_pos (position, left) 					#Corrige para 1 pixel a esquerda se position estiver proximo a borda da direita
	j exit
	
shift_right:
	addi pos_tmp, position, left
	lw pos_tmp, (pos_tmp)
	bne pos_tmp, white, exit
	Shift_pos (position, right)					#Corrige para 1 pixel a direita se position estiver proximo a borda da esquerda
	
exit:
	Paint_pix (position, green)
.end_macro 

#Desenha um trajeto aleatorio no bitmap display
.macro Draw_route (%branchs, %steps)
	Get_rnd (curr_st, 0, 4)						#Define um  estado  inicial
	For (i1, 1, %branchs, begin, end)
begin:
	Get_rnd (next_st, 0, 3)						#Define a proxima direcao do trajeto de acordo com a direcao anterior
	bne curr_st, 0, curr_state1
	beq next_st, 0, draw_right
	beq next_st, 1, draw_down
	j draw_up
	
curr_state1:		
	bne curr_st, 1, curr_state2
	beq next_st, 0, draw_left
	beq next_st, 1, draw_down
	j draw_up
	
curr_state2:
	bne curr_st, 2, curr_state3
	beq next_st, 0, draw_down
	beq next_st, 1, draw_right
	j draw_left
	
curr_state3:
	beq next_st, 0, draw_up
	beq next_st, 1, draw_right
	j draw_left
	
draw_right:
	Paint_line (right, %steps, 0)
	jr $ra	
	
draw_left:
	Paint_line (left, %steps, 1)
	jr $ra	
	
draw_down:
	Paint_line (down, %steps, 2)
	jr $ra	
	
draw_up:
	Paint_line (up, %steps, 3)
	jr $ra       
end:
	Paint_pix (position, green)		
.end_macro 

#Define a posicao inicial do robo
.macro Set_robot_pos ()
loop:
	Get_rnd (position, lo_limit, hi_limit) 
	Sync_pos (position)
	lw color_tmp, (position)
	bne color_tmp, black, loop					#Repete se o pixel da posicao nao for preto
	Paint_pix (position, pink) 	
	Sleep (1000)
.end_macro 

#Busca a localizacao do trajeto no display
.macro Locate_route ()
loop:
	beq color_tmp, blue, exit					#Sai se estiver proximo ao trajeto
	beq color_tmp, green, exit 
	Get_rnd (curr_st, 0, 4)						#Define aleatoriamente a proxima direcao
	beq curr_st, 0, move_right
	beq curr_st, 1, move_left
	beq curr_st, 2, move_down
	j move_up
	
move_right:		
	Get_moving (right, 32)
	j loop
	
move_left:
	Get_moving (left, 32)
	j loop
	
move_down:
	Get_moving (down, 32)
	j loop
	
move_up:
	Get_moving (up, 32)
	j loop
	
exit:
.end_macro 

#Define o proximo estado de deslocamento do robo
.macro Get_next_state (%direction, %v1, %v2, %v3)
	seq i1, %v1, blue							#Transforma a informacao dos pixels ao redor em valores booleanos
	seq i2, %v2, blue
	seq i3, %v3, blue
	bne i2, 0, in_101							#Define a proxima direcao de acordo com a tabela de transicao
	bne i3, 0, in_101
	li i1, %direction			
	mul i1, i1, -1
	move pos_tmp, position
	Shift_pos (pos_tmp, i1)
	bge curr_st, 2, right_left
	Get_pix_color (color_tmp, pos_tmp, down)
	beq color_tmp, blue, move_down
	Get_pix_color (color_tmp, pos_tmp, up)
	beq color_tmp, blue, move_up
	Get_rnd (curr_st, 2, 4)
	beq curr_st, 2, move_down
	j move_up
	
right_left:
	Get_pix_color (color_tmp, pos_tmp, right)
	beq color_tmp, blue, move_right
	Get_pix_color (color_tmp, pos_tmp, left)
	beq color_tmp, blue, move_left
	Get_rnd (curr_st, 0, 2)
	beq curr_st, 0, move_right
	j move_left

in_101:
	bne i1, 1, in_110
	bne i2, 0, in_110
	bne i3, 1, in_110
	blt curr_st, 2, move_down
	j move_right
	
in_110:
	bne i1, 1, in_111
	bne i2, 1, in_111
	bne i3, 0, in_111
	blt curr_st, 2, move_up
	j move_left
	
in_111:
	bne i1, 1, default
	bne i2, 1, default
	bne i3, 1, default
	beq curr_st, 0, move_left
	beq curr_st, 1, move_right
	beq curr_st, 2, move_up
	beq curr_st, 3, move_down
	
move_right:
	Move_robot (right, black)
	li curr_st, 0
	j exit
	
move_left:
	Move_robot (left, black)
	li curr_st, 1
	j exit
	
move_down:
	Move_robot (down, black)
	li curr_st, 2
	j exit
	
move_up:
	Move_robot (up, black)
	li curr_st, 3
	j exit
	
default:
	Move_robot (%direction, black)				#Mantem o estado atual (nao muda de direcao)
	
exit:
.end_macro

#Segue a borda do trajeto ate encontrar uma das extremidades
.macro Find_route_start ()
loop:
	Get_pix_color (right_pix, position, right)	#Sai do loop quando encontra o pixel verde
	beq right_pix, green, move_right
	Get_pix_color (left_pix, position, left)
	beq left_pix, green, move_left
	Get_pix_color (bottom_pix, position, down)
	beq bottom_pix, green, move_down
	Get_pix_color (upper_pix, position, up)
	beq upper_pix, green, move_up
													
	beq curr_st, 0, curr_state0					
	beq curr_st, 1, curr_state1
	beq curr_st, 2, curr_state2
	j curr_state3
	
curr_state0:
	Get_next_state (right, right_pix, bottom_pix, upper_pix)
	j loop
	
curr_state1:
	Get_next_state (left, left_pix, bottom_pix, upper_pix)
	j loop
	
curr_state2:
	Get_next_state (down, bottom_pix, right_pix, left_pix)
	j loop
	
curr_state3:
	Get_next_state (up, upper_pix, right_pix, left_pix)	
	j loop
	
move_right:
	Move_robot (right, black)
	j exit
	
move_left:
	Move_robot (left, black)
	j exit
	
move_down:
	Move_robot (down, black)
	j exit
	
move_up:
	Move_robot (up, black)
	
exit:
.end_macro

#Percorre o trajeto
.macro Follow_route
loop:
	addi  colorful, colorful, 0x0EF0DA     		#Incrementa a cor a cada loop para dar o efeito colorido
	Get_pix_color (color_tmp, position, right)	#Verifica a informacao dos pixels proximos
	beq color_tmp, blue, move_right			
	Get_pix_color (color_tmp, position, left)
	beq color_tmp, blue, move_left
	Get_pix_color (color_tmp, position, down)
	beq color_tmp, blue, move_down
	Get_pix_color (color_tmp, position, up)
	beq color_tmp, blue, move_up
	j exit
	
move_right:
	Move_robot (right, colorful)
	li curr_st, 0
	Get_pix_color (color_tmp, position, right)
	bne color_tmp, green, loop
	Move_robot (right, colorful)	
	j exit

move_left:
	Move_robot (left, colorful)
	li curr_st, 1
	Get_pix_color (color_tmp, position, left)
	bne color_tmp, green, loop
	Move_robot (left, colorful)
	j exit

move_down:
	Move_robot (down, colorful)
	li curr_st, 2
	Get_pix_color (color_tmp, position, down)
	bne color_tmp, green, loop
	Move_robot (down, colorful)
	j exit

move_up:
	Move_robot (up, colorful)
	li curr_st, 3
	Get_pix_color (color_tmp, position, up)
	bne color_tmp, green, loop
	Move_robot (up, colorful)

exit:
.end_macro

### FUNCAO PRINCIPAL ###

main:
	li white, 		0xFFFFFF	#Cor das bordas
	li green, 		0x00FF00	#Cor das extremidades do trajeto
	li blue, 		0x00BFFF 	#Cor da linha
	li pink, 		0xFF007F 	#Cor do robo
	li black, 		0x000000	#Cor padrao do display
	li colorful, 	0x000EBA	#Cor inicial para colorir o trajeto
	lui position, 	0x1004		#Endereco do primeiro pixel do display

	Draw_edge (right, 127)		#Desenha a borda superior
	Draw_edge (down, 63)		#Desenha a borda direita
	Draw_edge (left, 127)		#Desenha a borda inferior
	Draw_edge (up, 63)			#Desenha a borda esquerda
	
	Set_route_start				#Define uma posicao aleatoria para iniciar o desenho do trajeto
	Draw_route (100, 20)			#Desenha o trajeto
	
	Set_robot_pos				#Define uma posicao aleatoria para o robo iniciar a busca pelo trajeto
	Locate_route				#Busca a localizacao do trajeto
	Find_route_start			#Busca uma das extremidades do trajeto
	Follow_route				#Segue o trajeto ate a outra extremidade