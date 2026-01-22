; *************** DEFINICIÓN DE ETIQUETAS DE MEMORIA *************

; --- Direcciones Base de Memoria (RAM/ROM) ---
RAM_BASE			EQU			$0060				; Inicio del espacio de memoria RAM 
ROM_BASE			EQU			$DC00				; Dirección de inicio del programa en memoria ROM

; --- Vectores de Interrupción ---
VECTOR_TIMER_OVF	EQU			$FFF2				; Vector para Desbordamiento del Temporizador (MTIM)
VECTOR_TIMER_IC		EQU			$FFF6				; Vector para la Captura de Entrada (Input Capture), usado para el sensor
VECTOR_RESET		EQU			$FFFE				; Vector de Reinicio del Sistema

; --- Registros de Configuración ---
CONFIG_REG			EQU			$001F				; Registro de Configuración del Sistema del Microcontrolador

; --- Puertos de Entrada/Salida (I/O) ---
PUERTO_A			EQU			$0000				; Registro de Datos (Lectura/Escritura) del Puerto A
PUERTO_B			EQU			$0001				; Registro de Datos (Lectura/Escritura) del Puerto B
PUERTO_D			EQU			$0003				; Registro de Datos (Lectura/Escritura) del Puerto D

DDR_A				EQU			$0004				; Registro de Dirección de Datos (DDR) del Puerto A
DDR_B				EQU			$0005				; Registro de Dirección de Datos (DDR) del Puerto B
DDR_D				EQU			$0007				; Registro de Dirección de Datos (DDR) del Puerto D

; --- Módulo de Temporización (Timer/MTIM) ---
TSC_REG				EQU			$0020				; Registro de Control de Estado del Timer
TCNT_REG			EQU			$0021				; Registro Contador del Timer (Valor actual de tiempo)
TMOD_REG			EQU			$0023				; Registro de Modulación/Pre-escalador del Timer

; --- Módulo de Captura de Entrada (Canal 0) ---
TSC0_REG			EQU			$0025				; Registro de Control/Estado del Canal 0 de Captura
TCH0_REG			EQU			$0026				; Registro de Alto Byte para Captura de Entrada (Almacena el Periodo)


;---------------------------------------------------------------------------------------------------------------------------------------


; *************** ASIGNACIÓN DE ESPACIO EN RAM (VARIABLES DE PROGRAMA) *************

						ORG			RAM_BASE	; Inicia la asignación de variables a partir de la dirección base de RAM

; --- Variables de Medición de Periodo y Frecuencia ---
CONT_OVF				RMB			1			; Contador para el número de desbordamientos del Timer (extensión de rango)
FLAG_PULSO				RMB			1			; Bandera para indicar la recepción de un nuevo pulso del sensor
PULSOS_CAP				RMB			1			; Contador auxiliar para captura de pulsos (si se usa conteo en lugar de periodo)

; --- Almacenamiento del Resultado de RPM (Binario) ---
RPM_LOW					RMB			1			; Byte bajo del resultado de RPM (Unidades y Decenas)
RPM_HIGH				RMB			1			; Byte alto del resultado de RPM (Centenas y Miles)

; --- Variables de Control de Escala y Visualización ---
ESTADO_SW				RMB			1			; Almacena el estado actual de la llave selectora SW1 (x1 o x10)

; --- Almacenamiento del Resultado de RPM (BCD) ---
BCD_DIGITO1				RMB			1			; Almacena las Unidades y Decenas de RPM en formato BCD
BCD_DIGITO2				RMB			1			; Almacena las Centenas y Miles de RPM en formato BCD
BCD_DIGITO3				RMB			1			; Almacena la Decena de Mil (MSB) de RPM en formato BCD (hasta 99,999)

; --- Variables de Control del Multiplexado ---
DISPLAY_SEL				RMB			1			; Indica el display de 7 segmentos activo actualmente
CONT_MULT				RMB			1			; Contador auxiliar para la temporización del multiplexado

