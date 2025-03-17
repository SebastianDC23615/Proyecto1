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

S_SEGS: .byte 1			; Asigmar a RAM config de segundos
S_UMIN: .byte 1			; Asignar a RAM config de hora
S_DMIN: .byte 1			; Asignar a RAM config de hora
S_UHOR: .byte 1			; Asignar a RAM config de hora
S_DHOR: .byte 1			; Asignar a RAM config de hora

S_UMON: .byte 1			; Asignar a RAM config de fecha
S_DMON: .byte 1			; Asignar a RAM config de fecha
S_UDAT: .byte 1			; Asignar a RAM config de fecha
S_DDAT: .byte 1			; Asignar a RAM config de fecha

UMALARM: .byte 1		; Asignar a RAM unidades de minuto para alarma
DMALARM: .byte 1		; Asignar a RAM decenas de minuto para alarma
UHALARM: .byte 1		; Asignar a RAM unidades de hora para alarma
DHALARM: .byte 1		; Asignar a RAM decenas de hora para alarma

.cseg
.org 0x0000
JMP START

.org 0x0008		; Vector de interrupción para PORTC
JMP INT_PCINT

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

		LDI R16, 0x0F				;
		OUT DDRC, R16				; Puerto C como entrada
		LDI R16, 0x0F				;
		OUT PORTC, R16				; Habilitar pullups en PC0, PC1, PC2 y PC3

		; =========================================
		; Interrupciones
		; =========================================

		LDI R16, (1<<PCIE1)					; Habilitar interrupciones en PORTC
		STS PCICR, R16						;

		LDI R16, (1<<PCINT8) | (1<<PCINT9) | (1<<PCINT10) | (1<<PCINT11)
		STS PCMSK1, R16						; Habilitar interrupciones en PC0, PC1, PC2 y PC3

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
		LDI R21, 0x9
		STS UMIN, R21				; Cargar inicial a unidades minutos		
		LDI R21, 0x2		
		STS DMIN, R21				; Cargar inicial a decenas minutos
		LDI R21, 0x06
		STS UHOR, R21				; Cargar inicial a unidades horas
		LDI R21, 0x00
		STS DHOR, R21				; Cargar inicial a decenas horas

		LDI R21, 0x01
		STS UMON, R21				; Cargar inicial a unidades mes	
		LDI R21, 0x00			
		STS DMON, R21				; Cargar inicial a decenas mes
		LDI R21, 0x01
		STS UDAT, R21				; Cargar inicial a unidades dia
		LDI R21, 0x00
		STS DDAT, R21				; Cargar inicial a decenas dia

		STS S_SEGS, R21				; Valor a guardar a segundos config 
		STS S_UMIN, R21				; Valor a guardar a unidades minutos config hora
		STS S_DMIN, R21				; Valor a guardar a decenas minutos config hora
		STS S_UHOR, R21				; Valor a guardar a unidades horas config hora
		STS S_DHOR, R21				; Valor a guardar a decenas horas config hora

		LDI R21, 0x01
		STS S_UMON, R21				; Valor a guardar a unidades mes config hora
		STS S_UDAT, R21				; Valor a guardar a unidades dia config hora
		LDI R21, 0x00
		STS S_DMON, R21				; Valor a guardar a decenas mes config hora
		STS S_DDAT, R21				; Valor a guardar a decenas dia config hora

		LDI R21, 0
		STS UMALARM, R21			; Valor a guardar unidades de minuto alarma
		LDI R21, 3
		STS DMALARM, R21			; Valor a guardar decenas de minuto alarma
		LDI R21, 6
		STS UHALARM, R21			; Valor a guardar unidades de hora alarma
		LDI R21, 0
		STS DHALARM, R21			; Valor a guardar decenas de hora alarma

		SEI							; Habilitar interrupciones

	; =============================================
	; Bucle Principal
	; =============================================

	MAIN:
		
		LDS R21, UMALARM
		LDS R22, UMIN
		CP R21, R22
		BREQ MAIN_VERALRM_DM
		CBI PINB, 4
		RJMP cont_main

		MAIN_VERALRM_DM:
			LDS R21, DMALARM
			LDS R22, DMIN
			CP R21, R22
			BREQ MAIN_VERALRM_UH
			CBI PINB, 4
			RJMP cont_main

			MAIN_VERALRM_UH:
				LDS R21, UHALARM
				LDS R22, UHOR
				CP R21, R22
				BREQ MAIN_VERALRM_DH
				CBI PINB, 4
				RJMP cont_main

				MAIN_VERALRM_DH:
					LDS R21, DHALARM
					LDS R22, DHOR
					CPSE R21, R22
					RJMP cont_main
					SBI PINB, 4

		cont_main:
		CBI PINB, 4
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
			RJMP alternador_config_hora
		alt_fecha_config:
			RJMP alternador_config_fecha
		alt_alarm:
			RJMP alternador_alarma

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
			
			CBI PINB, 4
			CPI R19, 2
			BREQ mainjump
			CPI R19, 3
			BREQ mainjump
			CPI R19, 4
			BREQ mainjump

			;RJMP RST_CNT_M				; Activar para correr fecha mas rapido
			LDS R21, SEGS
			CPI R21, 59					; Verificar si segundos ya es 59
			BREQ RST_CNT_S				; Si ya es 59, resetear counter, sino saltar 

			INC R21						; Incrementar contador segundos
			STS SEGS, R21
			mainjump:
			RJMP MAIN

			RST_CNT_S:

				LDI R21, 0x00
				OUT PORTB, R21
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
		SBI PORTC, 4
		CBI PORTC, 5
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
		SBI PORTC, 5
		CBI PORTC, 4
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

