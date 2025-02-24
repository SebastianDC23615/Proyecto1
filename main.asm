; ============================================
; Universidad del Valle de Guatemala
; IE2024: Programaci�n de microcontroladores
; Proyecto 1
;
; Created: 24/02/2025
; Author : Sebasti�n Duarte Calder�n
; Hardware: ATmega328P
; Descripci�n: Proyecto 1, Reloj alarma con multiples modos
; ============================================

.include "m328Pdef.inc"

.cseg
.org 0x0000
JMP START

START:
	; =============================================
	; Configuraci�n de la pila
	; =============================================
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16

	; =============================================
	; Configuraci�n del MCU
	; =============================================

	SETUP:




	; =============================================
	; Bucle Principal
	; =============================================

	MAIN: