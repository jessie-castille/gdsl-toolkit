val uarity-of insn = let
  val f a b = b
in
  traverse f insn
end

val mnemonic-of insn = let
  val f a b = a
in
  traverse f insn
end

val traverse-others f insn =
   case insn of
      PAUSE: f "PAUSE" (NULLOP)
   end

# -> sftl
type uarity =
   NULLOP
 | UNOP_SRC of unop-src
 | UNOP of unop
 | BINOP_SRC of binop-src
 | BINOP_FMT of binop-fmt
 | BINOP of binop
 | TERNOP_SRC of ternop-src
 | TERNOP of ternop
 | TERNOP_FMT of ternop-fmt
 | QUADOP of quadop
 | QUADOP_FMT of quadop-fmt
 | QUADOP_FMT_SRC of quadop-fmt-src


val traverse f insn = 
   case insn of
      ABS-fmt x: f "ABS.fmt" (BINOP_FMT x)
    | ADD x: f "ADD" (TERNOP x)
    | ADD-fmt x: f "ADD.fmt" (TERNOP_FMT x)
    | ADDI x: f "ADDI" (TERNOP x)
    | ADDIU x: f "ADDIU" (TERNOP x)
    | ADDU x: f "ADDU" (TERNOP x)
    | ALNV-PS x: f "ALNV.PS" (QUADOP x)
    | AND x: f "AND" (TERNOP x)
    | ANDI x: f "ANDI" (TERNOP x)
    | BC1F x: f "BC1F" (BINOP_SRC x)
    | BC1FL x: f "BC1FL" (BINOP_SRC x)
    | BC1T x: f "BC1T" (BINOP_SRC x)
    | BC1TL x: f "BC1TL" (BINOP_SRC x)
    | BC2F x: f "BC2F" (BINOP_SRC x)
    | BC2FL x: f "BC2FL" (BINOP_SRC x)
    | BC2T x: f "BC2T" (BINOP_SRC x)
    | BC2TL x: f "BC2TL" (BINOP_SRC x)
    | BEQ x: f "BEQ" (TERNOP_SRC x)
    | BEQL x: f "BEQL" (TERNOP_SRC x)
    | BGEZ x: f "BGEZ" (BINOP_SRC x)
    | BGEZAL x: f "BGEZAL" (BINOP_SRC x)
    | BGEZALL x: f "BGEZALL" (BINOP_SRC x)
    | BGEZL x: f "BGEZL" (BINOP_SRC x)
    | BGTZ x: f "BGTZ" (BINOP_SRC x)
    | BGTZL x: f "BGTZL" (BINOP_SRC x)
    | BLEZ x: f "BLEZ" (BINOP_SRC x)
    | BLEZL x: f "BLEZL" (BINOP_SRC x)
    | BLTZ x: f "BLTZ" (BINOP_SRC x)
    | BLTZAL x: f "BLTZAL" (BINOP_SRC x)
    | BLTZALL x: f "BLTZALL" (BINOP_SRC x)
    | BLTZL x: f "BLTZL" (BINOP_SRC x)
    | BNE x: f "BNE" (TERNOP_SRC x)
    | BNEL x: f "BNEL" (TERNOP_SRC x)
    | BREAK x: f "BREAK" (UNOP_SRC x)
    | C-cond-fmt x: f "C.cond.fmt" (QUADOP_FMT_SRC x)
    | CACHE x: f "CACHE" (TERNOP_SRC x)
    | CACHEE x: f "CACHEE" (TERNOP_SRC x)
    | CEIL-L-fmt x: f "CEIL.L.fmt" (BINOP_FMT x)
    | CEIL-W-fmt x: f "CEIL.W.fmt" (BINOP_FMT x)
    | CFC1 x: f "CFC1" (BINOP x)
    | CFC2 x: f "CFC2" (BINOP x)
    | CLO x: f "CLO" (TERNOP x)
    | CLZ x: f "CLZ" (TERNOP x)
    | COP2 x: f "COP2" (UNOP_SRC x)
    | CTC1 x: f "CTC1" (BINOP_SRC x)
    | CTC2 x: f "CTC2" (BINOP_SRC x)
    | CVT-D-fmt x: f "CVT.D.fmt" (BINOP_FMT x)
    | CVT-L-fmt x: f "CVT.L.fmt" (BINOP_FMT x)
    | CVT-PS-S x: f "CVT.PS.S" (TERNOP x)
    | CVT-S-fmt x: f "CVT.S.fmt" (BINOP_FMT x)
    | CVT-S-PL x: f "CVT.S.PL" (BINOP x)
    | CVT-S-PU x: f "CVT.S.PU" (BINOP x)
    | CVT-W-fmt x: f "CVT.W.fmt" (BINOP_FMT x)
    | DERET: f "DERET" (NULLOP)
    | DI x: f "DI" (UNOP x)
    | DIV x: f "DIV" (BINOP_SRC x)
    | DIV-fmt x: f "DIV.fmt" (TERNOP_FMT x)
    | DIVU x: f "DIVU" (BINOP_SRC x)
    | EI x: f "EI" (UNOP x)
    | ERET: f "ERET" (NULLOP)
    | EXT x: f "EXT" (QUADOP x)
    | FLOOR-L-fmt x: f "FLOOR.L.fmt" (BINOP_FMT x)
    | FLOOR-W-fmt x: f "FLOOR.W.fmt" (BINOP_FMT x)
    | INS x: f "INS" (QUADOP x)
    | J x: f "J" (UNOP_SRC x)
    | JAL x: f "JAL" (UNOP_SRC x)
    | JALR x: f "JALR" (TERNOP x)
    | JALR-HB x: f "JALR.HB" (TERNOP x)
    | JALX x: f "JALX" (UNOP_SRC x)
    | JR x: f "JR" (BINOP_SRC x)
    | JR-HB x: f "JR.HB" (BINOP_SRC x)
    | LB x: f "LB" (TERNOP x)
    | LBE x: f "LBE" (TERNOP x)
    | LBU x: f "LBU" (TERNOP x)
    | LBUE x: f "LBUE" (TERNOP x)
    | LDC1 x: f "LDC1" (TERNOP x)
    | LDC2 x: f "LDC2" (TERNOP_SRC x)
    | LDXC1 x: f "LDXC1" (TERNOP x)
    | LH x: f "LH" (TERNOP x)
    | LHE x: f "LHE" (TERNOP x)
    | LHU x: f "LHU" (TERNOP x)
    | LHUE x: f "LHUE" (TERNOP x)
    | LL x: f "LL" (TERNOP x)
    | LLE x: f "LLE" (TERNOP x)
    | LUI x: f "LUI" (BINOP x)
    | LUXC1 x: f "LUXC1" (TERNOP x)
    | LW x: f "LW" (TERNOP x)
    | LWC1 x: f "LWC1" (TERNOP x)
    | LWC2 x: f "LWC2" (TERNOP_SRC x)
    | LWE x: f "LWE" (TERNOP x)
    | LWL x: f "LWL" (TERNOP x)
    | LWLE x: f "LWLE" (TERNOP x)
    | LWR x: f "LWR" (TERNOP x)
    | LWRE x: f "LWRE" (TERNOP x)
    | LWXC1 x: f "LWXC1" (TERNOP x)
    | MADD x: f "MADD" (BINOP_SRC x)
    | MADD-fmt x: f "MADD.fmt" (QUADOP_FMT x)
    | MADDU x: f "MADDU" (BINOP_SRC x)
    | MFC0 x: f "MFC0" (TERNOP x)
    | MFC1 x: f "MFC1" (BINOP x)
    | MFC2 x: f "MFC2" (BINOP x)
    | MFHC1 x: f "MFHC1" (BINOP x)
    | MFHC2 x: f "MFHC2" (BINOP x)
    | MFHI x: f "MFHI" (UNOP x)
    | MFLO x: f "MFLO" (UNOP x)
    | MOV-fmt x: f "MOV.fmt" (BINOP_FMT x)
    | MOVF x: f "MOVF" (TERNOP x)
    | MOVF-fmt x: f "MOVF.fmt" (TERNOP_FMT x)
    | MOVN x: f "MOVN" (TERNOP x)
    | MOVN-fmt x: f "MOVN.fmt" (TERNOP_FMT x)
    | MOVT x: f "MOVT" (TERNOP x)
    | MOVT-fmt x: f "MOVT.fmt" (TERNOP_FMT x)
    | MOVZ x: f "MOVZ" (TERNOP x)
    | MOVZ-fmt x: f "MOVZ.fmt" (TERNOP_FMT x)
    | MSUB x: f "MSUB" (BINOP_SRC x)
    | MSUB-fmt x: f "MSUB.fmt" (QUADOP_FMT x)
    | MSUBU x: f "MSUBU" (BINOP_SRC x)
    | MTC0 x: f "MTC0" (TERNOP_SRC x)
    | MTC1 x: f "MTC1" (BINOP x)
    | MTC2 x: f "MTC2" (BINOP_SRC x)
    | MTHC1 x: f "MTHC1" (BINOP x)
    | MTHC2 x: f "MTHC2" (BINOP_SRC x)
    | MTHI x: f "MTHI" (UNOP_SRC x)
    | MTLO x: f "MTLO" (UNOP_SRC x)
    | MUL x: f "MUL" (TERNOP x)
    | MUL-fmt x: f "MUL.fmt" (TERNOP_FMT x)
    | MULT x: f "MULT" (BINOP_SRC x)
    | MULTU x: f "MULTU" (BINOP_SRC x)
    | NEG-fmt x: f "NEG.fmt" (BINOP_FMT x)
    | NMADD-fmt x: f "NMADD.fmt" (QUADOP_FMT x)
    | NMSUB-fmt x: f "NMSUB.fmt" (QUADOP_FMT x)
    | NOR x: f "NOR" (TERNOP x)
    | OR x: f "OR" (TERNOP x)
    | ORI x: f "ORI" (TERNOP x)
    | PLL-PS x: f "PLL.PS" (TERNOP x)
    | PLU-PS x: f "PLU.PS" (TERNOP x)
    | PREF x: f "PREF" (TERNOP_SRC x)
    | PREFE x: f "PREFE" (TERNOP_SRC x)
    | PREFX x: f "PREFX" (TERNOP_SRC x)
    | PUL-PS x: f "PUL.PS" (TERNOP x)
    | PUU-PS x: f "PUU.PS" (TERNOP x)
    | RDHWR x: f "RDHWR" (BINOP x)
    | RDPGPR x: f "RDPGPR" (BINOP x)
    | RECIP-fmt x: f "RECIP.fmt" (BINOP_FMT x)
    | ROTR x: f "ROTR" (TERNOP x)
    | ROTRV x: f "ROTRV" (TERNOP x)
    | ROUND-L-fmt x: f "ROUND.L.fmt" (BINOP_FMT x)
    | ROUND-W-fmt x: f "ROUND.W.fmt" (BINOP_FMT x)
    | RSQRT-fmt x: f "RSQRT.fmt" (BINOP_FMT x)
    | SB x: f "SB" (TERNOP_SRC x)
    | SBE x: f "SBE" (TERNOP_SRC x)
    | SC x: f "SC" (TERNOP x)
    | SCE x: f "SCE" (TERNOP x)
    | SDBBP x: f "SDBBP" (UNOP_SRC x)
    | SDC1 x: f "SDC1" (TERNOP_SRC x)
    | SDC2 x: f "SDC2" (TERNOP_SRC x)
    | SDXC1 x: f "SDXC1" (TERNOP_SRC x)
    | SEB x: f "SEB" (BINOP x)
    | SEH x: f "SEH" (BINOP x)
    | SH x: f "SH" (TERNOP_SRC x)
    | SHE x: f "SHE" (TERNOP_SRC x)
    | SLL x: f "SLL" (TERNOP x)
    | SLLV x: f "SLLV" (TERNOP x)
    | SLT x: f "SLT" (TERNOP x)
    | SLTI x: f "SLTI" (TERNOP x)
    | SLTIU x: f "SLTIU" (TERNOP x)
    | SLTU x: f "SLTU" (TERNOP x)
    | SQRT-fmt x: f "SQRT.fmt" (BINOP_FMT x)
    | SRA x: f "SRA" (TERNOP x)
    | SRAV x: f "SRAV" (TERNOP x)
    | SRL x: f "SRL" (TERNOP x)
    | SRLV x: f "SRLV" (TERNOP x)
    | SUB x: f "SUB" (TERNOP x)
    | SUB-fmt x: f "SUB.fmt" (TERNOP_FMT x)
    | SUBU x: f "SUBU" (TERNOP x)
    | SUXC1 x: f "SUXC1" (TERNOP_SRC x)
    | SW x: f "SW" (TERNOP_SRC x)
    | SWC1 x: f "SWC1" (TERNOP_SRC x)
    | SWC2 x: f "SWC2" (TERNOP_SRC x)
    | SWE x: f "SWE" (TERNOP_SRC x)
    | SWL x: f "SWL" (TERNOP_SRC x)
    | SWLE x: f "SWLE" (TERNOP_SRC x)
    | SWR x: f "SWR" (TERNOP_SRC x)
    | SWRE x: f "SWRE" (TERNOP_SRC x)
    | SWXC1 x: f "SWXC1" (TERNOP_SRC x)
    | SYNC x: f "SYNC" (UNOP_SRC x)
    | SYNCI x: f "SYNCI" (BINOP_SRC x)
    | SYSCALL x: f "SYSCALL" (UNOP_SRC x)
    | TEQ x: f "TEQ" (TERNOP_SRC x)
    | TEQI x: f "TEQI" (BINOP_SRC x)
    | TGE x: f "TGE" (TERNOP_SRC x)
    | TGEI x: f "TGEI" (BINOP_SRC x)
    | TGEIU x: f "TGEIU" (BINOP_SRC x)
    | TGEU x: f "TGEU" (TERNOP_SRC x)
    | TLBINV: f "TLBINV" (NULLOP)
    | TLBINVF: f "TLBINVF" (NULLOP)
    | TLBP: f "TLBP" (NULLOP)
    | TLBR: f "TLBR" (NULLOP)
    | TLBWI: f "TLBWI" (NULLOP)
    | TLBWR: f "TLBWR" (NULLOP)
    | TLT x: f "TLT" (TERNOP_SRC x)
    | TLTI x: f "TLTI" (BINOP_SRC x)
    | TLTIU x: f "TLTIU" (BINOP_SRC x)
    | TLTU x: f "TLTU" (TERNOP_SRC x)
    | TNE x: f "TNE" (TERNOP_SRC x)
    | TNEI x: f "TNEI" (BINOP_SRC x)
    | TRUNC-L-fmt x: f "TRUNC.L.fmt" (BINOP_FMT x)
    | TRUNC-W-fmt x: f "TRUNC.W.fmt" (BINOP_FMT x)
    | WAIT x: f "WAIT" (UNOP_SRC x)
    | WRPGPR x: f "WRPGPR" (BINOP_SRC x)
    | WSBH x: f "WSBH" (BINOP x)
    | XOR x: f "XOR" (TERNOP x)
    | XORI x: f "XORI" (TERNOP x)
    | _: traverse-others f insn
   end


# <- sutl

