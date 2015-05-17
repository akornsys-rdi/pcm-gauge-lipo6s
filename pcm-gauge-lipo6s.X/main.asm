    LIST        P=PIC12F683          ; list directive to define processor
    #INCLUDE    <p12f683.inc>         ; processor specific variable definitions


; CONFIG
; __config 0xF0C4
 __CONFIG _FOSC_INTOSCIO & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _CP_OFF & _CPD_OFF & _BOREN_OFF & _IESO_OFF & _FCMEN_OFF

;Pinout
;   GP0/AN0 <- ADC  Volt (voltage divider 8.5:1)
;   GP1/AN1 <- ADC  Temp (LM35)
;   GP2     -> PWM  buzzer (without osc)
;   GP4     -> GPIO LED Warn
;   GP5     -> GPIO LED ok


Max_Volt    equ     0x93                ;  limite superior ADC0 (4.2 -> 25.2)
Min_Volt    equ     0x6E                ;  limite inferior ADC0 (3.1 -> 18.6)
Max_Temp    equ     0x26                ;  limite superior ADC1 (75º)
G_100       equ     0x93                ; 100%
G_083       equ     0x90                ; 83%
G_066       equ     0x8C                ; 66%
G_050       equ     0x87                ; 50%
G_033       equ     0x82                ; 33%
G_016       equ     0x7B                ; 16%
G_000       equ     0x71                ; 0%

    CBLOCK 0x3E                             ;  posiciones sólo en banco 0
    ADC0_LPFReg1                           ;  no mover de posición los registros LPF, posiciones fijas del 0x3E al 0x4D
    ADC0_LPFReg2                           ;  se usa direccionamiento indirecto
    ADC0_LPFReg3
    ADC0_LPFReg4
    ADC0_LPFReg5
    ADC0_LPFReg6
    ADC0_LPFReg7
    ADC0_LPFReg8
    ADC0_LPFReg9
    ADC0_LPFReg10
    ADC0_LPFReg11
    ADC0_LPFReg12
    ADC0_LPFReg13
    ADC0_LPFReg14
    ADC0_LPFReg15
    ADC0_LPFReg16
    ADC0_Accumulator_HI
    ADC0_Accumulator_LO
    ENDC

    CBLOCK 0x5E                             ;  posiciones sólo en banco 0
    ADC1_LPFReg1                           ;  no mover de posición los registros LPF, posiciones fijas del 0x5E al 0x6D
    ADC1_LPFReg2                           ;  se usa direccionamiento indirecto
    ADC1_LPFReg3
    ADC1_LPFReg4
    ADC1_LPFReg5
    ADC1_LPFReg6
    ADC1_LPFReg7
    ADC1_LPFReg8
    ADC1_LPFReg9
    ADC1_LPFReg10
    ADC1_LPFReg11
    ADC1_LPFReg12
    ADC1_LPFReg13
    ADC1_LPFReg14
    ADC1_LPFReg15
    ADC1_LPFReg16
    ADC1_Accumulator_HI
    ADC1_Accumulator_LO
    ENDC

    CBLOCK 0x70                             ;  posiciones comunes en bancos
    W_ISR
    STATUS_ISR
    ALARM_STAT
    DLoop1
    DLoop2
    DLoop3
    TmCount
    Dutycycle_ADC0
    Dutycycle_ADC1
    Dutycycle_HI
    Dutycycle_LO
    Aux
    ENDC

;------------------------------------------------------------------------------
; RESET VECTOR
;------------------------------------------------------------------------------
RES_VECT    code    0x0000  ; processor reset vector
    call    setup
    goto    main

ISR_VECT    code    0x0004  ; processor isr vector
    goto    isr

;------------------------------------------------------------------------------
; MAIN PROGRAM
;------------------------------------------------------------------------------
MAIN_PROG   code            ; let linker place main program

; TODO asegurar bancos