;---------------------------------------------------------------------------------------------------------------------------------------

; *************** COMIENZO DEL PROGRAMA EN ROM *************
						ORG			ROM_BASE			; Define el punto de inicio en la memoria de programa (ROM/Flash)
; --- TABLA DE CÓDIGOS PARA DISPLAYS DE 7 SEGMENTOS ---
; Los códigos son definidos para un display de ÁNODO COMÚN (o CÁTODO COMÚN, según el cableado)
; La secuencia de bits (hgfedcba) corresponde a los segmentos del display.
TABLA_7SEG				FCB			%10111111			; Código para el dígito 0
						FCB			%10000110			; Código para el dígito 1
						FCB			%11011011			; Código para el dígito 2
						FCB			%11001111			; Código para el dígito 3
						FCB			%11100110			; Código para el dígito 4
						FCB			%11101101			; Código para el dígito 5
						FCB			%11111101			; Código para el dígito 6
						FCB			%10000111			; Código para el dígito 7
						FCB			%11111111			; Código para el dígito 8
						FCB			%11101111			; Código para el dígito 9
						FCB			%10001000			; Código para el display 'A' (opcional)
						FCB			%10000011			; Código para el display 'b' (opcional)
						FCB			%11000011			; Código para el display 'C' (opcional)
						FCB			%10100001			; Código para el display 'd' (opcional)
						FCB			%10000110			; Código para el display 'E' (opcional)
						FCB			%10001110			; Código para el display 'F' (opcional)

; --- RUTINA DE INICIALIZACIÓN DEL SISTEMA ---
INICIO 					MOV			#$01, CONFIG_REG	; Deshabilita el Módulo de Protección de Código (COP/Watchdog)
						CLRA								; Inicializa el Acumulador A a cero
						CLRH								; Inicializa el Registro de Indice Alto (H) a cero
						CLRX								; Inicializa el Registro de Indice (X) a cero
						JSR			INIPUERTOS			; Salta a la Subrutina de Inicialización de Puertos de E/S
						JSR			INIVARIABLES		; Salta a la Subrutina de Inicialización de Variables en RAM
						JSR			INITIMER			; Salta a la Subrutina de Configuración del Módulo de Temporización
						CLI									; Habilita las interrupciones globales (permite la captura de pulsos)

; --- BUCLE PRINCIPAL DEL PROGRAMA (LOOP) ---
PRINCIPAL				JSR			CONTROL_LED			; Ejecuta la subrutina para el control del LED indicador de escala
						JSR			MULTIPLEXADO		; Llama a la subrutina de gestión de displays (Asumido, ya que es la principal tarea)
						JMP			PRINCIPAL			; Repite la ejecución del bucle

; -----------------------------------------------------------------------------------------------------------------------------
; *************** SUBRUTINA: INICIALIZACIÓN DE PUERTOS *************
INIPUERTOS
						; --- FASE 1: Configuración de la Dirección de Datos (DDRs) ---
						MOV			#$FF, DDR_B			; Puerto B (PB0-PB7): Configurado completamente como SALIDA (control de segmentos a-g)
						MOV			#$FF, DDR_A			; Puerto A (PA0-PA7): Configurado completamente como SALIDA (control de transistores/multiplexado)
						MOV			#%11101110, DDR_D	; Puerto D (DDR_D): Define la dirección de pines específicos
													; PD0 (Bit 0): Entrada (Sensor de Pulsos - IC)
													; PD4 (Bit 4): Entrada (Llave Selectora SW1 - X1/X10)
													; Otros pines: Salida (Control del LED DL1 y otros usos)

						; --- FASE 2: Configuración de Valores Iniciales (Puertos de Datos) ---
						MOV			#$00, PUERTO_A		; Puerto A: Inicializa a '0' (Transistores de Multiplexado Q1-Q4 en corte)
						MOV			#$FF, PUERTO_B		; Puerto B: Inicializa a '1' (Asume display de Ánodo Común: Todos los segmentos apagados)
						MOV			#%11101111, PUERTO_D	; Puerto D: Inicializa el estado de las salidas
													; Asume DL1 (conectado a PD5, por ejemplo) apagado y otros pines en estado seguro.
													; Nota: Los pines configurados como entrada (PD0, PD4) ignoran esta escritura.
						RTS								; Retorna del Subprograma