; =============================
; Alternador config de hora
; =============================

alternador_config_hora:
	CPI R18, 0						; si es 0 alternar a 1 y mostrar display 0
	BREQ SHW_DISP_0_CONF
	RJMP nextdisp7
	SHW_DISP_0_CONF:
		LDI R18, 0x01				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		SBI PORTB, 0				; Deshabilitar display 3
		SBI PORTB, 1				; Deshabilitar display 2
		SBI PORTB, 2				; Deshabilitar display 1
		CBI PORTB, 3				; Habilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, S_UMIN
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D

		RJMP alternador_config_hora
nextdisp7:
	CPI R18, 1						; si es 1 alternar a 2 y mostrar display 1
	BREQ SHW_DISP_1_CONF
	RJMP nextdisp8
	SHW_DISP_1_CONF:
		LDI R18, 0x02				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		SBI PORTB, 0				; Deshabilitar display 3
		SBI PORTB, 1				; Deshabilitar display 2
		CBI PORTB, 2				; Habilitar display 1
		SBI PORTB, 3				; Deshabilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, S_DMIN
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D

		RJMP alternador_config_hora
nextdisp8:
	CPI R18, 2						; si es 2 alternar a 3 y mostrar display 2
	BREQ SHW_DISP_2_CONF
	RJMP nextdisp9
	SHW_DISP_2_CONF:
		LDI R18, 0x03				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		SBI PORTB, 0				; Deshabilitar display 3
		CBI PORTB, 1				; Habilitar display 2
		SBI PORTB, 2				; Deshabilitar display 1
		SBI PORTB, 3				; Deshabilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, S_UHOR
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D	

		CPI R25, 1					; Condicionales para el punto
		BREQ DOT_ON_CONF
		CPI R25, 0
		BREQ DOT_OFF_CONF
		RJMP alternador_config_hora

		DOT_ON_CONF:
			CBI PORTC, 5
			SBI PORTC, 4
			SBI PORTD, 7
			RJMP MAIN
		DOT_OFF_CONF:
			CBI PORTC, 5
			CBI PORTC, 4
			CBI PORTD, 7
			RJMP MAIN

nextdisp9:
	CPI R18, 3						; si es 3 alternar a 0 y mostrar display 3
	BREQ SHW_DISP_3_CONF
	RJMP alternador_config_hora

	SHW_DISP_3_CONF:
		LDI R18, 0x00				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		CBI PORTB, 0				; Habilitar display 3
		SBI PORTB, 1				; Deshabilitar display 2
		SBI PORTB, 2				; Deshabilitar display 1
		SBI PORTB, 3				; Deshabilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, S_DHOR
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D

		RJMP alternador_config_hora

	RJMP alternador_config_hora
	
; =============================
; Alternador config de fecha
; =============================

alternador_config_fecha:
	CPI R18, 0						; si es 0 alternar a 1 y mostrar display 0
	BREQ SHW_DISP_0_CONF_DATE
	RJMP nextdisp10
	SHW_DISP_0_CONF_DATE:
		LDI R18, 0x01				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		SBI PORTB, 0				; Deshabilitar display 3
		SBI PORTB, 1				; Deshabilitar display 2
		SBI PORTB, 2				; Deshabilitar display 1
		CBI PORTB, 3				; Habilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, S_UMON
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D

		RJMP alternador_config_fecha
