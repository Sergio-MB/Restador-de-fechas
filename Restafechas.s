.data 
	cadena: 	.space 15
	err_msg_1: 	.asciiz "Error. La cadena introducida es demasiado larga.\n"
	err_msg_2:	.asciiz "\nError. Carácteres inválidos.\n"

.text
beginning:
	la	$a0,	cadena
	addi	$a1,	$zero,	15
	li	$v0,	8		# Pedimos una cadena
	syscall
	
	la	$a0,	cadena
	jal	elimina_retorno
	
	la	$a0,	cadena		
	jal	convertir		# Convertimos la cadena a registro.
	
	bne	$v1,	$zero,	error	# Si no bifurca no hay ningún error indicado por la función.
	  
	srl	$a0,	$v0,	2	# Hallamos la division por 4
	la	$a1,	cadena		# Pasamos la dirección de la cadena.
	
	jal	convertir2			# Convertimos.
	
	la	$a0,	cadena
	li	$v0,	4	
	syscall
	j	end			# Volvemos a ejecutar el programa.
error:
	bne	$v1,	1,	error_2	# Si no bifurca, es el error 1.
	la	$a0,	err_msg_1	# Imprimimos el mensaje de error 1.
	li	$v0,	4		
	syscall 
	j	beginning		# Volvemos a ejecutar el programa.
error_2:
	la	$a0,	err_msg_2	# Imprimimos el mensaje de error 2.
	li	$v0,	4
	syscall
	j	beginning

end:
	li	$v0,	10
	syscall	

#
# Función convertir: convierte una cadena en hexadecimal, detectando
# cadenas inválidas. Devuelve el error (si existe) por $v1, y por 
# $v0 el valor de la cadena leída. Por $a0 pasamos la dirección de 
# la cadena a convertir.
# 
convertir:
	addi	$sp,	$sp,	-4	# Hacemos espacio para guardar datos en la pila.
	sw	$ra,	0($sp)		# Guardamos el registro de retorno en la pila.
	
	jal	check			# Comprobamos si hay algún error.
	bne	$v1,	$zero,	endconvertir	# Si tenemos un error no leemos nada.
	
	move	$t0,	$zero			# Reninicialización de variables (contador).
	move	$v0,	$zero			# Reninicialización de variables (registro).
loop_convertir:
	lbu	$t1,	0($a0)			# Cargamos un carácter en $t1.
	beq	$t1,	0,	endconvertir	# Comprobamos si hamos acabado de leer.
	addi	$a0,	$a0,	1		# Apuntamos al siguiente carácter.
	sll	$v0,	$v0,	4		# Desplazamos el registro hacia la izquierda.
	bge	$t1,	65,	char		# Comprobamos si es una minúscula (recordar que es un carácter válido pues está validado).
	addi	$t1,	$t1,	-48		# Traducimos de ASCII a número del 0x00 al 0x09
	j	next
char:
	bge	$t1,	97,	upper	# Si no bifurca son minúsculas
	addi	$t1,	$t1,	-55	# Minúsculas. Traducimos de ASCII a hexadecimal
	j	next
upper:	
	addi	$t1,	$t1,	-87	# Mayúsculas. Traducimos de ASCII a hexadecimal
next:
	add	$v0,	$t1,	$v0	# Añadimos los 4 nuevos bits al registro
	addi	$t0,	$t0,	1	# Aumentamos el contador.
	bne	$t0,	8,	loop_convertir	# Vamos al principiuo del bucle.
endconvertir:
	lw	$ra,	0($sp)		# Restauramos los valores de la pila, pues en el medio llamamos a funciones externas.
	addi	$sp,	$sp,	4
	jr	$ra

#
# Función check. No modifica el registro $a0.
#	- $a0 -> dirección de la cadena.
#	- $v0 -> no usado. Usamos $v1 por conveniencia con la función convertir.
#	- $v1 -> código de error. Si 0, correcto.
check:	
	move	$t0,	$a0			# No usaremos el registro $a0 en nuestra función, para no tener que guardarlo 
	addi	$t2,	$zero,	1		# Reiniciamos $t2.
check_loop:
	lb	$t1,	0($t0)			# Cargamos el primer byte de la cadena.
	beq	$t1,	$zero,	ok_check	# Comprobamos si hemos acabado (\0).
	bge	$t2,	9,	too_long	# Si hemos leído 9 caracteres y el último no era el fin de fichero.
	# Entre 48 y 57 -> un número
	blt	$t1,	48,	invalid_char	# Por debajo de 48 no puede ser un carácter válido.
	ble	$t1,	57,	valid_char	# Luego pertenece a {48, ..., 57} (0 - 9).
	# Entre 65 y 70 -> A-F
	blt	$t1,	65,	invalid_char	# Luego pertenece a {58, ..., 64} INVÁLIDO.
	ble	$t1,	70,	valid_char	# Luego pertenece a {48, ..., 57} (A - Z) VÁLIDO.
	# Entre 97 y 102 -> a-f
	blt	$t1,	97,	invalid_char	# Luego pertenece a {71, ..., 96} INVÁLIDO.
	ble	$t1,	102,	valid_char	# Luego pertenece a {97, ..., 102} (a - z) VÁLIDO.
	# No es ninguno de los anteriores.
	j	invalid_char	
valid_char:
	addi	$t0,	$t0,	1	# Aumentamos el puntero
	addi	$t2,	$t2,	1	# Aumentamos el contador
	j	check_loop	
	
invalid_char:
	# Carácter inválido, luego devolvemos $v1 = 1.
	addi	$v1,	$zero,	2
	jr	$ra
too_long:
	# Cadena demasiado larga, luego devolvemos $v1 = 2.
	addi	$v1,	$zero,	1
	jr	$ra
ok_check:
	# Todo correcto, luego devolvemos $v1 = 0 y $v0 = número en binario válido.
	move	$v1,	$zero
	jr	$ra



#
# Función convertir2: convierte el número de 32 bits almacenado en
# el registro $a0 y almacena en una cadena $a1 su conversión a 
# hexadecimal codificado en ASCII.
#
convertir2:
	addi	$t0,	$zero,	8	# Contador de nuestro bucle para recorrer de 4 bits en 4 bits el registro.
	lui	$t1,	0xF000		# Máscara de las 4 posiciones más significativas del registro.
loop_convertir2:	
	addi	$t0,	$t0,	-1	# Restamos 1 al contador de programa
	## Lectura de 4 bytes
	and	$t2,	$a0,	$t1	# Aplicamos la máscara.
	srl	$t2,	$t2,	28	# Trasladamos 28 bytes a la derecha LÓGICAMENTE para poder tratar los bits anteriores.
	sll	$a0,	$a0,	4	# Desplazamos 4 posiciones a la izquierda para leer los 4 siguientes bits en la siguiente instrucción.
	
	bgt	$t2,	9,	letra	# Si el valor de $t2 > 9 implica que estamos tratando con una letra.
	addi	$t2,	$t2,	48	# Entonces estamos tratando con un número. Añadimos el código ASCII del 0.
	j	guarda_letra		# Saltamos a guardar la letra.
letra:	
	addi	$t2,	$t2,	55	# Si tenemos una letra, añadimos el código ASCII de la A.
guarda_letra:
	sb	$t2,	0($a1)		# Guardamos el carácter ASCII en la posición de memoria adecuada.
	addi	$a1,	$a1,	1	# Apuntamos al siguiente byte.
	bne	$t0,	$zero,	loop_convertir2	# Si hemos llegado a 0, hemos terminado de convertir el número.
	jr	$ra			# Fin de la función.

#
# Se le pasa una cadena y sustituye el retorno de carro por un cero.
#
elimina_retorno:
	lbu	$t1,	0($a0)		# Cargamos un byte
	beq	$t1,	10,	elimina	# Si es un salto de línea lo eliminamos.
	addi	$a0,	$a0,	1	# Apuntamos al siguiente byte, pues todavía no hemos encontrado el retorno de carro.
	j	elimina_retorno		# Volvemos a ejecutar el bucle.
elimina:	
	sb	$zero,	0($a0)		# Guardamos el cero.
	jr	$ra			# Fin de la función.