; -----------------------------------------------------------------------------------------------------------------------------

; *************** SUBRUTINA: INICIALIZACIÓN DE VARIABLES *************
INIVARIABLES
						; --- Limpieza de Variables de Medición ---
						CLR			CONT_OVF		; Inicializa el Contador de Desbordamientos del Timer a cero.
						CLR			PULSOS_CAP		; Inicializa el Contador de pulsos/frecuencia a cero.
						CLR			RPM_LOW			; Limpia el byte bajo del resultado de RPM.
						CLR			RPM_HIGH		; Limpia el byte alto del resultado de RPM.

						; --- Limpieza de Variables de Control ---
						CLR			ESTADO_SW		; Inicializa la variable de estado del Switch (x1/x10) a cero.
						CLR			FLAG_PULSO		; Limpia la bandera que indica la recepción de un nuevo pulso.

						; --- Limpieza de Variables de Visualización (BCD) ---
						CLR			BCD_DIGITO1		; Limpia el BCD de Unidades y Decenas.
						CLR			BCD_DIGITO2		; Limpia el BCD de Centenas y Miles.
						CLR			BCD_DIGITO3		; Limpia el BCD de Decena de Mil.

						; --- Limpieza de Variables de Multiplexado ---
						CLR			CONT_MULT		; Inicializa el Contador auxiliar de multiplexado a cero.
						CLR			DISPLAY_SEL		; Inicializa el Selector del Display activo a cero (e.g., Display 1).

						RTS							; Retorna del Subprograma

                        ; -----------------------------------------------------------------------------------------------------------------------------


; *************** SUBRUTINA: INICIALIZACIÓN DEL TEMPORIZADOR *************
; Objetivo: Configurar el Timer para la medición de Periodo (Input Capture).
; Ventana de tiempo DT: 5ms (DT = TMOD * Pre-escalador / f_BUS).

INITIMER
						; --- FASE 1: Configuración del Timer (MTIM) ---
						LDHX		#$00C0			; Carga el valor $00C0 (192 decimal) en el registro Indexado H:X.
						STHX		TMOD			; Escribe $00 en TMOD (Contador MTIM de 8 bits) y $C0 (192) en el registro de MTIM_MOD.
													; MTIM_MOD = 192. Esto establece el valor máximo de conteo.

						MOV			#%01000110, TSC		; Configura el Registro de Control y Estado del Timer (TSC)
													; Bit 6 = 1 (TIE): Habilita la interrupción por desbordamiento (Overflow).
													; Bits 2-0 (PS2-PS0 = 110): Selecciona un Pre-escalador de 64.
													; El timer cuenta y se reinicia automáticamente al llegar a 192.
													
						; Cálculo del Periodo de Desbordamiento (DT):


						; --- FASE 2: Configuración del Canal de Captura de Entrada (IC0) ---
						MOV			#%01000100, TSC0	; Configura el Registro de Control y Estado del Canal 0 (TSC0)
													; Bit 6 = 1 (TIE0): Habilita la Interrupción por Captura de Entrada (IC0).
													; Bits 3-2 (EDGE1-EDGE0 = 10): Configura la captura en el Flanco Ascendente (Rising Edge).
													; TSC0 es el registro asociado al pin de entrada del sensor (PD0).

						RTS							; Retorna del Subprograma
; -----------------------------------------------------------------------------------------------------------------------------