nextdisp10:
	CPI R18, 1						; si es 1 alternar a 2 y mostrar display 1
	BREQ SHW_DISP_1_CONF_DATE
	RJMP nextdisp11
	SHW_DISP_1_CONF_DATE:
		LDI R18, 0x02				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		SBI PORTB, 0				; Deshabilitar display 3
		SBI PORTB, 1				; Deshabilitar display 2
		CBI PORTB, 2				; Habilitar display 1
		SBI PORTB, 3				; Deshabilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, S_DMON
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D

		RJMP alternador_config_fecha
nextdisp11:
	CPI R18, 2						; si es 2 alternar a 3 y mostrar display 2
	BREQ SHW_DISP_2_CONF_DATE
	RJMP nextdisp12
	SHW_DISP_2_CONF_DATE:
		LDI R18, 0x03				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		SBI PORTB, 0				; Deshabilitar display 3
		CBI PORTB, 1				; Habilitar display 2
		SBI PORTB, 2				; Deshabilitar display 1
		SBI PORTB, 3				; Deshabilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, S_UDAT
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D	

		CPI R25, 1					; Condicionales para el punto
		BREQ DOT_ON_CONF_DATE
		CPI R25, 0
		BREQ DOT_OFF_CONF_DATE
		RJMP alternador_config_fecha

		DOT_ON_CONF_DATE:
			SBI PORTC, 5
			CBI PORTC, 4
			SBI PORTD, 7
			RJMP MAIN
		DOT_OFF_CONF_DATE:
			CBI PORTC, 5
			CBI PORTC, 4
			CBI PORTD, 7
			RJMP MAIN

nextdisp12:
	CPI R18, 3						; si es 3 alternar a 0 y mostrar display 3
	BREQ SHW_DISP_3_CONF_DATE
	RJMP alternador_config_fecha

	SHW_DISP_3_CONF_DATE:
		LDI R18, 0x00				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		CBI PORTB, 0				; Habilitar display 3
		SBI PORTB, 1				; Deshabilitar display 2
		SBI PORTB, 2				; Deshabilitar display 1
		SBI PORTB, 3				; Deshabilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, S_DDAT
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D

		RJMP alternador_config_fecha


	RJMP alternador_config_fecha

; =============================
; Alternador alarma
; =============================

alternador_alarma:
	CBI PORTC, 5
	CBI PORTC, 4
	CPI R18, 0						; si es 0 alternar a 1 y mostrar display 0
	BREQ SHW_DISP_0_ALARM
	RJMP nextdisp13
	SHW_DISP_0_ALARM:
		LDI R18, 0x01				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		SBI PORTB, 0				; Deshabilitar display 3
		SBI PORTB, 1				; Deshabilitar display 2
		SBI PORTB, 2				; Deshabilitar display 1
		CBI PORTB, 3				; Habilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, UMALARM
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D

		RJMP alternador_alarma
nextdisp13:
	CPI R18, 1						; si es 1 alternar a 2 y mostrar display 1
	BREQ SHW_DISP_1_ALARM
	RJMP nextdisp14
	SHW_DISP_1_ALARM:
		LDI R18, 0x02				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		SBI PORTB, 0				; Deshabilitar display 3
		SBI PORTB, 1				; Deshabilitar display 2
		CBI PORTB, 2				; Habilitar display 1
		SBI PORTB, 3				; Deshabilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, DMALARM
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D

		RJMP alternador_alarma
nextdisp14:
	CPI R18, 2						; si es 2 alternar a 3 y mostrar display 2
	BREQ SHW_DISP_2_ALARM
	RJMP nextdisp15
	SHW_DISP_2_ALARM:
		LDI R18, 0x03				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		SBI PORTB, 0				; Deshabilitar display 3
		CBI PORTB, 1				; Habilitar display 2
		SBI PORTB, 2				; Deshabilitar display 1
		SBI PORTB, 3				; Deshabilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, UHALARM
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D	

		CPI R25, 1					; Condicionales para el punto
		BREQ DOT_ON_ALARM
		CPI R25, 0
		BREQ DOT_OFF_ALARM

		RJMP alternador_alarma

		DOT_ON_ALARM:
			SBI PORTC, 5
			SBI PORTC, 4
			SBI PORTD, 7
			RJMP MAIN
		DOT_OFF_ALARM:
			CBI PORTC, 5
			CBI PORTC, 4
			CBI PORTD, 7
			RJMP MAIN