isr                         ; each ~8s
;interrupción TIMER0
    movwf   W_ISR                           ;  guardar estado
    swapf   STATUS,W
    movwf   STATUS_ISR
    incf    TmCount,F                  ;count 255 interrupts
    btfsc   STATUS,Z
    bsf     ALARM_STAT,0                ;then print
    banksel INTCON                          ;  desactivar flag de interrupción
    bcf     INTCON,T0IF
    swapf   STATUS_ISR,W                    ;  recuperar estado
    movwf   STATUS
    swapf   W_ISR,F
    swapf   W_ISR,W
    retfie

setup
    banksel OSCCON
    movlw   0x71
    movwf   OSCCON
;configurar puertos
    banksel GPIO                            ;  inicializar puertos
    clrf    GPIO
    movlw   0x07                            ;  comparador off
    movwf   CMCON0
    banksel ANSEL                           ;  máscara a modulo adc
    movlw   0x23                            ;  selecciona AN1 con fs osc/32
    movwf   ANSEL
    movlw   0x0F                            ;  configura todos los pines como entrada
    movwf   TRISIO
;configurar PWM
    movlw   0x37                            ;  establece frecuencia PWM (1.22 KHz)
    movwf   PR2
    banksel CCP1CON                         ;  PWM modo activo a nivel alto
    movlw   0x0C
    movwf   CCP1CON
    clrf    CCPR1L                          ;  MS byte factor de servicio
    bcf     PIR1,TMR2IF                     ;  borra el flag de igualdad entre timer2 y pr2
    movlw   0x07                            ;  timer2 on, no postscaler, prescaler 16
    movwf   T2CON
    btfss   PIR1,TMR2IF                     ;  espera desbordamiento en timer2
    goto    $-1
    banksel TRISIO                          ;  GPIO2 como salida
    bcf     TRISIO,2
;configurar ADC y LPF
    banksel ADCON0                          ;  ADC on, AN0 seleccionado, MSB a la izquierda, Vdd como Vref
    movlw   0x01                            ; 0x05 para adc1
    movwf   ADCON0
    call    Delay_4us                       ;  retardo de adquisición
    bsf     ADCON0,GO                       ;  inicia ciclo de ADC
    btfsc   ADCON0,GO                       ;  espera hasta que complete el ciclo
    goto    $-1                             ;  se desecha la primera lectura
    bsf     ADCON0,GO                       ;  inicia ciclo del ADC
    btfsc   ADCON0,GO                       ;  espera hasta que complete el ciclo
    goto    $-1
    movf    ADRESH,W                        ;  lee el MS byte del ADC
    movwf   ADC0_LPFReg1                    ;  inicializa los registros del LPF con el valor leído
    movwf   ADC0_LPFReg2
    movwf   ADC0_LPFReg3
    movwf   ADC0_LPFReg4
    movwf   ADC0_LPFReg5
    movwf   ADC0_LPFReg6
    movwf   ADC0_LPFReg7
    movwf   ADC0_LPFReg8
    movwf   ADC0_LPFReg9
    movwf   ADC0_LPFReg10
    movwf   ADC0_LPFReg11
    movwf   ADC0_LPFReg12
    movwf   ADC0_LPFReg13
    movwf   ADC0_LPFReg14
    movwf   ADC0_LPFReg15
    movwf   ADC0_LPFReg16
    clrf    ADC0_Accumulator_LO                  ;  inicializa el acumulador de LPF
    clrf    ADC0_Accumulator_HI
    movlw   0x05
    movwf   ADCON0
    call    Delay_4us                       ;  retardo de adquisición
    bsf     ADCON0,GO                       ;  inicia ciclo de ADC
    btfsc   ADCON0,GO                       ;  espera hasta que complete el ciclo
    goto    $-1
    movf    ADRESH,W                        ;  lee el MS byte del ADC
    movwf   ADC1_LPFReg1                    ;  inicializa los registros del LPF con el valor leído
    movwf   ADC1_LPFReg2
    movwf   ADC1_LPFReg3
    movwf   ADC1_LPFReg4
    movwf   ADC1_LPFReg5
    movwf   ADC1_LPFReg6
    movwf   ADC1_LPFReg7
    movwf   ADC1_LPFReg8
    movwf   ADC1_LPFReg9
    movwf   ADC1_LPFReg10
    movwf   ADC1_LPFReg11
    movwf   ADC1_LPFReg12
    movwf   ADC1_LPFReg13
    movwf   ADC1_LPFReg14
    movwf   ADC1_LPFReg15
    movwf   ADC1_LPFReg16
    clrf    ADC1_Accumulator_LO                  ;  inicializa el acumulador de LPF
    clrf    ADC1_Accumulator_HI