; *************** RUTINA DE SERVICIO DE INTERRUPCIÓN (ISR) - CAPTURA DE ENTRADA *************
; Esta rutina se ejecuta automáticamente al detectar un flanco ascendente en el sensor.
ISR_CAPTURA
						PSHA							; Guarda el contenido del Acumulador A en la Pila (contexto seguro)
						PSHH							; Guarda el contenido del Registro H en la Pila (contexto seguro)

						INC			PULSOS_CAP			; Incrementa el contador de pulsos recibidos (etiqueta PUL renombrada a PULSOS_CAP)

						BCLR		7, TSC0				; Limpia la bandera de interrupción de Captura (Bit 7: TCF0)
													; Es esencial limpiar la bandera para permitir futuras interrupciones.

						PULH							; Recupera el Registro H de la Pila
						PULA							; Recupera el Acumulador A de la Pila
						RTI								; Retorno de la Interrupción (Restaura el estado de la CPU)
; -----------------------------------------------------------------------------------------------------------------------------

; *************** RUTINA DE SERVICIO DE INTERRUPCIÓN (ISR) - DESBORDAMIENTO *************
; Esta rutina se ejecuta cada 5 ms para construir la ventana de muestreo.
ISR_OVERFLOW
						PSHA							; Guarda el Acumulador A en la Pila
						PSHH							; Guarda el Registro H en la Pila

						INC			CONT_OVF			; Incrementa el Contador de Overflows (cada incremento = 5 ms)

						LDA			CONT_OVF			; Carga el contador de Overflows en el Acumulador A
						CMP			#!200				; Compara A con 200 (200 overflows * 5 ms = 1000 ms = 1 segundo)
						BLO			OMITIR_CALCULO		; Si CONT_OVF < 200, salta y omite el muestreo y el cálculo

						; --- SECCIÓN DE MUESTREO (Ejecutada solo si se alcanza el 1.0 s) ---
						LDA			PULSOS_CAP			; Carga el número de pulsos capturados (PULSOS_CAP)
						STA			PULSOS_FINAL		; Almacena este valor en la variable de Frecuencia Base (PULSOS_FINAL/FREC)

						CLR			CONT_OVF			; Reinicia el Contador de Overflows a cero (inicia una nueva ventana de 1 s)
						CLR			PULSOS_CAP			; Reinicia el Contador de Pulsos a cero (prepara para la nueva ventana)

 
OMITIR_CALCULO
						; --- FASE DE CÁLCULO Y GESTIÓN DE ESCALA ---
						CLRA							; Limpia el Acumulador A (Preparación para la lectura del switch)

						LDA			ESTADO_SW			; Carga el estado de la llave selectora SW1
						CMP			#!1					; Compara el estado con el valor para Modo x1
						BNE			CALCULO_X10			; Si el switch no está en x1, salta a la lógica de escala x10

						; ... (Aquí continuaría la lógica para el Modo x1) ...
						
CALCULO_X10				; ... (Aquí continuaría la lógica para el Modo x10) ...

						PULH							; Recupera el Registro H de la Pila
						PULA							; Recupera el Acumulador A de la Pila
						RTI								; Retorno de la Interrupción
; -----------------------------------------------------------------------------------------------------------------------------
; *************** RUTINA DE CÁLCULO DE RPM Y ESCALA *************
; Las RPM se calculan multiplicando la frecuencia (PULSOS_FINAL/FREC) por un factor.
; FREC es el número de pulsos/segundo (RPS).

; --- MODO x1 (Medición normal: hasta 9,999 RPM) ---
; Esta sección se ejecuta si la llave SW1 está en el modo x1.
MODO_X1
						LDX			PULSOS_FINAL		; Carga el conteo de pulsos (RPS) en el Registro de Índice X.
						LDA			#!60				; Carga el factor de conversión (60 s/min) en el Acumulador A.
						MUL								; Multiplica X * A. Resultado de 16 bits (A * X) = RPM.
													; El byte bajo del resultado queda en el Acumulador A.
													; El byte alto del resultado queda en el Registro de Índice X.

						STA			RPM_LOW				; Almacena el byte bajo de RPM (Unidades y Decenas).
						STX			RPM_HIGH			; Almacena el byte alto de RPM (Centenas y Miles).

						BRA			CONTINUAR_PROCESO	; Salta al final de la lógica de escala.