nextdisp15:
	CPI R18, 3						; si es 3 alternar a 0 y mostrar display 3
	BREQ SHW_DISP_3_ALARM
	RJMP alternador_alarma

	SHW_DISP_3_ALARM:
		LDI R18, 0x00				; Alternar
		LDI R16, 0x00
		OUT PORTD, R16				; Eliminar ghost de PORTD

		CBI PORTB, 0				; Habilitar display 3
		SBI PORTB, 1				; Deshabilitar display 2
		SBI PORTB, 2				; Deshabilitar display 1
		SBI PORTB, 3				; Deshabilitar display 0

		LDI ZL, LOW(TRADUCTOR << 1)	;
		LDI ZH, HIGH(TRADUCTOR << 1); Reiniciar pointer 

		LDS R21, DHALARM
		ADC ZL, R21					; Sumar el valor de unidades segundos a ZL (parte baja)
		ADC ZH, R1 					; Sumar el acarreo a ZH (parte alta)
		LPM R17, Z					; Cargar pointer en registro
		OUT PORTD, R17				; Mostrar registro en puerto D

		RJMP alternador_alarma


	RJMP alternador_alarma

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

INT_PCINT:
	LDI R16, 0x00
	OUT PORTB, R16
    SBIS PINC, 0            ; Verificar si PC0 está cleared
    RJMP BUT_STATE			; Si no, ejecutar funcion de boton estado
	SBIS PINC, 1
	RJMP BUT_INC
	SBIS PINC, 2
	RJMP BUT_DEC

	RETI

; ==============================================
; Condicionales para boton que cambia de estado
; ==============================================

	BUT_STATE:

		CPI R19, 0				; Verificar estado del estado
		BREQ STATE_1			; si es 0, saltar a estado 1
		RJMP cont1

		STATE_1:					; Estado mostrar fecha
			LDI R19, 1

			RETI 

		cont1:
		CPI R19, 1
		BREQ STATE_2			; si es 1, saltar a estado 2
		RJMP cont2

		STATE_2:					; Estado config hora
			LDI R19, 2

			; segundos tomar de actual y mover a config
			LDS R21, SEGS
			STS S_SEGS, R21

			; hora tomar de actual y mover a config
			LDS R21, UMIN			; Tomar unidad minuto actual  
			STS S_UMIN, R21			; Guardar en config
			LDS R21, DMIN			; Tomar decena minuto actual
			STS S_DMIN, R21			; Guardar en config 
			LDS R21, UHOR			; Tomar unidad hora actual
			STS S_UHOR, R21			; Guardar en config
			LDS R21, DHOR			; Tomar decena hora actual
			STS S_DHOR, R21			; Guardar en config

			; fecha tomar de actual y mover a config
			LDS R21, UMON			; Tomar unidad mes actual  
			STS S_UMON, R21			; Guardar en config
			LDS R21, DMON			; Tomar decena mes actual
			STS S_DMON, R21			; Guardar en config 
			LDS R21, UDAT			; Tomar unidad dia actual
			STS S_UDAT, R21			; Guardar en config
			LDS R21, DDAT			; Tomar decena dia actual
			STS S_DDAT, R21			; Guardar en config

			RETI

		cont2:
		CPI R19, 2
		BREQ STATE_3			; si es 2, saltar a estado 3
		RJMP cont3

		STATE_3:					; Estado config fecha
			LDI R19, 3

			RETI

		cont3:
		CPI R19, 3
		BREQ STATE_4			; si es 3, saltar a estado 4
		RJMP cont4

		STATE_4:					; Estado config alarma
			LDI R19, 4

			RETI

		cont4:
		CPI R19, 4
		BREQ STATE_0			; si es 4, saltar a estado 0
		RJMP MAIN
		

		STATE_0:					; Estado mostrar hora
			LDI R19, 0

			; segundos tomar de config y mover a actual
			LDS R21, S_SEGS
			STS SEGS, R21
			LDI R20, 0x00

			; fecha tomar de config y mover a actual
			LDS R21, S_UMON			; Tomar unidad mes config  
			STS UMON, R21			; Guardar en actual
			LDS R21, S_DMON			; Tomar decena mes config
			STS DMON, R21			; Guardar en actual 
			LDS R21, S_UDAT			; Tomar unidad dia config
			STS UDAT, R21			; Guardar en actual
			LDS R21, S_DDAT			; Tomar decena dia config
			STS DDAT, R21			; Guardar en actual

			; hora tomar de config y mover a actual
			LDS R21, S_UMIN			; Tomar unidad minuto config  
			STS UMIN, R21			; Guardar en actual
			LDS R21, S_DMIN			; Tomar decena minuto config
			STS DMIN, R21			; Guardar en actual 
			LDS R21, S_UHOR			; Tomar unidad hora config
			STS UHOR, R21			; Guardar en actual
			LDS R21, S_DHOR			; Tomar decena hora config
			STS DHOR, R21			; Guardar en actual

			RETI

