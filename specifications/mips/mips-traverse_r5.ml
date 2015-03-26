val revision/traverse f insn = 
   case insn of
      ADDI x: f "ADDI" (TERNOP_LRR x)
    | ALNV-PS x: f "ALNV.PS" (QUADOP_LRRR x)
    | BC1F x: f "BC1F" (BINOP_RR x)
    | BC1FL x: f "BC1FL" (BINOP_RR x)
    | BC1T x: f "BC1T" (BINOP_RR x)
    | BC1TL x: f "BC1TL" (BINOP_RR x)
    | BC2F x: f "BC2F" (BINOP_RR x)
    | BC2FL x: f "BC2FL" (BINOP_RR x)
    | BC2T x: f "BC2T" (BINOP_RR x)
    | BC2TL x: f "BC2TL" (BINOP_RR x)
    | BEQL x: f "BEQL" (TERNOP_RRR x)
    | BGEZAL x: f "BGEZAL" (BINOP_RR x)
    | BGEZALL x: f "BGEZALL" (BINOP_RR x)
    | BGEZL x: f "BGEZL" (BINOP_RR x)
    | BGTZL x: f "BGTZL" (BINOP_RR x)
    | BLEZL x: f "BLEZL" (BINOP_RR x)
    | BLTZAL x: f "BLTZAL" (BINOP_RR x)
    | BLTZALL x: f "BLTZALL" (BINOP_RR x)
    | BLTZL x: f "BLTZL" (BINOP_RR x)
    | BNEL x: f "BNEL" (TERNOP_RRR x)
    | LDC2 x: f "LDC2" (BINOP_RR x)
    | LWC2 x: f "LWC2" (BINOP_RR x)
    | LWL x: f "LWL" (BINOP_LR x)
    | LWLE x: f "LWLE" (BINOP_LR x)
    | LWR x: f "LWR" (BINOP_LR x)
    | LWRE x: f "LWRE" (BINOP_LR x)
    | LWXC1 x: f "LWXC1" (BINOP_LR x)
    | SDC2 x: f "SDC2" (BINOP_RR x)
   end
