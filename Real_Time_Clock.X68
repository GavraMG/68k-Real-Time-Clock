*-----------------------------------------------------------
* Title      : HARDWARE CLOCK 
* Written by : Markus Gavra
* Date       : November 28, 2024
* Description: Built a working 24-hour clock using Assembly
*
* I have exclusive control over this submission via my password.
* By including this statement in this header, I certify that
* I have read and understood the University policy in academic
* integrity and I assert that this work is my own. I have
* not used any unapproved external resources including LLM
* models. Furthermore, I certify that is assignment was
* prepared by me specifically for this course.
*-----------------------------------------------------------
    ORG    $1000

; Hardware Setup
HARDWARE    EQU     $E00000             ; Base address of hardware devices
DIGIT1      EQU     14                  ; Hours tens (leftmost digit)
DIGIT2      EQU     12                  ; Hours units
DIGIT3      EQU     10                  ; Dash between hours and minutes
DIGIT4      EQU     8                   ; Minutes tens
DIGIT5      EQU     6                   ; Minutes units
DIGIT6      EQU     4                   ; Dash between minutes and seconds
DIGIT7      EQU     2                   ; Seconds tens
DIGIT8      EQU     0                   ; Seconds units (rightmost digit)
DASH        EQU     $40                 ; 7-segment code for '-'

START:           
            ; Place address of the level-6 ISR into the vector table
            MOVE.L  #ISR6,$78           ; Set vector for interrupt level 6
            MOVE.L  #ISR7,$7C           ; Set vector for interrupt level 7

            
            ; Initialize variables
            MOVE.W  #40,COUNTER         ; Set COUNTER to 40 (aligns better with real clock time)
            CLR.W   SECONDS             ; Clear SECONDS
            CLR.W   SECONDS_TENS        ; Clear SECONDS_TENS
            CLR.W   MINUTES             ; Clear MINUTES
            CLR.W   MINUTES_TENS        ; Clear MINUTES_TENS
            CLR.W   HOURS               ; Clear HOURS
            CLR.W   HOURS_TENS          ; Clear HOURS_TENS
            CLR.W   FLAG                ; Clear FLAG
            
            ; Display hardware window from software
            MOVE.L  #32,D0              ; Task number 32
            CLR.B   D1                  ; Parameter: display window
            TRAP    #15                 ; Calls trap 15
            
            ; Start polling loop
            BRA POLLING_LOOP  
         
POLLING_LOOP:
            MOVEA.L #HARDWARE, A0       ; Base address of hardware

POLL_LOOP:
        TST.W   FLAG                    ; Check if interrupt flag is set
        BEQ     POLL_LOOP               ; If not set, keep polling

        ; Clear the interrupt flag
        CLR.W   FLAG                    ; Acknowledge the interrupt

        ; Decrement COUNTER
        SUBI.W  #1, COUNTER             ; COUNTER = COUNTER - 1
        TST.W   COUNTER                 ; Check if COUNTER is 0
        BNE     DISPLAY_TIME            ; If not zero, display time
        MOVE.W  #40, COUNTER            ; Reset COUNTER to 40 (aligns better with real clock time)

        ; Update SECONDS
        ADDI.W  #1, SECONDS             ; SECONDS = SECONDS + 1
        CMP.W   #60, SECONDS            ; Compares seconds to 60 make sure it doesn't go over 
        BLO     DISPLAY_TIME            ; If SECONDS < 60, display time

        ; Reset SECONDS to 0 and increment MINUTES
        CLR.W   SECONDS                 ; Reset SECONDS to 0
        ADDI.W  #1, MINUTES             ; MINUTES = MINUTES + 1
        CMP.W   #60, MINUTES            ; Compares minutes to 60 to make sure it doesn't go over 
        BLO     DISPLAY_TIME            ; If MINUTES < 60, display time

        ; Reset MINUTES to 0 and increment HOURS
        CLR.W   MINUTES                 ; Reset MINUTES to 0
        ADDI.W  #1, HOURS               ; HOURS = HOURS + 1
        CMP.W   #24, HOURS              ; Compares hours to 24 to make sure it doesn't go over
        BLO     DISPLAY_TIME            ; If HOURS < 24, display time

        ; Reset HOURS to 0
        CLR.W   HOURS                   ; Reset HOURS to 0
            
DISPLAY_TIME:
            ; Display SECONDS on hardware using 7-segment table
            MOVEA.L #HARDWARE, A0       ; Base address of hardware
            MOVEA.L #CONVERT, A1        ; Address of conversion table

            ; ------------ SECONDS LOGIC ------------
            ; Check and update tens digit if needed
            MOVE.W  SECONDS, D0         ; Get seconds value
            CMP.W   #10, D0              ; Compare seconds units with 9
            BNE     DISPLAY_SECONDS     ; If not 9, skip tens digit increment
         
            ; Increment tens digit
            ADDI.W  #1, SECONDS_TENS    ; Add 1 to the tens digit
            CLR.W   SECONDS             ; Reset seconds' units to 0

            ; Check if seconds tens reached 6 (60 seconds)
            CMP.W   #6, SECONDS_TENS    ; Compare tens digit with 6
            BNE     DISPLAY_SECONDS     ; If less than 6, skip reset

            ; Increment mintues units and reset seconds
            ADDI.W  #1,MINUTES          ; Increment minutes units
            CLR.W   SECONDS             ; Reset seconds units to 0
            CLR.W   SECONDS_TENS        ; Reset seconds tens to 0

            ; ------------ MINTUES LOGIC ------------
            MOVE.W  MINUTES, D0         ; Get minutes units
            CMP.W   #10, D0             ; Compare with 10
            BNE     DISPLAY_MINUTES     ; If less than 10, skip tens update
            
            ; Increment minutes tens digit
            ADDI.W  #1, MINUTES_TENS    ; Increment minutes tens
            CLR.W   MINUTES             ; Reset minutes units to 0

            ; Check if minutes tens reached 6 (60 minutes)
            CMP.W   #6, MINUTES_TENS    ; Compare tens digit with 6
            BNE     DISPLAY_MINUTES     ; If less than 6, skip hours update

            ; Increment hours units and reset minutes
            ADDI.W  #1, HOURS           ; Increment hours' units
            CLR.W   MINUTES             ; Reset minutes units
            CLR.W   MINUTES_TENS        ; Reset minutes tens

            ; ------------ HOURS LOGIC ------------
            MOVE.W  HOURS, D0           ; Get minutes' units
            CMP.W   #10, D0             ; Compare with 10
            BNE     DISPLAY_HOURS       ; If less than 10, skip tens update
            
            ; Increment hour tens digit
            ADDI.W  #1, HOURS_TENS      ; Increment hours tens
            CLR.W   HOURS               ; Reset minutes' units to 0

            ; Check if hours tens reached 24 (24 hours)
            CMP.W   #24, HOURS_TENS     ; Compare tens digit with 6
            BNE     DISPLAY_HOURS       ; If less than 24, skip hours update

            ; Reset Hours
            CLR.W   HOURS               ; Reset hours units
            CLR.W   HOURS_TENS          ; Reset hours tens


DISPLAY_SECONDS:
            ; Display seconds units digit (DIGIT1)
            MOVE.W  SECONDS, D0         ; Get seconds value
            AND.W   #$000F, D0          ; Extract units digit (0-9)
            MOVE.B  (A1, D0.W),D1       ; Convert to 7-segment value
            MOVE.B  D1, DIGIT1(A0)      ; Write to hardware digit 1

            ; Display seconds tens digit (DIGIT2)
            MOVE.W  SECONDS_TENS, D0    ; Get tens digit
            AND.W   #$000F, D0          ; Mask to ensure it's in range 0-9
            MOVE.B  (A1, D0.W),D1       ; Convert to 7-segment value
            MOVE.B  D1, DIGIT2(A0)      ; Write to hardware digit 2
            
            ; Display dash (DIGIT3)
            MOVE.B  #DASH, DIGIT3(A0)   ; Dash between hours and minutes

