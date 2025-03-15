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

.dseg
.org SRAM_START			; Utilizar RAM para guardar valores
SEGS: .byte 1			; Asignar a RAM segundos
UMIN: .byte 1			; Asignar a RAM unidades de minuto
DMIN: .byte 1			; Asignar a RAM decenas de minuto
UHOR: .byte 1			; Asignar a RAM unidades de hora
DHOR: .byte 1			; Asignar a RAM decenas de hora

UMON: .byte 1			; Asignar a RAM unidades de mes
DMON: .byte 1			; Asignar a RAM decenas de mes
UDAT: .byte 1			; Asignar a RAM unidades de dia
DDAT: .byte 1			; Asignar a RAM decenas de dia

S_UMIN: .byte 1			; Asignar a RAM config de hora
S_DMIN: .byte 1			; Asignar a RAM config de hora
S_UHOR: .byte 1			; Asignar a RAM config de hora
S_DHOR: .byte 1			; Asignar a RAM config de hora

UMALARM: .byte 1		; Asignar a RAM unidades de minuto para alarma
DMALARM: .byte 1		; Asignar a RAM decenas de minuto para alarma
UHALARM: .byte 1		; Asignar a RAM unidades de hora para alarma
DHALARM: .byte 1		; Asignar a RAM decenas de hora para alarma

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

		LDI R16, (1<<PCINT8) | (1<<PCINT9) | (1<<PCINT10) | (1<<PCINT11)
		STS PCMSK0, R16						; Habilitar interrupciones en PC0, PC1, PC2 y PC3

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
		LPM R17, Z					; Cargar pointer a registro
		OUT PORTD, R17				; Mostrar valor de pointer a PORTD
	
		; =========================================
		; Configuraciones Extra
		; =========================================

		LDI R18, 0x00				; Inicializar alternador
		LDI R19, 0x00				; Estado a mostrar, 
									;		0: modo hora
									;		1: modo fecha
									;		2: modo config hora
									;		3: modo config fecha
									;		4: modo config alarma

		LDI R20, 0x00				; Inicializar contador de contador
		LDI R21, 0x00				; Común de RAM
		LDI R25, 0x01				; Inicializar alternador de punto

		STS SEGS, R21				; Cargar inicial a segundos
		STS UMIN, R21				; Cargar inicial a unidades minutos				
		STS DMIN, R21				; Cargar inicial a decenas minutos
		STS UHOR, R21				; Cargar inicial a unidades horas
		STS DHOR, R21				; Cargar inicial a decenas horas

		LDI R21, 0x01
		STS UMON, R21				; Cargar inicial a unidades mes	
		LDI R21, 0x00			
		STS DMON, R21				; Cargar inicial a decenas mes
		LDI R21, 0x01
		STS UDAT, R21				; Cargar inicial a unidades dia
		LDI R21, 0x00
		STS DDAT, R21				; Cargar inicial a decenas dia

		STS S_UMIN, R21				; Valor a guardar a unidades minutos config hora
		STS S_DMIN, R21				; Valor a guardar a decenas minutos config hora
		STS S_UHOR, R21				; Valor a guardar a unidades horas config hora
		STS S_DHOR, R21				; Valor a guardar a decenas horas config hora

		SEI							; Habilitar interrupciones

	; =============================================
	; Bucle Principal
	; =============================================

	MAIN:
		
		CPI R20, 50						; Verificar si ya se completaron 50 vueltas (1 segundo)
		BREQ RST_CCNT					; Si ha completado, resetear contador de contador, si no continuar
		CPI R20, 0						; Condicionales para el punto
		BREQ DT_N
		CPI R20, 25
		BREQ DT_F

		ver_mode:
		CPI R19, 0
		BREQ alt_hora
		CPI R19, 1
		BREQ alt_fecha
		CPI R19, 2
		BREQ alt_hora_config
		CPI R19, 3
		BREQ alt_fecha_config
		CPI R19, 4
		BREQ alt_alarm
		RJMP MAIN

		alt_hora:
			RJMP alternador_hora
		alt_fecha:
			RJMP alternador_fecha
		alt_hora_config:
			RJMP MAIN
		alt_fecha_config:
			RJMP MAIN
		alt_alarm:
			RJMP MAIN


		DT_N:
			LDI R25, 1
			RJMP ver_mode
		DT_F:
			LDI R25, 0
			RJMP ver_mode

		; =========================================
		; Condicionales para reloj 24 hrs
		; =========================================

		RST_CCNT:
			LDI R20, 0x00				; Reiniciar contador de contador
			;RJMP RST_CNT_M				; Activar para correr fecha mas rapido
			LDS R21, SEGS
			CPI R21, 59					; Verificar si segundos ya es 59
			BREQ RST_CNT_S				; Si ya es 59, resetear counter, sino saltar 

			INC R21						; Incrementar contador segundos
			STS SEGS, R21
			
			RJMP MAIN

			RST_CNT_S:
				
				LDI R21, 0x00
				STS SEGS, R21			; Reiniciar unidades de segundos

				LDS R21, UMIN			; Cargar de RAM
				CPI R21, 0x09			; Verificar si unidades minutos ya es 9
				BREQ RST_CNT_U_S		; Si ya es 9, resetear, sino saltar

				INC R21					; Incrementar unidades minutos
				STS UMIN, R21			; Cargar a RAM

				RJMP MAIN

				RST_CNT_U_S:

					LDI R21, 0x00			
					STS SEGS, R21			; Reiniciar contador segundos
					STS UMIN, R21			; Reiniciar contador unidades minutos

					LDS R21, DMIN			; Cargar de RAM
					CPI R21, 0x05			; Verificar decenas si ya es 5
					BREQ RST_CNT_D_S		; Si ya es 6, resetear counter, sino saltar

					INC R21					; Aumentar contador decenas segundos
					STS DMIN, R21			; Cargar a RAM

					RJMP MAIN

					RST_CNT_D_S:
						LDI R21, 0x00		
						STS SEGS, R21			; Reiniciar contador segundos
						STS UMIN, R21			; Reiniciar contador unidades minutos
						STS DMIN, R21			; Reiniciar contador decenas minutos

						LDS R21, UHOR			; Cargar de RAM
						CPI R21, 0x03			; Verificar si unidades minutos ya es 3
						BREQ RST_CNT_D_M		; Si ya es 3, verificar si decenas ya es 2, sino saltar
						continue1:
						LDS R21, UHOR
						CPI R21, 0x09			; Verificar si unidades minutos ya es 9
						BREQ RST_CNT_U_M		; Si ya es 9, resetear counter, sino saltar

						INC R21					; Aumentar unidades minutos
						STS UHOR, R21			; Cargar a RAM

						RJMP MAIN

						RST_CNT_U_M:
							LDI R21, 0x00
							STS SEGS, R21			; Reiniciar contador segundos
							STS UMIN, R21			; Reiniciar contador unidades minutos
							STS DMIN, R21			; Reiniciar contador decenas minutos
							STS UHOR, R21			; Reiniciar contador unidades horas				

							LDS R21, DHOR			; Cargar de RAM
							INC R21					; Incrementar contador decenas horas
							STS DHOR, R21			; Cargar a RAM

							RJMP MAIN

						RST_CNT_D_M:
							
							LDS R21, DHOR
							CPI R21, 0x02			; Verificar si ya son 24 horas
							BREQ RST_CNT_M			; Si ya son, resetear todo, sino saltar
							RJMP continue1			

							RST_CNT_M:
								LDI R21, 0x00			
								STS SEGS, R21			; Reiniciar contador segundos
								STS UMIN, R21			; Reiniciar contador unidades minutos
								STS DMIN, R21			; Reiniciar contador decenas minutos
								STS UHOR, R21			; Reiniciar contador unidades horas	
								STS DHOR, R21			; Reiniciar contador decenas horas	

								RJMP COMP_DATE			; Día completo, iniciar condicionales de fecha
		; ==================================
		; Condicionales Fecha
		; ==================================
		
		COMP_DATE:
		
		;----final 28----
		fin_28:
			LDS R21, UDAT			; Cargar de RAM
			CPI R21, 0x08			; Verificar si unidad es 8
			BREQ VER_28				; Si si, verificar si es 2
			RJMP fin_30

			VER_28:
				LDS R21, DDAT
				CPI R21, 0x02			; Verificar si decena es 2 para 28
				BREQ VER_FEB_D			; Si si, verificar febrero
				RJMP fin_30

				VER_FEB_D:
					LDS R21, DMON
					CPI R21, 0x00			; Verificar si decena es 0
					BREQ VER_FEB_U			; Si si, verificar si es 2
					RJMP fin_30
					
					VER_FEB_U:
						LDS R21, UMON
						CPI R21, 0x02			; Verificar si es 02
						BREQ RST_DAY_FEB		; Si si, resetear counter y aumentar a marzo
						RJMP fin_30
						RST_DAY_FEB:
							RJMP INC_MON
		;----final 30----
		fin_30:
			LDS R21, UDAT
			CPI R21, 0x00			; Verificar si unidad dia es 0
			BREQ VER_30				; si si, verificar decena
			RJMP fin_31
			
			VER_30:
				LDS R21, DDAT
				CPI R21, 0x03			; Verificar si decena es 3
				BREQ VER_30_INC			; Si si, verificar que mes es
				RJMP fin_31

				VER_30_INC:
					LDS R21, DMON
					CPI R21, 0x01			; Verificar si decena mes es 1
					BREQ VER_NOV			; Si si, verificar si es noviembre
					RJMP continue3

					VER_NOV:
						LDS R21, UMON
						CPI R21, 0x01			; Verificar si unidad es 1
						BREQ RST_DAY_30			; Si si, reiniciar dia y aumentar mes

					continue3:
					LDS R21, UMON
					CPI R21, 0x04			; Verificar si es abril
					BREQ RST_DAY_30			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x06			; Verificar si es junio
					BREQ RST_DAY_30			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x09			; Verificar si es septiembre
					BREQ RST_DAY_30			; Si si, reiniciar dia y aumentar mes
					RJMP fin_31

					RST_DAY_30:
						RJMP INC_MON
					


		;----final 31----
		fin_31:
			LDS R21, UDAT
			CPI R21, 0x01			; Verificar si unidad dia es 1
			BREQ VER_31				; Si si, verificar decena dia
			RJMP fin_9

			VER_31:
				LDS R21, DDAT
				CPI R21, 0x03			; Verificar si decena dia es 3
				BREQ VER_31_INC			; Si si, verificar que mes
				RJMP fin_9

				VER_31_INC:
					LDS R21, DMON
					CPI R21, 0x01			; Verificar si decena mes es 1
					BREQ VER_OCTDIC			; Si si, verificar si es octubre o diciembre
					RJMP continue4

					VER_OCTDIC:
						LDS R21, UMON
						CPI R21, 0x00			; Verificar si es octubre
						BREQ RST_DAY_31			; Si si, reiniciar dia y aumentar mes
						CPI R21, 0x02			; Verificar si es diciembre
						BREQ RST_DAY_31			; Si si, reiniciar dia y aumentar mes

					continue4:
					LDS R21, UMON
					CPI R21, 0x01			; Verificar si es enero
					BREQ RST_DAY_31			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x03			; Verificar si es marzo
					BREQ RST_DAY_31			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x05			; Verificar si es mayo
					BREQ RST_DAY_31			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x07			; Verificar si es julio
					BREQ RST_DAY_31			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x08			; Verificar si es agosto
					BREQ RST_DAY_31			; Si si, reiniciar dia y aumentar mes
					RJMP fin_9

					RST_DAY_31:
						RJMP INC_MON

		;----inc a dia cuando unidad es 9----
		fin_9:
			LDS R21, UDAT
			CPI R21, 0x09			; Verificar si unidad es 9
			BREQ INC_DAY_D			; Si si, incrementar decena, sino saltar
			LDS R21, UDAT
			INC R21					; Incrementar unidad dia
			STS UDAT, R21
			RJMP MAIN

			INC_DAY_D:
				LDI R21, 0x00
				STS UDAT, R21		; Reiniciar unidad dia

				LDS R21, DDAT
				INC R21				; Incrementar decena dia
				STS DDAT, R21
				RJMP MAIN

		;----incrementar mes----
			INC_MON:
				LDI R21, 0x01			; Resetear el dia a 01
				STS UDAT, R21
				LDI R21, 0x00
				STS DDAT, R21

				LDS R21, UMON
				CPI R21, 0x02			; Verificar si unidad de mes es 2
				BREQ VER_MON_D_1		; Si si, verificar si decena es 1
				RJMP continue2

				VER_MON_D_1:
					LDS R21, DMON
					CPI R21, 0x01			; Verificar si decena de mes es 1
					BREQ RST_ALL			; Si si, resetear toda la fecha
					RJMP continue2

					RST_ALL:
						LDI R21, 0x01
						STS UDAT, R21			; Reiniciar unidades mes y dia a 01;01
						STS UMON, R21
						LDI R21, 0x00
						STS DDAT, R21			; Reiniciar decenas mes a 0
						STS DMON, R21

						STS SEGS, R21			; Reiniciar contador segundos
						STS UMIN, R21			; Reiniciar contador unidades minutos
						STS DMIN, R21			; Reiniciar contador decenas minutos
						STS UHOR, R21			; Reiniciar contador unidades horas	
						STS DHOR, R21			; Reiniciar contador decenas horas
						RJMP MAIN

				continue2:
				LDS R21, UMON
				CPI R21, 0x09			; Verificar si unidad de mes en limite 9
				BREQ RST_MON			; Si si, pasar a octubre-diciembre

				INC R21
				STS UMON, R21			; Incrementar unidades mes

				RJMP MAIN

				RST_MON:
					LDI R21, 0x00
					STS UMON, R21			; Pasar unidades mes de 9 a 0
					LDI R21, 0x01
					STS DMON, R21			; Pasar decenas mes de 0 a 1
					RJMP MAIN
		RJMP MAIN

		; ==================================
		; Alternadores de display
		; ==================================