; --- MODO x10 (Medición escalada: hasta 99,999 RPM) ---
; Esta sección se ejecuta si la llave SW1 está en el modo x10.
CALCULO_X10
						LDX			PULSOS_FINAL		; Carga el conteo de pulsos (RPS) en el Registro de Índice X.
						LDA			#!6					; Carga el factor de conversión modificado (60/10 = 6) en el Acumulador A.
						MUL								; Multiplica X * A. Resultado de 16 bits (A * X) = RPM / 10.
													; Esta multiplicación simula la división por 10 necesaria.

						STA			RPM_LOW				; Almacena el byte bajo del resultado escalado.
						STX			RPM_HIGH			; Almacena el byte alto del resultado escalado.

CONTINUAR_PROCESO
; Aquí continuaría el código para la conversión Binario a BCD y el control del LED/Multiplexado.
; -----------------------------------------------------------------------------------------------------------------------------




; *************** ALGORITMO DOUBLE DABBLE (BINARIO A BCD) *************
; Convierte el valor de RPM (Binario de 16 bits en RPM_HIGH:RPM_LOW) a BCD.
MULTIPLEX_CALCULO
						CLRA							; Inicializa Acumulador A a 0
						CLR			BCD_DIGITO1			; Limpia el BCD de Unidades/Decenas
						CLR			BCD_DIGITO2			; Limpia el BCD de Centenas/Miles
						CLR			BCD_DIGITO3			; Limpia el BCD de Decena de Mil
						MOV			#!16, CONT_MULT		; Inicializa el contador del bucle a 16 (para los 16 bits de RPM)

LAZO_DABBLE
						; --- PASO 1: AÑADIR CORRECCIÓN BCD (DABBLE) ---
						; Aplica corrección +3 si el nibble es >= 5, antes del corrimiento (SHIFT).
						; Corrección para Unidades (Nibble bajo de BCD1)
						LDA			BCD_DIGITO1			; Carga BCD1
						AND			#$0F				; Aísla el nibble bajo (Unidades)
						CMP			#$05				; Compara con 5
						BLO			DECENAS_BCD			; Si < 5, salta la corrección
						LDA			BCD_DIGITO1			; Vuelve a cargar BCD1
						ADD			#$03				; Suma 3
						STA			BCD_DIGITO1			; Almacena el resultado
						
DECENAS_BCD
						; Corrección para Decenas (Nibble alto de BCD1)
						LDA			BCD_DIGITO1
						AND			#$F0				; Aísla el nibble alto (Decenas)
						CMP			#$50				; Compara con 50 ($5 \times 16$)
						BLO			CENTENAS_BCD		; Si < 50, salta la corrección
						LDA			BCD_DIGITO1
						ADD			#$30				; Suma 30 ($3 \times 16$)
						STA			BCD_DIGITO1
						
CENTENAS_BCD
						; Corrección para Centenas (Nibble bajo de BCD2)
						LDA			BCD_DIGITO2
						AND			#$0F
						CMP			#$05
						BLO			MILES_BCD
						LDA			BCD_DIGITO2
						ADD			#$03
						STA			BCD_DIGITO2
						
MILES_BCD
						; Corrección para Miles (Nibble alto de BCD2)
						LDA			BCD_DIGITO2
						AND			#$F0
						CMP			#$50
						BLO			SHIFT_DABBLE		; Continúa al corrimiento si no requiere corrección
						LDA			BCD_DIGITO2
						ADD			#$30
						STA			BCD_DIGITO2
						
						; Nota: La corrección para BCD3 (Decena de Mil) se asume omitida para ahorrar código/tiempo.

						; --- PASO 2: CORRIMIENTO A LA IZQUIERDA (SHIFT) ---