DISPLAY_MINUTES:
            ; Display minutes units digit (DIGIT4)
            MOVE.W  MINUTES, D0         ; Get seconds value
            AND.W   #$000F, D0          ; Extract units digit (0-9)
            MOVE.B  (A1, D0.W),D1       ; Convert to 7-segment value
            MOVE.B  D1, DIGIT4(A0)      ; Write to hardware digit 1

            ; Display minutes tens digit (DIGIT5)
            MOVE.W  MINUTES_TENS, D0    ; Get tens digit
            AND.W   #$000F, D0          ; Mask to ensure it's in range 0-9
            MOVE.B  (A1, D0.W),D1       ; Convert to 7-segment value
            MOVE.B  D1, DIGIT5(A0)      ; Write to hardware digit 2
            
            ; Display dash (DIGIT6)
            MOVE.B  #DASH, DIGIT6(A0)   ; Dash between hours and minutes

DISPLAY_HOURS:
            ; Display hours units digit (DIGIT7)
            MOVE.W  HOURS, D0           ; Get seconds value
            AND.W   #$000F, D0          ; Extract units digit (0-9)
            MOVE.B  (A1, D0.W),D1       ; Convert to 7-segment value
            MOVE.B  D1, DIGIT7(A0)      ; Write to hardware digit 1

            ; Display hours tens digit (DIGIT8)
            MOVE.W  HOURS_TENS, D0      ; Get tens digit
            AND.W   #$000F, D0          ; Mask to ensure it's in range 0-9
            MOVE.B  (A1, D0.W),D1       ; Convert to 7-segment value
            MOVE.B  D1, DIGIT8(A0)      ; Write to hardware digit 2

            BRA     POLL_LOOP           ; Loop again

; Interrupt service routine for level-6 auto-vector interrupt
ISR6:
            ORI.W   #$0700, SR          ; Set priority level to 7
            MOVEM.L D0-D1/A0, -(A7)     ; Save working registers
            MOVE.W  #1, FLAG            ; Set the flag to indicate interrupt
            MOVEM.L (A7)+, D0-D1/A0     ; Restore working registers
            ANDI.W  #$F8FF, SR          ; Restore priority level
            RTE                         ; Return from interrupt
            
; ISR7: Interrupt Service Routine for level-7 auto-vector interrupt
ISR7:           
                ORI.W   #$0700,SR           ; Set priority level to 7
                MOVEM.L A1/D0,-(A7)         ; Save working registers
                MOVE.W  #1, FLAG            ; Set the interrupt flag
                JSR     RESET_CLOCK         ; Call display subroutine for ISR7
                MOVEM.L (A7)+,A1/D0         ; Restore working registers
                RTE 
                
RESET_CLOCK:
                CLR.W   SECONDS             ; Clear SECONDS
                CLR.W   SECONDS_TENS        ; Clear SECONDS_TENS
                CLR.W   MINUTES             ; Clear MINUTES
                CLR.W   MINUTES_TENS        ; Clear MINUTES_TENS
                CLR.W   HOURS               ; Clear HOURS
                CLR.W   HOURS_TENS          ; Clear HOURS_TENS
                CLR.W   FLAG                ; Clear FLAG
                RTS
                

            SIMHALT                     ; Halt simulator
    
*-----------------------------------------------------------
* Data Definitions
*-----------------------------------------------------------

                ORG     $9000              
; Variables
COUNTER:        DC.W    40                 ; Counter initialized to 40 (aligns better with real clock time)
SECONDS:        DC.W    0                  ; SECONDS variable
SECONDS_TENS:   DC.W    0                  ; Variable to track tens digit of seconds
MINUTES:        DC.W    0                  ; MINUTES variable
MINUTES_TENS:   DC.W    0                  ; Variable to track tens digit of minutes
HOURS:          DC.W    0                  ; HOURS variable
HOURS_TENS:     DC.W    0                  ; Variable to track tens digit of hours
FLAG:           DC.W    0                  ; Synchronization flag

; 9-Segment LED patterns for digits 0-9
CONVERT     DC.B    $3F, $06, $5B, $4F, $66, $6D, $7D, $07, $7F, $6F

              END     START                ; Ends the program

*~Font name~Courier New~
*~Font size~10~
*~Tab type~1~
*~Tab size~4~