;configurar interrupciones
    movlw   0xA0                            ;  habilita interrupción por TIMER0
    movwf   INTCON
;configurar TIMER0
    banksel OPTION_REG                      ;  prescaler 256 a TIMER0 (interrupción cada ~32ms)
    movlw   0x87
    movwf   OPTION_REG
    banksel TMR0                            ;  precarga de TIMER0 e inicio
    movlw   0x00
    movwf   TMR0
;valores iniciales variables
    clrf    ALARM_STAT
    return

main                        ; main code
    banksel GPIO            ; lamp test & beep
    bsf     GPIO,4
    bsf     GPIO,5
    movlw   0x3F
    call    Set_Dutycycle
    call    Delay_250ms
    bcf     GPIO,4
    bcf     GPIO,5
    movlw   0x00
    call    Set_Dutycycle
    call    Delay_250ms             ; delay
    call    Delay_250ms
    call    Delay_250ms
    call    Delay_250ms
    movf    ADCON0,W                        ; fuel gauge
    andlw   0xF3
    movwf   ADCON0
    call    Delay_4us
    bsf     ADCON0,GO
    btfsc   ADCON0,GO
    goto    $-1
    call    Delay_4us
    movf    ADRESH,W
    movwf   Dutycycle_ADC0
    nop
    movf    Dutycycle_ADC0,W        ;v<=16%
    sublw   G_016
    btfsc   STATUS,C
    goto    $+0x1F
    movf    Dutycycle_ADC0,W        ;v<=33%
    sublw   G_033
    btfsc   STATUS,C
    goto    $+0x1F
    movf    Dutycycle_ADC0,W        ;v<=50%
    sublw   G_050
    btfsc   STATUS,C
    goto    $+0x1F
    movf    Dutycycle_ADC0,W        ;v<=66%
    sublw   G_066
    btfsc   STATUS,C
    goto    $+0x0E
    movf    Dutycycle_ADC0,W        ;v<=83%
    sublw   G_083
    btfsc   STATUS,C
    goto    $+6
    nop                             ;v>83%
    bsf     GPIO,5                  ;ggg
    call    Delay_250ms
    bcf     GPIO,5
    call    Delay_250ms
    bsf     GPIO,5                  ;gg
    call    Delay_250ms
    bcf     GPIO,5
    call    Delay_250ms
    bsf     GPIO,5                  ;g
    call    Delay_250ms
    bcf     GPIO,5
    call    Delay_250ms
    goto    $+0x0D
    bsf     GPIO,4                  ;rrr
    call    Delay_250ms
    bcf     GPIO,4
    call    Delay_250ms
    bsf     GPIO,4                  ;rr
    call    Delay_250ms
    bcf     GPIO,4
    call    Delay_250ms
    bsf     GPIO,4                  ;r
    call    Delay_250ms
    bcf     GPIO,4
    call    Delay_250ms
    call    Delay_250ms             ; delay
    call    Delay_250ms
    call    Delay_250ms
    call    Delay_250ms
    bcf     ALARM_STAT,0