SHIFT_DABBLE
						ASL			RPM_LOW				; Desplaza a la izquierda el byte bajo (LSB) de RPM. El bit 7 va al Carry.
						ROL			RPM_HIGH			; Rota a la izquierda el byte alto (MSB) de RPM. El Carry va al Bit 0.

						ROL			BCD_DIGITO1			; Rota el BCD de Unidades/Decenas. El Carry (el bit más significativo de RPM) entra por el Bit 0.
						ROL			BCD_DIGITO2			; Rota el BCD de Centenas/Miles.
						ROL			BCD_DIGITO3			; Rota el BCD de Decena de Mil.

						DBNZ		CONT_MULT, LAZO_DABBLE	; Decrementa el contador y repite el lazo si no es cero.
; El resultado BCD (RPM en decimal) está ahora listo en BCD1, BCD2 y BCD3.

---

; *************** RUTINA DE MULTIPLEXADO Y VISUALIZACIÓN *************
; Esta rutina enciende un display a la vez, usando el valor BCD calculado.
MULTIPLEX_DISPLAY
						CLRH							; Limpia H
						CLRX							; Limpia X
						
						; 1. APAGADO DE TODOS LOS DISPLAYS (Pulso bajo para transistores en corte, asumiendo PNP)
						BCLR		0, PUERTO_A			; Apaga Display 1 (LSB)
						BCLR		1, PUERTO_A			; Apaga Display 2
						BCLR		2, PUERTO_A			; Apaga Display 3
						BCLR		3, PUERTO_A			; Apaga Display 4 (MSB)
						
						; 2. SELECCIÓN DEL DÍGITO A MOSTRAR
						LDA			DISPLAY_SEL			; Carga el índice del display actual (0, 1, 2 o 3)
						CMP			#!0
						BEQ			Q1_UNIDADES			; Salta a Q1 si DISPLAY_SEL = 0 (Unidades)
						CMP			#!1
						BEQ			Q2_DECENAS			; Salta a Q2 si DISPLAY_SEL = 1 (Decenas)
						CMP			#!2
						BEQ			Q3_CENTENAS			; Salta a Q3 si DISPLAY_SEL = 2 (Centenas)
						CMP			#!3
						BEQ			Q4_MILES			; Salta a Q4 si DISPLAY_SEL = 3 (Miles)

; --- LÓGICA DE DÍGITO 1: UNIDADES (Nibble bajo de BCD1) ---
Q1_UNIDADES
						LDA			BCD_DIGITO1			
						AND			#$0F				; Aísla el nibble bajo (0-9)
						TAX								; Transfiere el dígito BCD a X (índice de la tabla)
						LDA			TABLA_7SEG, X		; Busca el código de 7 segmentos en la tabla
						STA			PUERTO_B			; Envía el código de segmentos al Puerto B
						BSET		0, PUERTO_A			; Enciende el Transistor Q1 (Display de Unidades)
						JMP			ACTUALIZAR_SEL		; Salta a la actualización del selector

; --- LÓGICA DE DÍGITO 2: DECENAS (Nibble alto de BCD1) ---
Q2_DECENAS
						LDA			BCD_DIGITO1
						AND			#$F0				; Aísla el nibble alto ($00, $10...$90)
						NSA								; Swaps nibbles ($X0$ se convierte en $0X$)
						TAX
						LDA			TABLA_7SEG, X
						STA			PUERTO_B
						BSET		1, PUERTO_A			; Enciende el Transistor Q2 (Display de Decenas)
						JMP			ACTUALIZAR_SEL

; --- LÓGICA DE DÍGITO 3: CENTENAS (Nibble bajo de BCD2) ---
Q3_CENTENAS
						LDA			BCD_DIGITO2
						AND			#$0F				; Aísla el nibble bajo (Centenas)
						TAX
						LDA			TABLA_7SEG, X
						STA			PUERTO_B
						BSET		2, PUERTO_A			; Enciende el Transistor Q3 (Display de Centenas)
						JMP			ACTUALIZAR_SEL

