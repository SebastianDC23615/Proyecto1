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
		LPM R25, Z					; Cargar pointer a registro
		OUT PORTD, R25				; Mostrar valor de pointer a PORTD
	
		; =========================================
		; Configuraciones Extra
		; =========================================

		LDI R17, 0x00				; Inicializar counter y mostrar en salida
		OUT PORTC, R17

		LDI R20, 0x00				; Inicializar contador de contador
		LDI R21, 0x00				; Inicializar contador unidades minutos
		LDI R22, 0x00				; Inicializar contador decenas minutos
		LDI R23, 0x00				; Inicializar contador unidades horas
		LDI R24, 0x00				; Inicializar contador decenas horas

		LDI R18, 0x00				; Inicializar alternador

		SEI							; Habilitar interrupciones



	; =============================================
	; Bucle Principal
	; =============================================

	MAIN:
		
		CPI R20, 50						; Verificar si ya se completaron 50 vueltas (1 segundo)
		BREQ RST_CCNT					; Si ha completado, resetear contador de contador, si no continuar
		RJMP alternador
		; =========================================
		; Condicionales para reloj 24 hrs
		; =========================================

		RST_CCNT:
			LDI R20, 0x00				; Resetear contador de contador

			CPI R21, 0x09				; Verificar si unidades ya es 9
			BREQ RST_CNT_U_S			; Si ya es 9, resetear counter, sino saltar 

			INC R21						; Incrementar contador unidades segundos

			RJMP MAIN

			RST_CNT_U_S:
				LDI R21, 0x00			; Reiniciar contador unidades segundos

				CPI R22, 0x05			; Verificar decenas si ya es 5
				BREQ RST_CNT_D_S		; Si ya es 6, resetear counter, sino saltar

				INC R22					; Aumentar contador decenas segundos

				RJMP MAIN

				RST_CNT_D_S:
					LDI R21, 0x00			; Reiniciar contador unidades segundos
					LDI R22, 0x00			; Reiniciar contador decenas segundos 

					CPI R23, 0x09			; Verificar si unidades minutos ya es 9
					BREQ RST_CNT_U_M		; Si ya es 9, resetear counter, sino saltar

					INC R23					; Aumentar unidades minutos

					RJMP MAIN

					RST_CNT_U_M:
						LDI R21, 0x00			; Reiniciar contador unidades segundos
						LDI R22, 0x00			; Reiniciar contador decenas segundos
						LDI R23, 0x00			; Reiniciar contador unidades minutos

						CPI R24, 0x02			; Verificar si decenas minutos ya es 2
						BREQ RST_CNT_D_M		; Si ya es 2, resetear counter, sino saltar

						INC R24					; Aumentar decenas minutos

						RJMP MAIN

						RST_CNT_D_M:
							LDI R21, 0x00			; Reiniciar contador unidades segundos
							LDI R22, 0x00			; Reiniciar contador decenas segundos
							LDI R23, 0x00			; Reiniciar contador unidades minutos
							LDI R24, 0x00			; Reiniciar contador decenas minutos

							RJMP MAIN

		; ==================================
		; Alternadores de display
		; ==================================
alternador:
		CPI R18, 0						; si es 0 alternar a 1 y mostrar display 0
		BREQ SHW_DISP_0
		RJMP nextdisp1
		SHW_DISP_0:
			LDI R18, 0x01				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			CBI PORTB, 3				; Deshabilitar display 3
			CBI PORTB, 2				; Deshabilitar display 2
			CBI PORTB, 1				; Deshabilitar display 1
			SBI PORTB, 0				; Habilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R25, Z					; Cargar pointer en registro
			OUT PORTD, R25				; Mostrar registro en puerto D

			RJMP MAIN
nextdisp1:
		CPI R18, 1						; si es 1 alternar a 2 y mostrar display 1
		BREQ SHW_DISP_1
		RJMP nextdisp2
		SHW_DISP_1:
			LDI R18, 0x02				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			CBI PORTB, 3				; Deshabilitar display 3
			CBI PORTB, 2				; Deshabilitar display 2
			SBI PORTB, 1				; Habilitar display 1
			CBI PORTB, 0				; Deshabilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			ADC ZL, R22					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R25, Z					; Cargar pointer en registro
			OUT PORTD, R25				; Mostrar registro en puerto D

			RJMP MAIN
nextdisp2:
		CPI R18, 2						; si es 2 alternar a 3 y mostrar display 2
		BREQ SHW_DISP_2
		RJMP nextdisp3
		SHW_DISP_2:
			LDI R18, 0x03				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			CBI PORTB, 3				; Deshabilitar display 3
			SBI PORTB, 2				; Habilitar display 2
			CBI PORTB, 1				; Deshabilitar display 1
			CBI PORTB, 0				; Deshabilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			ADC ZL, R23					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R25, Z					; Cargar pointer en registro
			OUT PORTD, R25				; Mostrar registro en puerto D

			RJMP MAIN
nextdisp3:
		CPI R18, 3						; si es 3 alternar a 0 y mostrar display 3
		BREQ SHW_DISP_3
		RJMP MAIN

		SHW_DISP_3:
			LDI R18, 0x00				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			SBI PORTB, 3				; Habilitar display 3
			CBI PORTB, 2				; Deshabilitar display 2
			CBI PORTB, 1				; Deshabilitar display 1
			CBI PORTB, 0				; Deshabilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			ADC ZL, R24					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R25, Z					; Cargar pointer en registro
			OUT PORTD, R25				; Mostrar registro en puerto D

			RJMP MAIN

		RJMP MAIN

; =============================================
; Contador de overflow para 7 segmentos
; =============================================

CNT_OVF:
	SBI TIFR0, TOV0				; Limpiar bandera de "overflow"
    LDI R16, 178	
    OUT TCNT0, R16				; Volver a cargar valor inicial en TCNT0

	INC R20
	RETI