; ==============================================
; Condicionales para boton que incrementa (PC1)
; ==============================================
	
	BUT_INC:

		;-------Para incrementar hora-------
		CPI R19, 2
		BREQ INC_HORA_CONFIG

		RJMP hor_cont
		
		INC_HORA_CONFIG:
			;----Condicionales para aumentar hora----

			LDS R21, S_UMIN
			CPI R21, 9
			BREQ RST_DMIN_S
			
			LDS R21, S_UMIN
			INC R21
			STS S_UMIN, R21
			RETI

			RST_DMIN_S:
				LDI R21, 0
				STS S_UMIN, R21

				LDS R21, S_DMIN
				CPI R21, 5
				BREQ RST_UHOR_S

				LDS R21, S_DMIN
				INC R21
				STS S_DMIN, R21
				RETI

				RST_UHOR_S:
					LDI R21, 0
					STS S_UMIN, R21
					STS S_DMIN, R21

					LDS R21, S_UHOR
					CPI R21, 3
					BREQ VER_24H_S
					RJMP but_cont1

					VER_24H_S:
						LDS R21, S_DHOR
						CPI R21, 2
						BREQ RST_ALL_S

					but_cont1:
					LDS R21, S_UHOR
					CPI R21, 9
					BREQ RST_DHOR_S

					LDS R21, S_UHOR
					INC R21
					STS S_UHOR, R21

					RETI

					RST_DHOR_S:
						LDI R21, 0
						STS S_UMIN, R21
						STS S_DMIN, R21
						STS S_UHOR, R21

						LDS R21, S_DHOR
						INC R21
						STS S_DHOR, R21

						RETI

					RST_ALL_S:
						LDI R21, 0
						STS S_UMIN, R21
						STS S_DMIN, R21
						STS S_UHOR, R21
						STS S_DHOR, R21
						RETI
						


		hor_cont:
		;-------Para incrementar fecha------
		CPI R19, 3
		BREQ INC_FECHA_CONFIG
		RJMP alrm_cont

		INC_FECHA_CONFIG:
			
			;----final 28----
		fin_28_S:
			LDS R21, S_UDAT			; Cargar de RAM
			CPI R21, 0x08			; Verificar si unidad es 8
			BREQ VER_28_S				; Si si, verificar si es 2
			RJMP fin_30_S

			VER_28_S:
				LDS R21, S_DDAT
				CPI R21, 0x02			; Verificar si decena es 2 para 28
				BREQ VER_FEB_D_S			; Si si, verificar febrero
				RJMP fin_30_S

				VER_FEB_D_S:
					LDS R21, S_DMON
					CPI R21, 0x00			; Verificar si decena es 0
					BREQ VER_FEB_U_S			; Si si, verificar si es 2
					RJMP fin_30_S
					
					VER_FEB_U_S:
						LDS R21, S_UMON
						CPI R21, 0x02			; Verificar si es 02
						BREQ RST_DAY_FEB_S		; Si si, resetear counter y aumentar a marzo
						RJMP fin_30_S
						RST_DAY_FEB_S:
							RJMP INC_MON_S
		;----final 30----
		fin_30_S:
			LDS R21, S_UDAT
			CPI R21, 0x00			; Verificar si unidad dia es 0
			BREQ VER_30_S				; si si, verificar decena
			RJMP fin_31_S
			
			VER_30_S:
				LDS R21, S_DDAT
				CPI R21, 0x03			; Verificar si decena es 3
				BREQ VER_30_S_INC			; Si si, verificar que mes es
				RJMP fin_31_S

				VER_30_S_INC:
					LDS R21, S_DMON
					CPI R21, 0x01			; Verificar si decena mes es 1
					BREQ VER_NOV_S			; Si si, verificar si es noviembre
					RJMP continue3_S

					VER_NOV_S:
						LDS R21, S_UMON
						CPI R21, 0x01			; Verificar si unidad es 1
						BREQ RST_DAY_30_S			; Si si, reiniciar dia y aumentar mes

					continue3_S:
					LDS R21, S_UMON
					CPI R21, 0x04			; Verificar si es abril
					BREQ RST_DAY_30_S			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x06			; Verificar si es junio
					BREQ RST_DAY_30_S			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x09			; Verificar si es septiembre
					BREQ RST_DAY_30_S			; Si si, reiniciar dia y aumentar mes
					RJMP fin_31_S

					RST_DAY_30_S:
						RJMP INC_MON_S
					


		;----final 31----
		fin_31_S:
			LDS R21, S_UDAT
			CPI R21, 0x01			; Verificar si unidad dia es 1
			BREQ VER_31_S				; Si si, verificar decena dia
			RJMP fin_9_S

			VER_31_S:
				LDS R21, S_DDAT
				CPI R21, 0x03			; Verificar si decena dia es 3
				BREQ VER_31_S_INC			; Si si, verificar que mes
				RJMP fin_9_S

				VER_31_S_INC:
					LDS R21, S_DMON
					CPI R21, 0x01			; Verificar si decena mes es 1
					BREQ VER_OCTDIC_S			; Si si, verificar si es octubre o diciembre
					RJMP continue4_S

					VER_OCTDIC_S:
						LDS R21, S_UMON
						CPI R21, 0x00			; Verificar si es octubre
						BREQ RST_DAY_31_S			; Si si, reiniciar dia y aumentar mes
						CPI R21, 0x02			; Verificar si es diciembre
						BREQ RST_DAY_31_S			; Si si, reiniciar dia y aumentar mes

					continue4_S:
					LDS R21, S_UMON
					CPI R21, 0x01			; Verificar si es enero
					BREQ RST_DAY_31_S			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x03			; Verificar si es marzo
					BREQ RST_DAY_31_S			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x05			; Verificar si es mayo
					BREQ RST_DAY_31_S			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x07			; Verificar si es julio
					BREQ RST_DAY_31_S			; Si si, reiniciar dia y aumentar mes
					CPI R21, 0x08			; Verificar si es agosto
					BREQ RST_DAY_31_S			; Si si, reiniciar dia y aumentar mes
					RJMP fin_9_S

					RST_DAY_31_S:
						RJMP INC_MON_S

		;----inc a dia cuando unidad es 9----
		fin_9_S:
			LDS R21, S_UDAT
			CPI R21, 0x09			; Verificar si unidad es 9
			BREQ INC_DAY_D_S			; Si si, incrementar decena, sino saltar
			LDS R21, S_UDAT
			INC R21					; Incrementar unidad dia
			STS S_UDAT, R21
			RETI

			INC_DAY_D_S:
				LDI R21, 0x00
				STS S_UDAT, R21		; Reiniciar unidad dia

				LDS R21, S_DDAT
				INC R21				; Incrementar decena dia
				STS S_DDAT, R21
				RETI

		;----incrementar mes----
			INC_MON_S:
				LDI R21, 0x01			; Resetear el dia a 01
				STS S_UDAT, R21
				LDI R21, 0x00
				STS S_DDAT, R21

				LDS R21, S_UMON
				CPI R21, 0x02			; Verificar si unidad de mes es 2
				BREQ VER_MON_D_1_S		; Si si, verificar si decena es 1
				RJMP continue2_S

				VER_MON_D_1_S:
					LDS R21, S_DMON
					CPI R21, 0x01			; Verificar si decena de mes es 1
					BREQ RST_ALL_S_D			; Si si, resetear toda la fecha
					RJMP continue2_S

					RST_ALL_S_D:
						LDI R21, 0x01
						STS S_UDAT, R21			; Reiniciar unidades mes y dia a 01;01
						STS S_UMON, R21
						LDI R21, 0x00
						STS S_DDAT, R21			; Reiniciar decenas mes a 0
						STS S_DMON, R21

						RETI

				continue2_S:
				LDS R21, S_UMON
				CPI R21, 0x09			; Verificar si unidad de mes en limite 9
				BREQ RST_MON_S			; Si si, pasar a octubre-diciembre

				INC R21
				STS S_UMON, R21			; Incrementar unidades mes

				RETI

				RST_MON_S:
					LDI R21, 0x00
					STS S_UMON, R21			; Pasar unidades mes de 9 a 0
					LDI R21, 0x01
					STS S_DMON, R21			; Pasar decenas mes de 0 a 1
					RETI
		RETI


		alrm_cont:
		;-------Para incrementar alarma-----
		CPI R19, 4
		BREQ INC_ALARM_CONFIG
		RETI

		INC_ALARM_CONFIG:

			LDS R21, UMALARM
			CPI R21, 9
			BREQ RST_DMIN_S_ALRM
			
			LDS R21, UMALARM
			INC R21
			STS UMALARM, R21
			RETI

			RST_DMIN_S_ALRM:
				LDI R21, 0
				STS UMALARM, R21

				LDS R21, DMALARM
				CPI R21, 5
				BREQ RST_UHOR_S_ALRM

				LDS R21, DMALARM
				INC R21
				STS DMALARM, R21
				RETI

				RST_UHOR_S_ALRM:
					LDI R21, 0
					STS UMALARM, R21
					STS DMALARM, R21

					LDS R21, UHALARM
					CPI R21, 3
					BREQ VER_24H_S_ALRM
					RJMP but_cont1_ALRM

					VER_24H_S_ALRM:
						LDS R21, DHALARM
						CPI R21, 2
						BREQ RST_ALL_S_ALRM

					but_cont1_ALRM:
					LDS R21, UHALARM
					CPI R21, 9
					BREQ RST_DHOR_S_ALRM

					LDS R21, UHALARM
					INC R21
					STS UHALARM, R21

					RETI

					RST_DHOR_S_ALRM:
						LDI R21, 0
						STS UMALARM, R21
						STS DMALARM, R21
						STS UHALARM, R21

						LDS R21, DHALARM
						INC R21
						STS DHALARM, R21

						RETI

					RST_ALL_S_ALRM:
						LDI R21, 0
						STS UMALARM, R21
						STS DMALARM, R21
						STS UHALARM, R21
						STS DHALARM, R21
						RETI

		RETI

; ==============================================
; Condicionales para boton que decrementa (PC2)
; ==============================================

	BUT_DEC:
		;----Para decrementar hora----
		CPI R19, 2
		BREQ DEC_HORA_CONFIG

		RJMP hor_cont2
		
		DEC_HORA_CONFIG:
			LDS R21, S_UMIN
			CPI R21, 0x00
			BREQ RST_UMIN_DEC
			
			LDS R21, S_UMIN
			DEC R21
			STS S_UMIN, R21
			RETI

			RST_UMIN_DEC:
				LDI R21, 0x09
				STS S_UMIN, R21

				LDS R21, S_DMIN
				CPI R21, 0x00
				BREQ RST_DMIN_DEC

				LDS R21, S_DMIN
				DEC R21
				STS S_DMIN, R21
				RETI

				RST_DMIN_DEC:
					LDI R21, 0x09
					STS S_UMIN, R21
					LDI R21, 0x05
					STS S_DMIN, R21

					LDS R21, S_UHOR
					CPI R21, 0x00
					BREQ RST_UHOR_DEC

					LDS R21, S_UHOR
					DEC R21
					STS S_UHOR, R21
					RETI
					
					RST_UHOR_DEC:
						LDI R21, 0x09
						STS S_UMIN, R21
						LDI R21, 0x05
						STS S_DMIN, R21
						LDI R21, 0x09
						STS S_UHOR, R21

						LDS R21, S_DHOR
						CPI R21, 0x00
						BREQ RST_DHOR_DEC

						LDS R21, S_DHOR
						DEC R21
						STS S_DHOR, R21
						RETI

						RST_DHOR_DEC:
							LDI R21, 0x09
							STS S_UMIN, R21
							LDI R21, 0x05
							STS S_DMIN, R21
							LDI R21, 0x03
							STS S_UHOR, R21
							LDI R21, 0x02
							STS S_DHOR, R21
							RETI



		;----Para decrementar fecha----
		hor_cont2:
		CPI R19, 3
		BREQ DEC_FECHA_CONFIG
		RJMP alarm_cont2
			
		DEC_FECHA_CONFIG:	
			LDS R21, S_UDAT
			CPI R21, 0x01
			BREQ VER_DEC_CONFIG
			RJMP conti1

			VER_DEC_CONFIG:
				LDS R21, S_DDAT
				CPI R21, 0x00
				BREQ DEC_MON_CONFIG
				
			conti1:
			LDS R21, S_UDAT
			CPI R21, 0x00
			BREQ DEC_DEC_CONFIG
			RJMP conti2

			DEC_DEC_CONFIG:
				LDI R21, 0x09
				STS S_UDAT, R21
				LDS R21, S_DDAT
				DEC R21
				STS S_DDAT, R21
				RETI
			
			conti2:
			LDS R21, S_UDAT
			DEC R21
			STS S_UDAT, R21
			RETI

			;----Decrementar mes
			DEC_MON_CONFIG:
				LDS R21, S_DMON
				CPI R21, 0x00    
				BREQ VER_RST_DEC
				RJMP deccont1

				VER_RST_DEC:
					LDS R21, S_UMON
					CPI R21, 0x01
					BREQ RST_TO_DEC
					RJMP deccont2

					RST_TO_DEC:
						LDI R21, 0x01
						STS S_UDAT, R21
						LDI R21, 0x03
						STS S_DDAT, R21
						LDI R21, 0x02
						STS S_UMON, R21
						LDI R21, 0x01
						STS S_DMON, R21
						RETI

					deccont2:
					LDS R21, S_UMON
					CPI R21, 0x02			; febrero
					BREQ RST_MON_31_S
					CPI R21, 0x03			; marzo
					BREQ RST_MON_28_S
					CPI R21, 0x04			; abril
					BREQ RST_MON_31_S
					CPI R21, 0x05			; mayo
					BREQ RST_MON_30_S
					CPI R21, 0x06			; junio
					BREQ RST_MON_31_S
					CPI R21, 0x07			; julio
					BREQ RST_MON_30_S
					CPI R21, 0x08			; agosto
					BREQ RST_MON_31_S
					CPI R21, 0x09			; septiembre
					BREQ RST_MON_31_S
					RJMP deccont1

					RST_MON_31_S:
						RJMP RST_31_S
					RST_MON_30_S:
						RJMP RST_30_S
					RST_MON_28_S:
						RJMP RST_28_S

				deccont1:
				LDS R21, S_DMON
				CPI R21, 0x01
				BREQ VER_OCTNOVDEC
				RETI
				
				VER_OCTNOVDEC:
					LDS R21, S_UMON
					CPI R21, 0x00			; octubre
					BREQ RST_MON_30_S
					CPI R21, 0x01			; noviembre
					BREQ RST_MON_31_S
					CPI R21, 0x02			; diciembre
					BREQ RST_MON_30_S
					RETI

				RST_30_S:
					LDS R21, S_DMON
					CPI R21, 0x01
					BREQ ver_oct
					RJMP contin1

					ver_oct:
						LDS R21, S_UMON
						CPI R21, 0x00
						BREQ rst_oct
						RJMP contin1

						rst_oct:
							LDI R21, 0x03
							STS S_DDAT, R21
							LDI R21, 0x00
							STS S_UDAT, R21
							LDI R21, 0x09
							STS S_UMON, R21
							LDI R21, 0x00
							STS S_DMON, R21
							RETI

					contin1:
					LDI R21, 0x03
					STS S_DDAT, R21
					LDI R21, 0x00
					STS S_UDAT, R21
					LDS R21, S_UMON
					DEC R21
					STS S_UMON, R21
					RETI

				RST_31_S:
					LDI R21, 0x03
					STS S_DDAT, R21
					LDI R21, 0x01
					STS S_UDAT, R21
					
					LDS R21, S_UMON
					DEC R21
					STS S_UMON, R21
					RETI

				RST_28_S:
					LDI R21, 0x02
					STS S_DDAT, R21
					LDI R21, 0x08
					STS S_UDAT, R21
					LDI R21, 0x00
					STS S_DMON, R21
					LDI R21, 0x02
					STS S_UMON, R21
					RETI
					
					


		;----Para decrementar alarma----
		alarm_cont2:
		CPI R19, 4
		BREQ DEC_ALARM
		RETI

		DEC_ALARM:
			LDS R21, UMALARM
			CPI R21, 0x00
			BREQ RST_UMIN_DEC_ALM
			
			LDS R21, UMALARM
			DEC R21
			STS UMALARM, R21
			RETI

			RST_UMIN_DEC_ALM:
				LDI R21, 0x09
				STS UMALARM, R21

				LDS R21, DMALARM
				CPI R21, 0x00
				BREQ RST_DMIN_DEC_ALM

				LDS R21, DMALARM
				DEC R21
				STS DMALARM, R21
				RETI

				RST_DMIN_DEC_ALM:
					LDI R21, 0x09
					STS UMALARM, R21
					LDI R21, 0x05
					STS DMALARM, R21

					LDS R21, UHALARM
					CPI R21, 0x00
					BREQ RST_UHOR_DEC_ALM

					LDS R21, UHALARM
					DEC R21
					STS UHALARM, R21
					RETI
					
					RST_UHOR_DEC_ALM:
						LDI R21, 0x09
						STS UMALARM, R21
						LDI R21, 0x05
						STS DMALARM, R21
						LDI R21, 0x09
						STS UHALARM, R21

						LDS R21, DHALARM
						CPI R21, 0x00
						BREQ RST_DHOR_DEC_ALM

						LDS R21, DHALARM
						DEC R21
						STS DHALARM, R21
						RETI

						RST_DHOR_DEC_ALM:
							LDI R21, 0x09
							STS UMALARM, R21
							LDI R21, 0x05
							STS DMALARM, R21
							LDI R21, 0x03
							STS UHALARM, R21
							LDI R21, 0x02
							STS DHALARM, R21
							RETI

		RETI