; --- LÓGICA DE DÍGITO 4: MILES (Nibble alto de BCD2) ---
Q4_MILES
						LDA			BCD_DIGITO2
						AND			#$F0				; Aísla el nibble alto (Miles)
						NSA								; Swaps nibbles
						TAX
						LDA			TABLA_7SEG, X
						STA			PUERTO_B
						BSET		3, PUERTO_A			; Enciende el Transistor Q4 (Display de Miles)
						JMP			ACTUALIZAR_SEL

; --- 3. ACTUALIZACIÓN DEL SELECTOR Y FIN DE ISR ---
ACTUALIZAR_SEL
						LDA			DISPLAY_SEL			; Carga el índice actual
						INCA							; Incrementa el índice para el siguiente ciclo
						CMP			#!4					; Compara con 4
						BNE			FINAL_ISR			; Si es < 4, salta
						CLRA							; Si es 4, reinicia el selector a 0 (Q1)

FINAL_ISR
						STA			DISPLAY_SEL			; Actualiza la variable de selección de display

						BCLR		7, TSC				; Limpia la bandera de interrupción TOF (Timer Overflow Flag)
						PULH							; Recupera H
						PULA							; Recupera A
						RTI								; Retorno de la Interrupción (Restaura el estado de la CPU)

;------------------------------------------------------------------------------------------------------------------------------
; *************** SUBRUTINA: CONTROL DEL LED E INTERRUPTOR DE ESCALA *************
; Lee el estado del switch de escala (PD0) y controla el LED (PD1).
SUBRUTINA_LED
						; 1. Evalúa el estado del switch (Asumido PD0 conectado a GND en modo x10, o a VCC en modo x1)
						BRCLR		0, PUERTO_D, MODO_X10	; Si el bit 0 de PUERTO_D es '0' (modo x10), salta a MODO_X10

						; --- LÓGICA MODO X1 (PD0 = 1) ---
						LDA			#!1						; El switch está en 1 (Modo x1)
						STA			ESTADO_SW				; Guarda 1 en la variable ESTADO_SW
						BSET		1, PUERTO_D				; Pone un 1 en PD1 (Apaga el LED DL1)
						BRA			FIN_LED					; Salta al final de la rutina

MODO_X10
						; --- LÓGICA MODO X10 (PD0 = 0) ---
						LDA			#!0						; El switch está en 0 (Modo x10)
						STA			ESTADO_SW				; Guarda 0 en la variable ESTADO_SW
						BCLR		1, PUERTO_D				; Pone un 0 en PD1 (Enciende el LED DL1)

FIN_LED
						RTS										; Retorna de la subrutina
; -----------------------------------------------------------------------------------------------------------------------------
; *************** DEFINICIÓN DEL VECTOR DE INTERRUPCIÓN POR OVERFLOW *************
						ORG			TIMER_OVF			; Define la dirección del Vector de Overflow del Timer (Ej: $FFF2)
						DW			ISR_OVERFLOW		; Escribe la dirección de la rutina de servicio (ISR_OVERFLOW) en el vector.
													; Cuando el Timer desborde, el CPU saltará a esta dirección.

; *************** DEFINICIÓN DEL VECTOR DE INTERRUPCIÓN POR INPUT CAPTURE *************
						ORG			TIMER_IC			; Define la dirección del Vector de Input Capture (Ej: $FFF4)
						DW			ISR_CAPTURA			; Escribe la dirección de la rutina de servicio (ISR_CAPTURA) en el vector.
													; Cuando el sensor envíe un pulso, el CPU saltará a esta dirección.
													
; *************** DEFINICIÓN DEL VECTOR DE RESET ***********************************
						ORG			RESET				; Define la dirección del Vector de Reset (Ej: $FFFE)
						DW			INICIO				; Escribe la dirección de la rutina de inicio (INICIO) en el vector.
													; Tras el encendido o un reset, el CPU comenzará la ejecución aquí.

; *************************************************************************************************
; *************** FIN DEL CÓDIGO DEL PROGRAMA *************