loop
    btfss   ALARM_STAT,0
    goto    $+0x13
    clrw
    movf    ALARM_STAT,W        ;if ALARM_STAT,0 == HIGH -> print
    andlw   0x0E
    btfsc   STATUS,Z
    goto    $+3
    bsf     GPIO,4
    goto    $+2
    bsf     GPIO,5
    call    Delay_250ms
    bcf     GPIO,4
    bcf     GPIO,5
    btfsc   ALARM_STAT,1
    call    Alarm_VMin
    btfsc   ALARM_STAT,2
    call    Alarm_VMax
    btfsc   ALARM_STAT,3
    call    Alarm_TMax
    bcf     ALARM_STAT,0
    movlw   0x01
    andwf   ALARM_STAT,F
    call    LPF_ADC_Read
    movf    Dutycycle_ADC0,W        ;process read
    sublw   Max_Volt
    btfss   STATUS,C
    goto    $+0x0A
    movf    Dutycycle_ADC0,W
    sublw   Min_Volt
    btfsc   STATUS,C
    goto    $+8
    movf    Dutycycle_ADC1,W
    sublw   Max_Temp
    btfss   STATUS,C
    goto    $+6
    goto    loop
    bsf     ALARM_STAT,2        ;vmax
    goto    loop
    bsf     ALARM_STAT,1        ;vmin
    goto    loop
    bsf     ALARM_STAT,3       ;tmax
    goto    loop

Alarm_VMin
    movlw   0x1F
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x00
    call    Set_Dutycycle
    call    Delay_75ms
    banksel PR2
    movlw   0x45
    movwf   PR2
    banksel GPIO
    movlw   0x1F
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x00
    call    Set_Dutycycle
    call    Delay_75ms
    banksel PR2
    movlw   0x37
    movwf   PR2
    banksel GPIO
    movlw   0x1F
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x00
    call    Set_Dutycycle
    return

Alarm_VMax
    banksel PR2
    movlw   0x45
    movwf   PR2
    banksel GPIO
    movlw   0x1F
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x00
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x1F
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x00
    call    Set_Dutycycle
    call    Delay_75ms
    banksel PR2
    movlw   0x37
    movwf   PR2
    banksel GPIO
    movlw   0x1F
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x00
    call    Set_Dutycycle
    return

Alarm_TMax
    movlw   0x1F
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x00
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x1F
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x00
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x1F
    call    Set_Dutycycle
    call    Delay_75ms
    movlw   0x00
    call    Set_Dutycycle
    return

LPF_ADC_Read
;ADC0 - volts
    ;Desplazamiento de registros
    movlw   0x4C                            ;  desplaza los registros LPF
    movwf   FSR
    movf    INDF,W
    incf    FSR,F
    movwf   INDF
    btfss   FSR,6                           ;  es el ultimo desplazamiento?
    goto    $+4                             ;  si a acabado salta
    decf    FSR,F                           ;  si no direcciona el siguiente registro y vuelve al bucle
    decf    FSR,F
    goto    $-7
    ;Lectura del ADC
    movf    ADCON0,W                        ; ADC0
    andlw   0xF3
    movwf   ADCON0
    call    Delay_4us
    bsf     ADCON0,GO                       ;  inicia ciclo del ADC
    btfsc   ADCON0,GO                       ;  espera hasta que complete el ciclo
    goto    $-1
    call    Delay_4us
    movf    ADRESH,W                        ;  lee el MS byte del ADC
    movwf   ADC0_LPFReg1
    ;Cálculo del LPF
    movf    ADC0_LPFReg1,W                 ;  inicia el cálculo
    movwf   ADC0_Accumulator_LO                  ;  el acumulador es el sumatorio de los registros
    movlw   0x4E
    movwf   FSR
    decf    FSR,F
    movf    INDF,W
    addwf   ADC0_Accumulator_LO,F
    btfsc   STATUS,C                        ;  si el acumulador desborda, +1 al MSByte
    incf    ADC0_Accumulator_HI,F
    btfsc   FSR,6                           ;  comprueba si ha sumado todos los registros
    goto    $-6
    rrf     ADC0_Accumulator_LO,F                ;  división entre 16
    rrf     ADC0_Accumulator_LO,F
    rrf     ADC0_Accumulator_LO,F
    rrf     ADC0_Accumulator_LO,W
    andlw   0x0F
    movwf   ADC0_Accumulator_LO
    swapf   ADC0_Accumulator_HI,W
    andlw   0xF0
    iorwf   ADC0_Accumulator_LO,F
    movf    ADC0_Accumulator_LO,W
    movwf   Dutycycle_ADC0                   ;  mueve el resultado a la salida
    clrf    ADC0_Accumulator_LO                  ;  limpia los registros para la siguiente ejecución
    clrf    ADC0_Accumulator_HI