; =============================
; Alternador de hora
; =============================
alternador_hora:
		CPI R18, 0						; si es 0 alternar a 1 y mostrar display 0
		BREQ SHW_DISP_0
		RJMP nextdisp1
		SHW_DISP_0:
			LDI R18, 0x01				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			SBI PORTB, 0				; Deshabilitar display 3
			SBI PORTB, 1				; Deshabilitar display 2
			SBI PORTB, 2				; Deshabilitar display 1
			CBI PORTB, 3				; Habilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			LDS R21, UMIN
			ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R17, Z					; Cargar pointer en registro
			OUT PORTD, R17				; Mostrar registro en puerto D

			RJMP MAIN
	nextdisp1:
		CPI R18, 1						; si es 1 alternar a 2 y mostrar display 1
		BREQ SHW_DISP_1
		RJMP nextdisp2
		SHW_DISP_1:
			LDI R18, 0x02				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			SBI PORTB, 0				; Deshabilitar display 3
			SBI PORTB, 1				; Deshabilitar display 2
			CBI PORTB, 2				; Habilitar display 1
			SBI PORTB, 3				; Deshabilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			LDS R21, DMIN
			ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R17, Z					; Cargar pointer en registro
			OUT PORTD, R17				; Mostrar registro en puerto D

			RJMP MAIN
	nextdisp2:
		CPI R18, 2						; si es 2 alternar a 3 y mostrar display 2
		BREQ SHW_DISP_2
		RJMP nextdisp3
		SHW_DISP_2:
			LDI R18, 0x03				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			SBI PORTB, 0				; Deshabilitar display 3
			CBI PORTB, 1				; Habilitar display 2
			SBI PORTB, 2				; Deshabilitar display 1
			SBI PORTB, 3				; Deshabilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			LDS R21, UHOR
			ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R17, Z					; Cargar pointer en registro
			OUT PORTD, R17				; Mostrar registro en puerto D	

			CPI R25, 1					; Condicionales para el punto
			BREQ DOT_ON
			CPI R25, 0
			BREQ DOT_OFF
			RJMP MAIN

			DOT_ON:
				SBI PORTD, 7
				RJMP MAIN
			DOT_OFF:
				CBI PORTD, 7
				RJMP MAIN

	nextdisp3:
		CPI R18, 3						; si es 3 alternar a 0 y mostrar display 3
		BREQ SHW_DISP_3
		RJMP MAIN

		SHW_DISP_3:
			LDI R18, 0x00				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			CBI PORTB, 0				; Habilitar display 3
			SBI PORTB, 1				; Deshabilitar display 2
			SBI PORTB, 2				; Deshabilitar display 1
			SBI PORTB, 3				; Deshabilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			LDS R21, DHOR
			ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R17, Z					; Cargar pointer en registro
			OUT PORTD, R17				; Mostrar registro en puerto D

			RJMP MAIN

; =============================
; Alternador de fecha
; =============================

alternador_fecha:
	CPI R18, 0						; si es 0 alternar a 1 y mostrar display 0
		BREQ SHW_DISP_0_DATE
		RJMP nextdisp4
		SHW_DISP_0_DATE:
			LDI R18, 0x01				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			SBI PORTB, 0				; Deshabilitar display 3
			SBI PORTB, 1				; Deshabilitar display 2
			SBI PORTB, 2				; Deshabilitar display 1
			CBI PORTB, 3				; Habilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			LDS R21, UMON
			ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R17, Z					; Cargar pointer en registro
			OUT PORTD, R17				; Mostrar registro en puerto D

			RJMP MAIN
	nextdisp4:
		CPI R18, 1						; si es 1 alternar a 2 y mostrar display 1
		BREQ SHW_DISP_1_DATE
		RJMP nextdisp5
		SHW_DISP_1_DATE:
			LDI R18, 0x02				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			SBI PORTB, 0				; Deshabilitar display 3
			SBI PORTB, 1				; Deshabilitar display 2
			CBI PORTB, 2				; Habilitar display 1
			SBI PORTB, 3				; Deshabilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			LDS R21, DMON
			ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R17, Z					; Cargar pointer en registro
			OUT PORTD, R17				; Mostrar registro en puerto D

			RJMP MAIN
	nextdisp5:
		CPI R18, 2						; si es 2 alternar a 3 y mostrar display 2
		BREQ SHW_DISP_2_DATE
		RJMP nextdisp6
		SHW_DISP_2_DATE:
			LDI R18, 0x03				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			SBI PORTB, 0				; Deshabilitar display 3
			CBI PORTB, 1				; Habilitar display 2
			SBI PORTB, 2				; Deshabilitar display 1
			SBI PORTB, 3				; Deshabilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			LDS R21, UDAT
			ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R17, Z					; Cargar pointer en registro
			OUT PORTD, R17				; Mostrar registro en puerto D	

			CPI R25, 1					; Condicionales para el punto
			BREQ DOT_ON_DATE
			CPI R25, 0
			BREQ DOT_OFF_DATE
			RJMP MAIN

			DOT_ON_DATE:
				SBI PORTD, 7
				RJMP MAIN
			DOT_OFF_DATE:
				CBI PORTD, 7
				RJMP MAIN

	nextdisp6:
		CPI R18, 3						; si es 3 alternar a 0 y mostrar display 3
		BREQ SHW_DISP_3_DATE
		RJMP MAIN

		SHW_DISP_3_DATE:
			LDI R18, 0x00				; Alternar
			LDI R16, 0x00
			OUT PORTD, R16				; Eliminar ghost de PORTD

			CBI PORTB, 0				; Habilitar display 3
			SBI PORTB, 1				; Deshabilitar display 2
			SBI PORTB, 2				; Deshabilitar display 1
			SBI PORTB, 3				; Deshabilitar display 0

			LDI ZL, LOW(TRADUCTOR << 1)	;
			LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

			LDS R21, DDAT
			ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
			ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
			LPM R17, Z					; Cargar pointer en registro
			OUT PORTD, R17				; Mostrar registro en puerto D

			RJMP MAIN

		RJMP MAIN

; =============================================
; Contador de overflow para 7 segmentos, 20ms
; =============================================

CNT_OVF:
	SBI TIFR0, TOV0				; Limpiar bandera de "overflow"
    LDI R16, 178	
    OUT TCNT0, R16				; Volver a cargar valor inicial en TCNT0

	INC R20

	RETI

; =============================================
; Interrupciones de botón
; =============================================

;BTN_INT: