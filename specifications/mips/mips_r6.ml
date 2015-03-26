####################################################################
###                    DECODER FOR REVISION 6                    ###
####################################################################

######################
# guard conditions
####

val lui? s = (s.rs == '00000')
val bgtz? s = (s.rt == '00000')
val bgtzalc? s = (s.rs == '00000') and (not (s.rt == '00000'))
val bgezalc? s = (s.rs == s.rt) and (not (s.rs == '00000')) 
val blez? s = (s.rt == '00000')
val blezalc? s = (s.rs == '00000') and (not (s.rt == '00000'))
val bltzalc? s = (s.rs == s.rt) and (not (s.rs == '00000'))
val beqzalc? s = ((zx s.rs) < (zx s.rt)) and (s.rs == '00000') and (not (s.rt == '00000'))
val bnezalc? s = ((zx s.rs) < (zx s.rt)) and (s.rs == '00000') and (not (s.rt == '00000'))
val blezc? s = (s.rs == '00000') and (not (s.rt == '00000')) 
val bgezc? s = (s.rs == s.rt) and (not (s.rs == '00000')) and (not (s.rt == '00000'))
val bgec? s = (not (s.rs == s.rt)) and (not (s.rs == '00000')) and (not (s.rt == '00000'))
val bgtzc? s = (s.rs == '00000') and (not (s.rt == '00000')) 
val bltzc? s = (s.rs == s.rt) and (not (s.rs == '00000')) and (not (s.rt == '00000'))
val bltc? s = (not (s.rs == s.rt)) and (not (s.rs == '00000')) and (not (s.rt == '00000'))
val bgeuc? s = (not (s.rs == s.rt)) and (not (s.rs == '00000')) and (not (s.rt == '00000'))
val bltuc? s = (not (s.rs == s.rt)) and (not (s.rs == '00000')) and (not (s.rt == '00000'))
val beqc? s = ((zx s.rs) < (zx s.rt)) and (not (s.rs == '00000')) and (not (s.rt == '00000'))
val bnec? s = ((zx s.rs) < (zx s.rt)) and (not (s.rs == '00000')) and (not (s.rt == '00000'))
val beqzc? s = not (s.rs == '00000')
val bnezc? s = not (s.rs == '00000')


######################
# decoder rules
####

### ABS-fmt
###  - Floating Point Absolute Value
val / ['010001 /fmt5sd 00000 /fs /fd 000101'] = binop-fmt ABS-fmt fmt fd (right fs) 

### ADD-fmt
###  - Floating Point Add
val / ['010001 /fmt5sd /ft /fs /fd 000000'] = ternop-fmt ADD-fmt fmt fd (right fs) (right ft) 

### ADDIUPC
###  - Add Immediate to PC (unsigned - non-trapping)
val / ['111011 /rs 00 /immediate19'] = binop ADDIUPC rs immediate21

### ALIGN
###  - Concatenate two GPRs, and extract a contiguous subset at a byte position
val / ['011111 /rs /rt /rd 010 /bp 100000'] = quadop ALIGN rd (right rs) (right rt) bp

### ALUIPC
###  - Aligned Add Upper Immediate to PC
val / ['111011 /rs 11111 /immediate16'] = binop ALUIPC rs immediate32

### AUI
###  - Add Immediate to Upper Bits
val / ['001111 /rs /rt /immediate16']
 | lui? = binop LUI rt immediate16
 | otherwise = ternop AUI rt (right rs) immediate32

### AUIPC
###  - Add Upper Immediate to PC
val / ['111011 /rs 11110 /immediate16'] = binop AUIPC rs immediate32

### BALC
###  - Branch and Link, Compact
val / ['111010 /offset26'] = unop BALC offset28

### BC
###  - Branch, Compact
val / ['110010 /offset26'] = unop BC offset28

### BC1EQZ
###  - Branch if Coprocessor 1 (FPU) Register Bit 0 Equal to Zero
val / ['010001 01001 /ft /offset16'] = binop BC1EQZ (right ft) offset18

### BC1NEZ
###  - Branch if Coprocessor 1 (FPU) Register Bit 0 Not Equal to Zero
val / ['010001 01101 /ft /offset16'] = binop BC1NEZ (right ft) offset18

### BC2EQZ
###  - Branch if Coprocessor 2 Condition (Register) Equal to Zero
val / ['010010 01001 /ct /offset16'] = binop BC2EQZ ct offset18

### BC2NEZ
###  - Branch if Coprocessor 2 Condition (Register) Not Equal to Zero
val / ['010010 01101 /ct /offset16'] = binop BC2NEZ ct offset18

### BGTZ
###  - Branch on Greater Than Zero
###  => see BLTUC

### BLEZ
###  - Branch on Less Than or Equal to Zero
###  => see BGEUC

### B{LE,GE,GT,LT,EQ,NE}ZALC
###  - Compact zero-compare and branch-and-link instructions
###    BLEZALC
###  => see BGEUC

