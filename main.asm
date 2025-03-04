; ============================================
; Universidad del Valle de Guatemala
; IE2024: Programación de microcontroladores
; Proyecto 1
;
; Created: 24/02/2025
; Author : Sebastián Duarte Calderón
; Hardware: ATmega328P
; Descripción: Proyecto 1, Reloj alarma con multiples modos
; ============================================

.include "m328Pdef.inc"

.cseg
.org 0x0000
JMP START

.org 0x0020		; Vector de interrupción para overflow
JMP CNT_OVF

START:
	; =============================================
	; Configuración de la pila
	; =============================================
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16

	; =============================================
	; Configuración del MCU
	; =============================================

	SETUP:
		CLI							; Deshabilitar interrupciones antes de configurar

		LDI R16, 0x00				; Deshabilitar comunicacion serial
		STS UCSR0B, R16

		; =========================================
		; Puertos
		; =========================================

		LDI R16, 0xFF				; 
		OUT DDRD, R16				; Puerto D como salida de 7 segmentos
		LDI R16, 0x00				; 
		OUT PORTD, R16				; Inicializar salida

		LDI R16, 0x0F				; 
		OUT DDRB, R16				; PB0, PB1, PB2, PB3 selectores respectivos
		LDI R16, 0x00				;
		OUT PORTB, R16				; Setear como salidas

		LDI R16, 0x07				;
		OUT DDRC, R16				; Puerto C como entrada
		LDI R16, 0x07				;
		OUT PORTC, R16				; Habilitar pullups en PC0, PC1 y PC2

		; =========================================
		; Interrupciones
		; =========================================

		LDI R16, (1<<PCIE1)					; Habilitar interrupciones en PORTC
		STS PCICR, R16						;

		LDI R16, (1<<PCINT8) | (1<<PCINT9) | (1<<PCINT10)	; Habilitar interrupciones en PB0 y PB1
		STS PCMSK0, R16										;

		LDI R16, (1 << TOIE0)				; Habilitar interrupciones por overflow de timer
		STS TIMSK0, R16	

		; =========================================
		; Timer
		; =========================================

		LDI R16, (1 << CLKPCE)		; Habilitar factor division
		STS CLKPR, R16
		LDI R16, 0b00000010
		STS CLKPR, R16				; Configurar factor division a 4, F_cpu = 4MHz

		LDI R16, (1<<CS00) 	| (0<<CS01)	| (1<<CS02)		; prescaler 1024
		OUT TCCR0B, R16									; Configurar preescalador del TIMER 0 a 1024
		LDI R16, 178
		OUT TCNT0, R16									; Cargar valor inicial en TCNT0

		; =========================================
		; Libreria Traductor Numeros
		; =========================================

		LDI ZL, LOW(TRADUCTOR << 1)
		LDI ZH, HIGH(TRADUCTOR << 1)
	
		TRADUCTOR: .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x58, 0x5E, 0x79, 0x71
		LPM R23, Z					; Cargar pointer a registro
		OUT PORTD, R23				; Mostrar valor de pointer a PORTD
	
		; =========================================
		; Configuraciones Extra
		; =========================================

		LDI R17, 0x00				; Inicializar counter y mostrar en salida
		OUT PORTC, R17

		LDI R20, 0x00				; Inicializar contador 7 segmentos unidades
		LDI R21, 0x00				; Inicializar contador de contador
		LDI R22, 0x00				; Inicializar contador 7 segmentos decenas
		LDI R18, 0x00				; Inicializar alternador

		SEI							; Habilitar interrupciones



	; =============================================
	; Bucle Modo Hora
	; =============================================

	LOOP_TIME:
		
		CPI R21, 50						; Verificar si ya se completaron 50 vueltas (1 segundo)
		BREQ RST_CCNT					; Si ha completado, resetear contador de contador, si no continuar

		CPI R18, 0						; si es 0 alternar a 1 y mostrar display 0
		BREQ SHW_DISP_0

		CPI R18, 1						; si es 1 alternar a 2 y mostrar display 1
		BREQ SHW_DISP_1

		CPI R18, 2						; si es 2 alternar a 3 y mostrar display 2
		BREQ SHW_DISP_2

		CPI R18, 3						; si es 3 alternar a 0 y mostrar display 3
		BREQ SHW_DISP_3

		RJMP LOOP_TIME

		RST_CCNT:
			LDI R20, 0x00				; Resetear contador de contador

			CPI R21, 0x09				; Verificar si unidades ya es 9
			BREQ RST_CNT_U_S			; Si ya es 9, resetear counter, sino saltar 

			INC R21						; Incrementar contador unidades egundos

			RJMP MAIN

			RST_CNT_U_S:
				LDI R21, 0x00			; Reiniciar contador unidades segundos

				CPI R22, 0x05			; Verificar decenas si ya es 6
				BREQ RST_CNT_D_S		; Si ya es 6, resetear counter, sino saltar

				INC R22					; Aumentar contador decenas segundos

				RJMP MAIN

				RST_CNT_D:
					LDI R21, 0x00			; Reiniciar contador unidades segundos
					LDI R22, 0x00			; Reiniciar contador decenas segundos 

					CPI R23, ;aquimequede
					RJMP MAIN

	; =============================================
	; Bucle Modo Fecha
	; =============================================

	LOOP_DATE:
		RJMP LOOP_DATE


; =============================================
; Contador de overflow para 7 segmentos
; =============================================

CNT_OVF:
	SBI TIFR0, TOV0				; Limpiar bandera de "overflow"
    LDI R16, 178	
    OUT TCNT0, R16				; Volver a cargar valor inicial en TCNT0

	INC R20
	RETI