;ADC1 - temp
    ;Desplazamiento de registros
    movlw   0x6C                            ;  desplaza los registros LPF
    movwf   FSR
    movf    INDF,W
    incf    FSR,F
    movwf   INDF
    btfss   FSR,5                           ;  es el ultimo desplazamiento?
    goto    $+4                             ;  si a acabado salta
    decf    FSR,F                           ;  si no direcciona el siguiente registro y vuelve al bucle
    decf    FSR,F
    goto    $-7
    ;Lectura del ADC
    movf    ADCON0,W                        ; ADC1
    andlw   0xF3
    iorlw   0x04
    movwf   ADCON0
    call    Delay_4us
    bsf     ADCON0,GO                       ;  inicia ciclo del ADC
    btfsc   ADCON0,GO                       ;  espera hasta que complete el ciclo
    goto    $-1
    call    Delay_4us
    movf    ADRESH,W                        ;  lee el MS byte del ADC
    movwf   ADC1_LPFReg1
    ;Cálculo del LPF
    movf    ADC1_LPFReg1,W                 ;  inicia el cálculo
    movwf   ADC1_Accumulator_LO                  ;  el acumulador es el sumatorio de los registros
    movlw   0x6E
    movwf   FSR
    decf    FSR,F
    movf    INDF,W
    addwf   ADC1_Accumulator_LO,F
    btfsc   STATUS,C                        ;  si el acumulador desborda, +1 al MSByte
    incf    ADC1_Accumulator_HI,F
    btfsc   FSR,5                           ;  comprueba si ha sumado todos los registros
    goto    $-6
    rrf     ADC1_Accumulator_LO,F                ;  división entre 16
    rrf     ADC1_Accumulator_LO,F
    rrf     ADC1_Accumulator_LO,F
    rrf     ADC1_Accumulator_LO,W
    andlw   0x0F
    movwf   ADC1_Accumulator_LO
    swapf   ADC1_Accumulator_HI,W
    andlw   0xF0
    iorwf   ADC1_Accumulator_LO,F
    movf    ADC1_Accumulator_LO,W
    movwf   Dutycycle_ADC1                   ;  mueve el resultado a la salida
    clrf    ADC1_Accumulator_LO                  ;  limpia los registros para la siguiente ejecución
    clrf    ADC1_Accumulator_HI
    return

Set_Dutycycle
    movwf   Dutycycle_HI                    ;  se guarda en variable para el registro MS
    movwf   Dutycycle_LO                    ;  se guarda en variable para el registro LS
    rrf     Dutycycle_HI,F                  ;  procesamiento para ajustar al registro MS
    rrf     Dutycycle_HI,F
    movlw   0x3F
    andwf   Dutycycle_HI,F
    swapf   Dutycycle_LO,F                  ;  procesamiento para ajustar al registro LS
    movlw   0x30
    andwf   Dutycycle_LO,F
    movlw   0x0C                            ;  máscara de bits establecidos en setup
    iorwf   Dutycycle_LO,F
    movf    Dutycycle_HI,W                  ;  mueve el factor de servicio al registro MS
    movwf   CCPR1L
    movf    Dutycycle_LO,W                  ;  mueve el factor de servicio al registro LS
    movwf   CCP1CON
    return

Delay_4us
    goto    $+1
    goto    $+1
    return

Delay_75ms
	movlw	0x2E
	movwf	DLoop1
	movlw	0x76
	movwf	DLoop2
Delay_75ms_0
	decfsz	DLoop1, f
	goto	$+2
	decfsz	DLoop2, f
	goto	Delay_75ms_0
	goto	$+1
	nop
	return

Delay_250ms
	movlw	0x03
	movwf	DLoop1
	movlw	0x18
	movwf	DLoop2
	movlw	0x02
	movwf	DLoop3
Delay_250ms_0
	decfsz	DLoop1, f
	goto	$+2
	decfsz	DLoop2, f
	goto	$+2
	decfsz	DLoop3, f
	goto	Delay_250ms_0
	goto	$+1
	return

;------------------------------------------------------------------------------
;End of program
    END