###    BGEZALC
###  => see BGEUC

###    BGTZALC
###  => see BLTTUC

###    BLTZALC
###  => see BLTTUC

###    BEQZALC
###  => see BEQC

###    BNEZALC
###  => see BNEC

### B<cond>C
###  - Compact compare-and-branch instructions
###    BGEC (BLEZ)
val / ['010110 /rs /rt /offset16']
 | blezc? = binop BLEZC (right rt) offset18
 | bgezc? = binop BGEZC (right rt) offset18
 | bgec? = ternop BGEC (right rs) (right rt) offset18

###    BLTC (BGTC)
val / ['010111 /rs /rt /offset16']
 | bgtzc? = binop BGTZC (right rt) offset18
 | bltzc? = binop BLTZC (right rt) offset18
 | bltc? = ternop BLTC (right rs) (right rt) offset18

###    BGEUC (BLEUC)
val / ['000110 /rs /rt /offset16']
 | blez?    = binop BLEZ (right rs) offset18
 | blezalc? = binop BLEZALC (right rt) offset18
 | bgezalc? = binop BGEZALC (right rt) offset18
 | bgeuc?   = ternop BGEUC (right rs) (right rt) offset18

###    BLTUC (BGTUC)
val / ['000111 /rs /rt /offset16']
 | bgtz?    = binop BGTZ (right rs) offset18
 | bgtzalc? = binop BGTZALC (right rt) offset18
 | bltzalc? = binop BLTZALC (right rt) offset18
 | bltuc?   = ternop BLTUC (right rs) (right rt) offset18

###    BEQC
val / ['001000 /rs /rt /offset16']
 | beqzalc? = binop BEQZALC (right rt) offset18
 | beqc? = ternop BEQC (right rs) (right rt) offset18

###    BNEC
val / ['011000 /rs /rt /offset16']
 | bnezalc? = binop BNEZALC (right rt) offset18
 | bnec? = ternop BNEC (right rs) (right rt) offset18

###    BEQZC
val / ['110110 /rs /offset21']
 | beqzc? = binop BEQZC (right rs) offset23

###    BNEZC
val / ['111110 /rs /offset21']
 | bnezc? = binop BNEZC (right rs) offset23

### LUI
###  - Load Upper Immediate
###  => see AUI r0, rt, immediate16


type instruction = 
   ADDIUPC of binop-lr
 | ALIGN of quadop-lrrr
 | ALUIPC of binop-lr
 | AUI of ternop-lrr
 | AUIPC of binop-lr
 | BALC of unop-r
 | BC of unop-r
 | BC1EQZ of binop-rr
 | BC1NEZ of binop-rr
 | BC2EQZ of binop-rr
 | BC2NEZ of binop-rr
 | BLEZALC of binop-rr
 | BGEZALC of binop-rr
 | BGTZALC of binop-rr
 | BLTZALC of binop-rr
 | BEQZALC of binop-rr
 | BNEZALC of binop-rr
 | BLEZC of binop-rr
 | BGEZC of binop-rr
 | BGEC of ternop-rrr
 | BGTZC of binop-rr
 | BLTZC of binop-rr
 | BLTC of ternop-rrr
 | BGEUC of ternop-rrr
 | BLTUC of ternop-rrr
 | BEQC of ternop-rrr
 | BNEC of ternop-rrr
 | BEQZC of binop-rr
 | BNEZC of binop-rr

type imm =
   IMM21 of 21
 | IMM32 of 32
 | BP of 2
 | OFFSET23 of 23
 | OFFSET28 of 28
 | C2CONDITION of 5


###########################
# operand decoders
####

val /immediate19 ['immediate19:19'] = update@{immediate19=immediate19}
val /offset21 ['offset21:21'] = update@{offset21=offset21}
val /offset26 ['offset26:26'] = update@{offset26=offset26}
val /bp ['bp:2'] = update@{bp=bp}
val /ct ['ct:5'] = update@{ct=ct}

###########################
# operand constructors
####

val immediate21 = do
  immediate19 <- query $immediate19;
  return (IMM (IMM21 (immediate19 ^ '00')))
end

val immediate32 = do
  immediate16 <- query $immediate16;
  return (IMM (IMM32 (immediate16 ^ '0000000000000000')))
end

val offset23 = do
  offset21 <- query $offset21;
  return (IMM (OFFSET23 (offset21 ^ '00')))
end

val offset28 = do
  offset26 <- query $offset26;
  return (IMM (OFFSET28 (offset26 ^ '00')))
end

val bp = do
  bp <- query $bp;
  return (IMM (BP bp))
end

val ct = do
  ct <- query $ct;
  return (IMM (C2CONDITION ct))
end


#################################
# to be removed ;)

type format = 
   PS


val /fmt5sdps ['10 /fmt3sdps'] = return void
val /fmt3sdps [/fmt3sd] = return void
val /fmt3sdps ['110'] = update@{fmt=PS}
