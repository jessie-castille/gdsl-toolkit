# vim:filetype=sml:ts=3:sw=3:expandtab

export = translate translateBlock translateSuperBlock

type sem_writeback =
   SEM_WRITE_VAR of {size:int, id:sem_var}
 | SEM_WRITE_MEM of {size:int, address:sem_linear, segment:seg_override}

#Todo: fix
val runtime-stack-address-size = do
  mode64 <- mode64?;
  if mode64 then
    return 64
  else
    return 32
end

val ip-get = do
  return (var (semantic-register-of RIP))
#  k <- ipget;
#  return (imm k)
end

val segment-register? x =
  case x of
     CS: '1'
   | SS: '1'
   | DS: '1'
   | ES: '1'
   | FS: '1'
   | GS: '1'
   | _ : '0'
  end

val sizeof2 dst/src1 src2 =
   case dst/src1 of
      REG r: return ($size (semantic-register-of r))
    | MEM x: return x.sz
    | _:
         case src2 of
            REG r: return ($size (semantic-register-of r))
          | MEM x: return x.sz
         end
   end

val sizeof-flow target =
  case target of
     REL8 x: return 8
   | REL16 x: return 16
   | REL32 x: return 32
   | REL64 x: return 64
   | NEARABS x: sizeof1 x
   | FARABS x: sizeof1 x
  end

val sizeof1 op =
   case op of
      REG r: return (semantic-register-of r).size
    | MEM x: return x.sz
    | IMM8 i: return 8
    | IMM16 i: return 16
    | IMM32 i: return 32
    | IMM64 i: return 64
   end

type signedness =
   Signed
 | Unsigned

val expand dst-getter conv lin from-sz to-sz =
  if from-sz === to-sz then
    return lin
  else do
    expanded <- dst-getter;
    case conv of
       Signed: movsx to-sz expanded from-sz lin
     | Unsigned: movzx to-sz expanded from-sz lin
    end;
    return (var expanded)
  end

val segment-add mode64 address segment = let
  val seg-sem seg-reg = SEM_LIN_VAR(semantic-register-of seg-reg)
in
  case segment of
     SEG_NONE:
       if mode64 then
         address
       else
         SEM_LIN_ADD {opnd1=seg-sem DS,opnd2=address}
   | SEG_OVERRIDE s:
       if mode64 then
         case s of
            FS: SEM_LIN_ADD {opnd1=seg-sem s,opnd2=address}
  	  | GS: SEM_LIN_ADD {opnd1=seg-sem s,opnd2=address}
	  | _: address
	 end
       else
         SEM_LIN_ADD {opnd1=seg-sem s,opnd2=address}
  end
end

#IA-32e => 64 bit real addresses
val real-addr-sz = return 64

val segmented-lin lin sz segment = do
  real-addr-sz <- real-addr-sz;
  mode64 <- mode64?;

  expanded <- expand mktemp Unsigned lin sz real-addr-sz;
  return (segment-add mode64 expanded segment)
end
val segmented-reg reg segment = segmented-lin (var reg) reg.size segment

val segmented-load dst-sz dst addr-sz address segment = do
  address-segmented <- segmented-lin address addr-sz segment;
  addr-sz <- real-addr-sz;
  load dst-sz dst addr-sz address-segmented
end

val segmented-store addr rhs segment = do
  address-segmented <- segmented-lin addr.address addr.size segment;
  addr-sz <- real-addr-sz;
  store (address addr-sz address-segmented) rhs
end

#val segment segment = do
#  mode64 <- mode64?;
#  if mode64 then
#    case segment of
#       SEG_NONE: return 
#
#    case segment of
#       FS: return segment
#     | GS: return segment
#     | _: return DS
#    end
#  else
#    return segment
#  return DS
#end

val conv-with conv sz x =
   let
      val conv-imm conv x = case conv of
                               Signed: return (SEM_LIN_IMM{imm=sx x})
                             | Unsigned: return (SEM_LIN_IMM{imm=zx x})
      end

      val conv-reg conv sz r = do
        reg <- return (semantic-register-of r);
	expanded <- expand mktemp conv (var reg) reg.size sz;
	return expanded
      end

      val conv-sum conv sz x =
         do op1 <- conv-with conv sz x.a;
            op2 <- conv-with conv sz x.b;
            return
               (SEM_LIN_ADD
                  {opnd1=op1,
                   opnd2=op2})
         end

      val conv-scale conv sz x =
         do op <- conv-with conv sz x.opnd;
            return
               (SEM_LIN_SCALE
                  {opnd=op,
                   imm=
                     case $imm x of
                        '00': 1
                      | '01': 2
                      | '10': 4
                      | '11': 8
                     end})
         end

      val conv-mem x = conv-with Signed x.psz x.opnd
   in
      case x of
         IMM8 x: conv-imm conv x.imm
       | IMM16 x: conv-imm conv x.imm
       | IMM32 x: conv-imm conv x.imm
       | IMM64 x: conv-imm conv x.imm
       | REG x: conv-reg conv sz x
       | SUM x: conv-sum conv sz x
       | SCALE x: conv-scale conv sz x
       | MEM x:
           let
	     val m expanded = do
               address <- conv-mem x;
               segmented-load x.sz expanded x.psz address x.segment;
               expanded <- expand (return expanded) conv (var expanded) x.sz sz;
	       return expanded
	     end
	   in do
             #address <- conv-mem x;
	     address <- return (conv-mem x);

	     expanded <- mktemp;
	     expanded <- with-subscope (m expanded);
	     return expanded
           end end
      end
   end

val read sz x = conv-with Unsigned sz x
val reads conv sz x = conv-with conv sz x

val extract-imm-unsigned imm =
  case imm of
     IMM8 x: zx x.imm
   | IMM16 x: zx x.imm
   | IMM32 x: zx x.imm
   | IMM64 x: zx x.imm
 end

val read-addr-reg x =
  case x of
     MEM m:
       case m.opnd of
          REG r: r
       end
  end

val read-flow sz x =
   let
      val conv-bv v = return (SEM_LIN_IMM{imm=sx v})
   in
      case x of
         REL8 x: conv-bv x
       | REL16 x: conv-bv x
       | REL32 x: conv-bv x
       | REL64 x: conv-bv x
       | NEARABS x: read sz x
       | FARABS x: read sz x
      end
   end

val near target =
  case target of
     REL8 x: '1'
   | REL16 x: '1'
   | REL32 x: '1'
   | REL64 x: '1'
   | NEARABS x: '1'
   | _: '0'
  end

val far target = not (near target)

val relative target =
  case target of
     REL8 x: '1'
   | REL16 x: '1'
   | REL32 x: '1'
   | REL64 x: '1'
   | _: '0'
  end

val absolute target = not (relative target)

#Todo: MEM => byte offset, REG => bit offset... confusing (division?)
val lval-offset sz x offset =
   case x of
     MEM x:
       do
         #Offset for memory operands? => Add offset to pointer
         address <- conv-with Signed x.psz x.opnd;
	 combined <- return (SEM_LIN_ADD{opnd1=address,opnd2=SEM_LIN_IMM {imm=offset}});
         return (SEM_WRITE_MEM{size=x.psz,address=combined,segment=x.segment})
       end
    | REG r:
       do 
         id <- return (semantic-register-of-operand-with-size x sz);
	 id <- return (@{offset=id.offset + offset} id);
         return (SEM_WRITE_VAR{size= $size id,id=id})
       end
   end


val lval sz x = lval-offset sz x 0
val lval-upper sz x = lval-offset sz x sz

val register? x =
  case x of
      REG: '1'
    | _: '0'
  end

val write-extend avx-encoded sz a b =
   case a of
      SEM_WRITE_MEM x:
         #store x (SEM_LIN{size=sz,opnd1=b})
	 segmented-store x (SEM_LIN{size=sz,opnd1=b}) x.segment
    | SEM_WRITE_VAR x: do
        #if mode64 then
	#  mov 32 (semantic-register-of EAX) (imm 100)
	#else
	#  return void
	#;
        #if (is-avx-sse x.id.id) then
	#  mov 32 (semantic-register-of EAX) (imm 101)
	#else
	#  return void
	#;
        #if (avx-encoded) then
	#  mov 32 (semantic-register-of EAX) (imm 102)
	#else
	#  return void
	#;
	#mov 32 (semantic-register-of EAX) (imm (500 + sz));

	mov sz x.id b;

	mode64 <- mode64?;
	if (mode64 and (not (is-avx-sse x.id.id)) and sz === 32) then
	  #Todo: Only if sz == 32? - Yes (tested)!
	  #Todo: Only for a subset of all registers?
          mov (64 - sz) (at-offset x.id sz) (imm 0)
	else if (avx-encoded and (is-avx-sse x.id.id) and sz < 256) then
	  mov (256 - sz) (at-offset x.id sz) (imm 0)
	else
	  return void

#        case sz of
#           32:
#              case x.id.offset of
#                 0:
#                    do mov 32 x.id b;
#                       # Zero the upper half of the given register/variable
#                       mov 32 (@{offset=32} x.id) (SEM_LIN_IMM {imm=0})
#                    end
#               | _: mov sz x.id b
#              end
#         | _: mov sz x.id b
#        end
        end
   end

val write sz a b = write-extend '0' sz a b

val combine high low = do
  high <- return (semantic-register-of high);
  low <- return (semantic-register-of low);
 
  sz <- return high.size;
 
  combined <- mktemp;
  mov sz (at-offset combined sz) (var high);
  mov sz combined (var low);
 
  return combined
end

val move-combined size dst-high dst-low src = do
  dst-high <- return (semantic-register-of dst-high);
  dst-low <- return (semantic-register-of dst-low);
 
  mov size dst-high (var (at-offset src size));
  mov size dst-low (var (at-offset src 0))
end

val fEQ = return (_var VIRT_EQ)
val fNEQ = return (_var VIRT_NEQ)
val fLES = return (_var VIRT_LES)
val fLEU = return (_var VIRT_LEU)
val fLTS = return (_var VIRT_LTS)
val fLTU = return (_var VIRT_LTU)

val zero = return (SEM_LIN_IMM{imm=0})

val sem-a sem-cc x = do
  cf <- fCF;
  zf <- fZF;
  sem-cc x (/and (/not (var cf)) (/not (var zf)))
end
val sem-nbe sem-cc x = sem-a sem-cc x

val sem-ae sem-cc x = do
  cf <- fCF;
  sem-cc x (/not (var cf))
end
val sem-nb sem-cc x = sem-ae sem-cc x
val sem-nc sem-cc x = sem-ae sem-cc x

val sem-c sem-cc x = do
  cf <- fCF;
  sem-cc x (/d (var cf))
end
val sem-b sem-cc x = sem-c sem-cc x
val sem-nae sem-cc x = sem-nae sem-cc x

val sem-be sem-cc x = do
  cf <- fCF;
  zf <- fZF;
  sem-cc x (/or (/d (var cf)) (/d (var zf)))
end
val sem-na sem-cc x = sem-be sem-cc x

val sem-e sem-cc x = do
  zf <- fZF;
  sem-cc x (/d (var zf))
end
val sem-z sem-cc x = sem-e sem-cc x

val sem-g sem-cc x = do
  zf <- fZF;
  sf <- fSF;
  ov <- fOF;
  sem-cc x (/and (/not (var zf)) (/eq 1 (var sf) (var ov)))
end
val sem-nle sem-cc x = sem-g sem-cc x

val sem-ge sem-cc x = do
  sf <- fSF;
  ov <- fOF;
  sem-cc x (/eq 1 (var sf) (var ov))
end
val sem-nl sem-cc x = sem-ge sem-cc x

val sem-l sem-cc x = do
  sf <- fSF;
  ov <- fOF;
  sem-cc x (/neq 1 (var sf) (var ov))
end
val sem-nge sem-cc x = sem-l sem-cc x

val sem-le sem-cc x = do
  zf <- fZF;
  sf <- fSF;
  ov <- fOF;
  sem-cc x (/or (/d (var zf)) (/neq 1 (var sf) (var ov)))
end
val sem-ng sem-cc x = sem-le sem-cc x

val sem-ne sem-cc x = do
  zf <- fZF;
  sem-cc x (/not (var zf))
end
val sem-nz sem-cc x = sem-ne sem-cc x

val sem-no sem-cc x = do
  ov <- fOF;
  sem-cc x (/not (var ov))
end

val sem-np sem-cc x = do
  pf <- fPF;
  sem-cc x (/not (var pf))
end
val sem-po sem-cc x = sem-np sem-cc x

val sem-ns sem-cc x = do
  sf <- fSF;
  sem-cc x (/not (var sf))
end

val sem-o sem-cc x = do
  ov <- fOF;
  sem-cc x (/d (var ov))
end

val sem-p sem-cc x = do
  pf <- fPF;
  sem-cc x (/d (var pf))
end
val sem-pe sem-cc x = sem-p sem-cc x

val sem-s sem-cc x = do
  sf <- fSF;
  sem-cc x (/d (var sf))
end

val undef-opnd opnd = do
  sz <- sizeof1 opnd;
  a <- lval sz opnd;
  t <- mktemp;
	undef sz t;
  write sz a (var t)
end

val sem-undef-arity-ge1 x = do
  case x.opnd1 of
     REG r: undef-opnd x.opnd1
   | MEM m: undef-opnd x.opnd1
  end
end

val sem-undef-arity0 x = do
  return void
end

val sem-undef-arity1 x = do
  sem-undef-arity-ge1 x
end

val sem-undef-arity2 x = do
  sem-undef-arity-ge1 x
end

val sem-undef-arity3 x = do
  sem-undef-arity-ge1 x
end

val sem-undef-arity4 x = do
  sem-undef-arity-ge1 x
end

val sem-undef-varity x = do
  case x of
     VA0 x: sem-undef-arity0 x
   | VA1 x: sem-undef-arity1 x
   | VA2 x: sem-undef-arity2 x
   | VA3 x: sem-undef-arity3 x
   | VA4 x: sem-undef-arity4 x
  end
end

val sem-undef-flow1 x = do
  return void
end

val emit-parity-flag r = do
  byte-size <- return 8;

  low-byte <- mktemp;
  mov byte-size low-byte r;

  pf <- fPF;
  # Bitwise XNOR
  cmpeq 1 pf (var (at-offset low-byte 7)) (var (at-offset low-byte 6));
  cmpeq 1 pf (var pf) (var (at-offset low-byte 5));
  cmpeq 1 pf (var pf) (var (at-offset low-byte 4));
  cmpeq 1 pf (var pf) (var (at-offset low-byte 3));
  cmpeq 1 pf (var pf) (var (at-offset low-byte 2));
  cmpeq 1 pf (var pf) (var (at-offset low-byte 1));
  cmpeq 1 pf (var pf) (var (at-offset low-byte 0))
end

val emit-arithmetic-adjust-flag sz r op0 op1 = do
  # Hacker's Delight - How the Computer Sets Overflow for Signed Add/Subtract
  t <- mktemp;
  xorb sz t r op0;
  xorb sz t (var t) op1;

  andb sz t (var t) (imm 0x10);
  af <- fAF;
  cmpneq sz af (var t) (imm 0)
end

val emit-add-adc-flags sz sum s0 s1 carry set-carry = let
  val emit = do
    eq <- fEQ;
    les <- fLES;
    leu <- fLEU;
    lts <- fLTS;
    ltu <- fLTU;
    sf <- fSF;
    ov <- fOF;
    z <- fZF;
    cf <- fCF;
    t1 <- mktemp;
    t2 <- mktemp;
    t3 <- mktemp;
    zer0 <- zero;
  
    cmpltu sz ltu s0 s1;
    xorb sz t1 sum s0;
    xorb sz t2 sum s1;
    andb sz t3 (var t1) (var t2);
    cmplts sz ov (var t3) zer0;
    cmplts sz sf sum zer0;
    cmpeq sz eq sum zer0;
    xorb 1 lts (var sf) (var ov);
    orb 1 leu (var ltu) (var eq);
    orb 1 les (var lts) (var eq);
    cmpeq sz z sum zer0;
  
    # Hacker's Delight - Unsigned Add/Subtract
    if set-carry then (
      _if (/d carry) _then do
        cmpleu sz cf sum s0
      end _else do
        cmpltu sz cf sum s0
      end
    ) else
      return void
    ;
  
    emit-parity-flag sum;
    emit-arithmetic-adjust-flag sz sum s0 s1
  end
in
  with-subscope emit
end

val emit-sub-sbb-flags sz difference minuend subtrahend carry set-carry = let
  val emit = do
    eq <- fEQ;
    les <- fLES;
    leu <- fLEU;
    lts <- fLTS;
    ltu <- fLTU;
    sf <- fSF;
    ov <- fOF;
    cf <- fCF;
    z <- fZF;
    t1 <- mktemp;
    t2 <- mktemp;
    t3 <- mktemp;
    zer0 <- zero;
  
    cmpltu sz ltu minuend subtrahend;
    cmpleu sz leu minuend subtrahend;
    cmplts sz lts minuend subtrahend;
    cmples sz les minuend subtrahend;
    cmpeq sz eq minuend subtrahend;
    cmplts sz sf difference zer0;
    xorb 1 ov (var lts) (var sf);
    cmpeq sz z difference zer0;
  
    if set-carry then (
      # Hacker's Delight - Unsigned Add/Subtract
      _if (/d carry) _then do
        cmpleu sz cf minuend subtrahend
      end _else do
        cmpltu sz cf minuend subtrahend
      end
    ) else
      return void
    ;
  
    emit-parity-flag difference;
    emit-arithmetic-adjust-flag sz difference minuend subtrahend
  end
in
  with-subscope emit
end

val emit-mul-flags sz product = let
  val emit = do
    ov <- fOF;
    cf <- fCF;
    sf <- fSF;
    zf <- fZF;
    af <- fAF;
    pf <- fPF;
  
    sgn-ext <- mktemp;
    movsx sz sgn-ext 1 (var (at-offset product (sz + sz - 1)));
  
    cmpneq sz ov (var (at-offset product sz)) (var sgn-ext);
    mov 1 cf (var ov);
  
    undef 1 sf;
    undef 1 zf;
    undef 1 af;
    undef 1 pf
  end
in
  with-subscope emit
end

val move-to-rflags size lin = let
  val emit = do
    flags <- rflags;
  
    in-mask <- return 0x0000000000245fd5;
    out-mask <- return 0xffffffffffc3a02a;
  
    temp <- mktemp;
    andb size temp lin (imm in-mask);
    andb size flags (var flags) (imm out-mask);
    orb size flags (var flags) (var temp)
  end
in
  with-subscope emit
end

val direction-adjust reg-size reg-sem for-size = do
  amount <-
    case for-size of
       8: return 1
     | 16: return 2
     | 32: return 4
     | 64: return 8
    end
  ;

  df <- fDF;
  _if (/not (var df)) _then
    add reg-size reg-sem (var reg-sem) (imm amount)  
  _else
    sub reg-size reg-sem (var reg-sem) (imm amount)
end

val divb x y =
  case x of
     8:
       case y of
          1: 8
        | 2: 4
        | 4: 2
        | 8: 1
       end
   | 16:
       case y of
          1: 16
        | 2: 8
        | 4: 4
        | 8: 2
        | 16: 1
       end
   | 32:
       case y of
          1: 32
        | 2: 16
        | 4: 8
        | 8: 4
        | 16: 2
        | 32: 1
       end
   | 64:
       case y of
          1: 64
        | 2: 32
        | 4: 16
        | 8: 8
        | 16: 4
        | 32: 2
        | 64: 1
       end
   | 128:
       case y of
          1: 128
        | 2: 64
        | 4: 32
        | 8: 16
        | 16: 8
        | 32: 4
        | 64: 2
        | 128: 1
       end
   | 256:
       case y of
          1: 256
        | 2: 128
        | 4: 64
        | 8: 32
        | 16: 16
        | 32: 8
        | 64: 4
        | 128: 2
        | 256: 1
       end
    | k:
       case y of
          1: k
	| k: 1
       end
  end
;

val logb x =
  case x of
     256: 8
   | 128: 7
   | 64: 6
   | 32: 5
   | 16: 4
   | 8: 3
   | 4: 2
   | 2: 1
   | 1: 0
  end

val exp base e =
  case e of
     0: 1
   | x: base * (exp base (e - 1))
  end

val vector-apply size element-size monad = do
  limit <- return (divb size element-size);

  let
    val f i = do
      with-subscope (monad i);

      if (i < (limit - 1)) then
        f (i + 1)
      else
        return void
    end
  in
    f 0
  end
end

#val avx-expand-dst x sem = do
#  sem;
# 
#  size <- sizeof1 x.opnd1;
#  out-size <- return
#    (case x.opnd1 of
#        REG r: 256
#      | _: size
#    end)
#  ;
#
#  if out-size > size then do
#    rest-size <- return (out-size - size);
#    
#    src <- read size x.opnd1;
#    dst <- lval out-size x.opnd1;
#
#    temp <- mktemp;
#    movzx out-size temp size src;
#
#    write out-size dst (var temp)
#  end else
#    return void
#end

val binop-signed-saturating operator size dst src1 src2 = do
  dst-ex <- mktemp;
  src1-ex <- mktemp;
  src2-ex <- mktemp;

  upper <- return (
    case size of
       8: 0x7f
     | 16: 0x7fff
    end
  );
  lower <- return (
    case size of
       8: (0-0x80)
     | 16: (0-0x8000)
    end
  );

  movsx (size + 1) src1-ex size src1;
  movsx (size + 1) src2-ex size src2;
  operator (size + 1) dst-ex (var src1-ex) (var src2-ex);
  
  _if (/gts (size + 1) (var dst-ex) (imm upper)) _then (
    mov size dst (imm upper)
  ) _else ( _if (/lts (size + 1) (var dst-ex) (imm lower)) _then
    mov size dst (imm lower)
  _else
    mov size dst (var dst-ex)
  )
end

val add-signed-saturating size dst src1 src2 = binop-signed-saturating add size dst src1 src2
val sub-signed-saturating size dst src1 src2 = binop-signed-saturating sub size dst src1 src2

val binop-unsigned-saturating operator comparer limit size dst src1 src2 = do
  operator size dst src1 src2;
 
  _if (comparer size (var dst) src1) _then (
    mov size dst (imm limit)
  )
end

val add-unsigned-saturating size dst src1 src2 = do
  limit <- return (
    case size of
       8: 0xff
     | 16: 0xffff
    end
  );
  binop-unsigned-saturating add /ltu limit size dst src1 src2
end

val sub-unsigned-saturating size dst src1 src2 = binop-unsigned-saturating sub /gtu 0 size dst src1 src2

val semantics insn =
  case insn of
     AAA x: sem-undef-arity0 x
   | AAD x: sem-undef-arity1 x
   | AAM x: sem-undef-arity1 x
   | AAS x: sem-undef-arity0 x
   | ADC x: sem-adc x
   | ADD x: sem-add x
   | ADDPD x: sem-undef-arity2 x
   | ADDPS x: sem-undef-arity2 x
   | ADDSD x: sem-undef-arity2 x
   | ADDSS x: sem-undef-arity2 x
   | ADDSUBPD x: sem-undef-arity2 x
   | ADDSUBPS x: sem-undef-arity2 x
   | AESDEC x: sem-undef-arity2 x
   | AESDECLAST x: sem-undef-arity2 x
   | AESENC x: sem-undef-arity2 x
   | AESENCLAST x: sem-undef-arity2 x
   | AESIMC x: sem-undef-arity2 x
   | AESKEYGENASSIST x: sem-undef-arity3 x
   | AND x: sem-and x
   | ANDNPD x: sem-undef-arity2 x
   | ANDNPS x: sem-undef-arity2 x
   | ANDPD x: sem-andpd x
   | ANDPS x: sem-undef-arity2 x
   | ARPL x: sem-undef-arity2 x
   | BLENDPD x: sem-undef-arity3 x
   | BLENDPS x: sem-undef-arity3 x
   | BLENDVPD x: sem-undef-arity3 x
   | BLENDVPS x: sem-undef-arity3 x
   | BOUND x: sem-undef-arity2 x
   | BSF x: sem-bsf x
   | BSR x: sem-bsr x
   | BSWAP x: sem-bswap x
   | BT x: sem-bt x sem-bt-none
   | BTC x: sem-bt x sem-bt-complement
   | BTR x: sem-bt x sem-bt-reset
   | BTS x: sem-bt x sem-bt-set
   | CALL x: sem-call x
   | CBW x: sem-convert 8
   | CDQ x: sem-cwd-cdq-cqo x
   | CDQE x: sem-convert 32
   | CLC x: sem-undef-arity0 x
   | CLD x: sem-undef-arity0 x
   | CLFLUSH x: sem-undef-arity1 x
   | CLI x: sem-undef-arity0 x
   | CLTS x: sem-undef-arity0 x
   | CMC x: sem-cmc
   | CMOVA x: sem-a sem-cmovcc x
   | CMOVAE x: sem-ae sem-cmovcc x
   | CMOVB x: sem-b sem-cmovcc x
   | CMOVBE x: sem-be sem-cmovcc x
   | CMOVC x: sem-c sem-cmovcc x
   | CMOVE x: sem-e sem-cmovcc x
   | CMOVG x: sem-g sem-cmovcc x
   | CMOVGE x: sem-ge sem-cmovcc x
   | CMOVL x: sem-l sem-cmovcc x
   | CMOVLE x: sem-le sem-cmovcc x
   | CMOVNA x: sem-na sem-cmovcc x
   | CMOVNAE x: sem-nae sem-cmovcc x
   | CMOVNB x: sem-nb sem-cmovcc x
   | CMOVNBE x: sem-nbe sem-cmovcc x
   | CMOVNC x: sem-nc sem-cmovcc x
   | CMOVNE x: sem-ne sem-cmovcc x
   | CMOVNG x: sem-ng sem-cmovcc x
   | CMOVNGE x: sem-nge sem-cmovcc x
   | CMOVNL x: sem-nl sem-cmovcc x
   | CMOVNLE x: sem-nle sem-cmovcc x
   | CMOVNO x: sem-no sem-cmovcc x
   | CMOVNP x: sem-np sem-cmovcc x
   | CMOVNS x: sem-ns sem-cmovcc x
   | CMOVNZ x: sem-nz sem-cmovcc x
   | CMOVO x: sem-o sem-cmovcc x
   | CMOVP x: sem-p sem-cmovcc x
   | CMOVPE x: sem-pe sem-cmovcc x
   | CMOVPO x: sem-po sem-cmovcc x
   | CMOVS x: sem-s sem-cmovcc x
   | CMOVZ x: sem-z sem-cmovcc x
   | CMP x: sem-cmp x
   | CMPPD x: sem-undef-arity3 x
   | CMPPS x: sem-undef-arity3 x
   | CMPS x: sem-repe-repne-insn x sem-cmps
   | CMPSD x: sem-undef-arity3 x
#   | CMPSD x:
#       case x of
#         VA0: sem-cmpsd
#       | _ x: sem-undef-arity0 x
#      end
#   | CMPSQ x: sem-undef-arity0 x
   | CMPSS x: sem-undef-arity3 x
   | CMPXCHG x: sem-cmpxchg x
   | CMPXCHG16B x: sem-cmpxchg16b-cmpxchg8b x
   | CMPXCHG8B x: sem-cmpxchg16b-cmpxchg8b x
   | COMISD x: sem-undef-arity2 x
   | COMISS x: sem-undef-arity2 x
   | CPUID x: sem-cpuid x
   | CQO x: sem-cwd-cdq-cqo x
   | CRC32 x: sem-undef-arity2 x
   | CVTDQ2PD x: sem-undef-arity2 x
   | CVTDQ2PS x: sem-undef-arity2 x
   | CVTPD2DQ x: sem-undef-arity2 x
   | CVTPD2PI x: sem-undef-arity2 x
   | CVTPD2PS x: sem-undef-arity2 x
   | CVTPI2PD x: sem-undef-arity2 x
   | CVTPI2PS x: sem-undef-arity2 x
   | CVTPS2DQ x: sem-undef-arity2 x
   | CVTPS2PD x: sem-undef-arity2 x
   | CVTPS2PI x: sem-undef-arity2 x
   | CVTSD2SI x: sem-undef-arity2 x
   | CVTSD2SS x: sem-undef-arity2 x
   | CVTSI2SD x: sem-undef-arity2 x
   | CVTSI2SS x: sem-undef-arity2 x
   | CVTSS2SD x: sem-undef-arity2 x
   | CVTSS2SI x: sem-undef-arity2 x
   | CVTTPD2DQ x: sem-undef-arity2 x
   | CVTTPD2PI x: sem-undef-arity2 x
   | CVTTPS2DQ x: sem-undef-arity2 x
   | CVTTPS2PI x: sem-undef-arity2 x
   | CVTTSD2SI x: sem-undef-arity2 x
   | CVTTSS2SI x: sem-undef-arity2 x
   | CWD x: sem-cwd-cdq-cqo x
   | CWDE x: sem-convert 16
   | DAA x: sem-undef-arity0 x
   | DAS x: sem-undef-arity0 x
   | DEC x: sem-dec x
   | DIV x: sem-div Unsigned x
   | DIVPD x: sem-undef-arity2 x
   | DIVPS x: sem-undef-arity2 x
   | DIVSD x: sem-undef-arity2 x
   | DIVSS x: sem-undef-arity2 x
   | DPPD x: sem-undef-arity3 x
   | DPPS x: sem-undef-arity3 x
   | EMMS x: sem-undef-arity0 x
   | ENTER x: sem-undef-arity2 x
   | EXTRACTPS x: sem-undef-arity3 x
   | F2XM1 x: sem-undef-arity0 x
   | FABS x: sem-undef-arity0 x
   | FADD x: sem-undef-arity2 x
   | FADDP x: sem-undef-arity2 x
   | FBLD x: sem-undef-arity1 x
   | FBSTP x: sem-undef-arity1 x
   | FCHS x: sem-undef-arity0 x
   | FCLEX x: sem-undef-arity0 x
   | FCMOVB x: sem-undef-arity2 x
   | FCMOVBE x: sem-undef-arity2 x
   | FCMOVE x: sem-undef-arity2 x
   | FCMOVNB x: sem-undef-arity2 x
   | FCMOVNBE x: sem-undef-arity2 x
   | FCMOVNE x: sem-undef-arity2 x
   | FCMOVNU x: sem-undef-arity2 x
   | FCMOVU x: sem-undef-arity2 x
   | FCOM x: sem-undef-arity1 x
   | FCOMI x: sem-undef-arity2 x
   | FCOMIP x: sem-undef-arity2 x
   | FCOMP x: sem-undef-arity1 x
   | FCOMPP x: sem-undef-arity0 x
   | FCOS x: sem-undef-arity0 x
   | FDECSTP x: sem-undef-arity0 x
   | FDIV x: sem-undef-arity2 x
   | FDIVP x: sem-undef-arity2 x
   | FDIVR x: sem-undef-arity2 x
   | FDIVRP x: sem-undef-arity2 x
   | FFREE x: sem-undef-arity1 x
   | FIADD x: sem-undef-arity1 x
   | FICOM x: sem-undef-arity1 x
   | FICOMP x: sem-undef-arity1 x
   | FIDIV x: sem-undef-arity2 x
   | FIDIVR x: sem-undef-arity1 x
   | FILD x: sem-undef-arity1 x
   | FIMUL x: sem-undef-arity1 x
   | FINCSTP x: sem-undef-arity0 x
   | FINIT x: sem-undef-arity0 x
   | FIST x: sem-undef-arity1 x
   | FISTP x: sem-undef-arity1 x
   | FISTTP x: sem-undef-arity1 x
   | FISUB x: sem-undef-arity1 x
   | FISUBR x: sem-undef-arity1 x
   | FLD x: sem-undef-arity1 x
   | FLD1 x: sem-undef-arity0 x
   | FLDCW x: sem-undef-arity1 x
   | FLDENV x: sem-undef-arity1 x
   | FLDL2E x: sem-undef-arity0 x
   | FLDL2T x: sem-undef-arity0 x
   | FLDLG2 x: sem-undef-arity0 x
   | FLDLN2 x: sem-undef-arity0 x
   | FLDPI x: sem-undef-arity0 x
   | FLDZ x: sem-undef-arity0 x
   | FMUL x: sem-undef-arity2 x
   | FMULP x: sem-undef-arity2 x
   | FNCLEX x: sem-undef-arity0 x
   | FNINIT x: sem-undef-arity0 x
   | FNOP x: sem-undef-arity0 x
   | FNSAVE x: sem-undef-arity1 x
   | FNSTCW x: sem-undef-arity1 x
   | FNSTENV x: sem-undef-arity1 x
   | FNSTSW x: sem-undef-arity1 x
   | FPATAN x: sem-undef-arity0 x
   | FPREM1 x: sem-undef-arity0 x
   | FPREM x: sem-undef-arity0 x
   | FPTAN x: sem-undef-arity0 x
   | FRNDINT x: sem-undef-arity0 x
   | FRSTOR x: sem-undef-arity1 x
   | FSAVE x: sem-undef-arity1 x
   | FSCALE x: sem-undef-arity0 x
   | FSIN x: sem-undef-arity0 x
   | FSINCOS x: sem-undef-arity0 x
   | FSQRT x: sem-undef-arity0 x
   | FST x: sem-undef-arity1 x
   | FSTCW x: sem-undef-arity1 x
   | FSTENV x: sem-undef-arity1 x
   | FSTP x: sem-undef-arity1 x
   | FSTSW x: sem-undef-arity1 x
   | FSUB x: sem-undef-arity2 x
   | FSUBP x: sem-undef-arity2 x
   | FSUBR x: sem-undef-arity2 x
   | FSUBRP x: sem-undef-arity2 x
   | FTST x: sem-undef-arity0 x
   | FUCOM x: sem-undef-arity1 x
   | FUCOMI x: sem-undef-arity1 x
   | FUCOMIP x: sem-undef-arity1 x
   | FUCOMP x: sem-undef-arity1 x
   | FUCOMPP x: sem-undef-arity0 x
   | FXAM x: sem-undef-arity0 x
   | FXCH x: sem-undef-arity1 x
   | FXRSTOR x: sem-undef-arity1 x
   | FXRSTOR64 x: sem-undef-arity1 x
   | FXSAVE x: sem-undef-arity1 x
   | FXSAVE64 x: sem-undef-arity1 x
   | FXTRACT x: sem-undef-arity0 x
   | FYL2X x: sem-undef-arity0 x
   | FYL2XP1 x: sem-undef-arity0 x
   | HADDPD x: sem-undef-arity2 x
   | HADDPS x: sem-undef-arity2 x
   | HLT x: sem-undef-arity0 x
   | HSUBPD x: sem-undef-arity2 x
   | HSUBPS x: sem-undef-arity2 x
   | IDIV x: sem-idiv x
   | IMUL v:
       case v of
          VA1 x: sem-imul-1 x
        | VA2 x: sem-imul-2 x
        | VA3 x: sem-imul-3 x
       end
   | IN x: sem-undef-arity2 x
   | INC x: sem-inc x
   | INSB x: sem-undef-arity0 x
   | INSD x: sem-undef-arity0 x
   | INSERTPS x: sem-undef-arity3 x
   | INSW x: sem-undef-arity0 x
   | INT x: sem-undef-arity1 x
   | INT0 x: sem-undef-arity0 x
   | INT3 x: sem-undef-arity0 x
   | INVD x: sem-invd
   | INVLPG x: sem-undef-arity1 x
   | INVPCID x: sem-undef-arity2 x
   | IRET x: sem-undef-arity0 x
   | IRETD x: sem-undef-arity0 x
   | IRETQ x: sem-undef-arity0 x
   | JA x: sem-a sem-jcc x
   | JAE x: sem-ae sem-jcc x
   | JB x: sem-b sem-jcc x
   | JBE x: sem-be sem-jcc x
   | JC x: sem-c sem-jcc x
   | JCXZ x: sem-jcxz x
   | JE x: sem-e sem-jcc x
   | JECXZ x: sem-jecxz x
   | JG x: sem-g sem-jcc x
   | JGE x: sem-ge sem-jcc x
   | JL x: sem-l sem-jcc x
   | JLE x: sem-le sem-jcc x
   | JMP x: sem-jmp x
   | JNA x: sem-na sem-jcc x
   | JNAE x: sem-nae sem-jcc x
   | JNB x: sem-nb sem-jcc x
   | JNBE x: sem-nbe sem-jcc x
   | JNC x: sem-nc sem-jcc x
   | JNE x: sem-ne sem-jcc x
   | JNG x: sem-ng sem-jcc x
   | JNGE x: sem-nge sem-jcc x
   | JNL x: sem-nl sem-jcc x
   | JNLE x: sem-nle sem-jcc x
   | JNO x: sem-no sem-jcc x
   | JNP x: sem-np sem-jcc x
   | JNS x: sem-ns sem-jcc x
   | JNZ x: sem-nz sem-jcc x
   | JO x: sem-o sem-jcc x
   | JP x: sem-p sem-jcc x
   | JPE x: sem-pe sem-jcc x
   | JPO x: sem-po sem-jcc x
   | JRCXZ x: sem-jrcxz x
   | JS x: sem-s sem-jcc x
   | JZ x: sem-z sem-jcc x
   | LAHF x: sem-lahf
   | LAR x: sem-undef-arity2 x
   | LDDQU x: sem-mov '0' x
   | LDMXCSR x: sem-undef-arity1 x
   | LDS x: sem-lds-les-lfs-lgs-lss x DS
   | LEA x: sem-lea x
   | LEAVE x: sem-undef-arity0 x
   | LES x: sem-lds-les-lfs-lgs-lss x ES
   | LFENCE x: sem-undef-arity0 x
   | LFS x: sem-lds-les-lfs-lgs-lss x FS
   | LGDT x: sem-undef-arity1 x
   | LGS x: sem-lds-les-lfs-lgs-lss x GS
   | LIDT x: sem-undef-arity1 x
   | LLDT x: sem-undef-arity1 x
   | LMSW x: sem-undef-arity1 x
   | LODS x: sem-rep-insn x sem-lods
   | LOOP x: sem-loop x
   | LOOPE x: sem-loope x
   | LOOPNE x: sem-loopne x
   | LSL x: sem-undef-arity2 x
   | LSS x: sem-lds-les-lfs-lgs-lss x SS
   | LTR x: sem-undef-arity1 x
   | MASKMOVDQU x: sem-maskmovdqu-vmaskmovdqu x
   | MASKMOVQ x: sem-maskmovq x
   | MAXPD x: sem-undef-arity2 x
   | MAXPS x: sem-undef-arity2 x
   | MAXSD x: sem-undef-arity2 x
   | MAXSS x: sem-undef-arity2 x
   | MFENCE x: sem-undef-arity0 x
   | MINPD x: sem-undef-arity2 x
   | MINPS x: sem-undef-arity2 x
   | MINSD x: sem-undef-arity2 x
   | MINSS x: sem-undef-arity2 x
   | MONITOR x: sem-undef-arity0 x
   | MOV x: sem-mov '0' x
   | MOVAPD x: sem-mov '0' x
   | MOVAPS x: sem-mov '0' x
   | MOVBE x: sem-movbe x
   | MOVD x: sem-movzx '0' x
   | MOVDDUP x: sem-undef-arity2 x
   | MOVDQ2Q x: sem-mov '0' x
   | MOVDQA x: sem-mov '0' x
   | MOVDQU x: sem-mov '0' x
   | MOVHLPS x: sem-undef-arity2 x
   | MOVHPD x: sem-undef-arity2 x
   | MOVHPS x: sem-undef-arity2 x
   | MOVLHPS x: sem-undef-arity2 x
   | MOVLPD x: sem-undef-arity2 x
   | MOVLPS x: sem-undef-arity2 x
   | MOVMSKPD x: sem-undef-arity2 x
   | MOVMSKPS x: sem-undef-arity2 x
   | MOVNTDQ x: sem-mov '0' x
   | MOVNTDQA x: sem-mov '0' x
   | MOVNTI x: sem-mov '0' x
   | MOVNTPD x: sem-undef-arity2 x
   | MOVNTPS x: sem-undef-arity2 x
   | MOVNTQ x: sem-mov '0' x
   | MOVQ x: sem-movzx '0' x
   | MOVQ2DQ x: sem-movzx '0' x
   | MOVS x: sem-rep-insn x sem-movs
   | MOVSD x: sem-undef-arity2 x
   | MOVSHDUP x: sem-undef-arity2 x
   | MOVSLDUP x: sem-undef-arity2 x
   | MOVSS x: sem-undef-arity2 x
   | MOVSW x: sem-undef-arity2 x
   | MOVSX x: sem-movsx x
   | MOVSXD x: sem-movsx x
   | MOVUPD x: sem-undef-arity2 x
   | MOVUPS x: sem-undef-arity2 x
   | MOVZX x: sem-movzx '0' x
   | MPSADBW x: sem-undef-arity3 x
   | MUL x: sem-mul Unsigned x
   | MULPD x: sem-undef-arity2 x
   | MULPS x: sem-undef-arity2 x
   | MULSD x: sem-undef-arity2 x
   | MULSS x: sem-undef-arity2 x
   | MWAIT x: sem-nop
   | NEG x: sem-neg x
   | NOP x: sem-nop
   | NOT x: sem-not x
   | OR x: sem-or x
   | ORPD x: sem-undef-arity2 x
   | ORPS x: sem-undef-arity2 x
   | OUT x: sem-undef-arity2 x
   | OUTS x: sem-undef-arity0 x
   | OUTSB x: sem-undef-arity0 x
   | OUTSD x: sem-undef-arity0 x
   | OUTSW x: sem-undef-arity0 x
   | PABSB x: sem-pabs '0' 8 x
   | PABSD x: sem-pabs '0' 32 x
   | PABSW x: sem-pabs '0' 16 x
   | PACKSSDW x: sem-packsswb-packssdw 16 x
   | PACKSSWB x: sem-packsswb-packssdw 8 x
   | PACKUSDW x: sem-packuswb-packusdw 16 x
   | PACKUSWB x: sem-packuswb-packusdw 8 x
   | PADDB x: sem-padd 8 x
   | PADDD x: sem-padd 32 x
   | PADDQ x: sem-padd 64 x
   | PADDSB x: sem-padds 8 x
   | PADDSW x: sem-padds 16 x
   | PADDUSB x: sem-paddus 8 x
   | PADDUSW x: sem-paddus 16 x
   | PADDW x: sem-padd 16 x
   | PALIGNR x: sem-palignr x
   | PAND x: sem-pand x
   | PANDN x: sem-pandn x
   | PAUSE x: sem-undef-arity0 x
   | PAVGB x: sem-pavg 8 x
   | PAVGW x: sem-pavg 16 x
   | PBLENDVB x: sem-pblendvb x
   | PBLENDW x: sem-pblendw x
   | PCLMULQDQ x: sem-pclmulqdq x
   | PCMPEQB x: sem-pcmpeq 8 x
   | PCMPEQD x: sem-pcmpeq 32 x
   | PCMPEQQ x: sem-pcmpeq 64 x
   | PCMPEQW x: sem-pcmpeq 16 x
   | PCMPESTRI x: sem-undef-arity3 x
   | PCMPESTRM x: sem-undef-arity3 x
   | PCMPGRD x: sem-undef-arity2 x
   | PCMPGTB x: sem-pcmpgt 8 x
   | PCMPGTD x: sem-pcmpgt 32 x 
   | PCMPGTQ x: sem-pcmpgt 64 x
   | PCMPGTW x: sem-pcmpgt 16 x
   | PCMPISTRI x: sem-undef-arity3 x
   | PCMPISTRM x: sem-undef-arity3 x
   | PEXTRB x: sem-pextr-vpextr 8 x
   | PEXTRD x: sem-pextr-vpextr 32 x
   | PEXTRQ x: sem-pextr-vpextr 64 x
   | PEXTRW x: sem-pextr-vpextr 16 x
   | PHADDD x: sem-phadd 32 x
   | PHADDSW x: sem-phaddsw x
   | PHADDW x: sem-phadd 16 x
   | PHMINPOSUW x: sem-phminposuw-vphminposuw '0' x
   | PHSUBD x: sem-phsub 32 x
   | PHSUBSW x: sem-phsubsw x
   | PHSUBW x: sem-phsub 16 x
   | PINSRB x: sem-pinsr 8 x
   | PINSRD x: sem-pinsr 32 x
   | PINSRQ x: sem-pinsr 64 x
   | PINSRW x: sem-pinsr 16 x
   | PMADDUBSW x: sem-pmaddubsw x
   | PMADDWD x: sem-pmaddwd x
   | PMAXSB x: sem-pmaxs 8 x
   | PMAXSD x: sem-pmaxs 32 x
   | PMAXSW x: sem-pmaxs 16 x
   | PMAXUB x: sem-pmaxu 8 x
   | PMAXUD x: sem-pmaxu 32 x
   | PMAXUW x: sem-pmaxu 16 x
   | PMINSB x: sem-pmins 8 x
   | PMINSD x: sem-pmins 32 x
   | PMINSW x: sem-pmins 16 x
   | PMINUB x: sem-pminu 8 x
   | PMINUD x: sem-pminu 32 x
   | PMINUW x: sem-pminu 16 x
   | PMOVMSKB x: sem-pmovmskb-vpmovmskb '0' x
   | PMOVSXBD x: sem-pmovsx-vpmovsx '0' 8 32 x
   | PMOVSXBQ x: sem-pmovsx-vpmovsx '0' 8 64 x
   | PMOVSXBW x: sem-pmovsx-vpmovsx '0' 8 16 x
   | PMOVSXDQ x: sem-pmovsx-vpmovsx '0' 32 64 x
   | PMOVSXWD x: sem-pmovsx-vpmovsx '0' 16 32 x
   | PMOVSXWQ x: sem-pmovsx-vpmovsx '0' 16 64 x
   | PMOVZXBD x: sem-pmovzx-vpmovzx '0' 8 32 x
   | PMOVZXBQ x: sem-pmovzx-vpmovzx '0' 8 64 x
   | PMOVZXBW x: sem-pmovzx-vpmovzx '0' 8 16 x
   | PMOVZXDQ x: sem-pmovzx-vpmovzx '0' 32 64 x
   | PMOVZXWD x: sem-pmovzx-vpmovzx '0' 16 32 x
   | PMOVZXWQ x: sem-pmovzx-vpmovzx '0' 16 64 x
   | PMULDQ x: sem-pmuldq x
   | PMULHRSW x: sem-pmulhrsw x
   | PMULHUW x: sem-pmulhuw x
   | PMULHW x: sem-pmulhw x
   | PMULLD x: sem-pmull 32 x
   | PMULLW x: sem-pmull 16 x
   | PMULUDQ x: sem-pmuludq x
   | POP x: sem-pop x
   | POPA x: sem-popa-popad x
   | POPAD x: sem-popa-popad x
   | POPCNT x: sem-popcnt x
   | POPF x: sem-popf x
   | POPFD x: sem-popf x
   | POPFQ x: sem-popf x
   | POR x: sem-por x
   | PREFETCHNTA x: sem-undef-arity1 x
   | PREFETCHT0 x: sem-undef-arity1 x
   | PREFETCHT1 x: sem-undef-arity1 x
   | PREFETCHT2 x: sem-undef-arity1 x
   | PREFETCHW x: sem-undef-arity1 x
   | PSADBW x: sem-psadbw x
   | PSHUFB x: sem-pshufb x
   | PSHUFD x: sem-pshufd-vpshufd '0' x
   | PSHUFHW x: sem-pshufhw-vpshufhw '0' x
   | PSHUFLW x: sem-pshuflw-vpshuflw '0' x
   | PSHUFW x: sem-pshufw x
   | PSIGNB x: sem-psign 8 x
   | PSIGND x: sem-psign 32 x
   | PSIGNW x: sem-psign 16 x
   | PSLLD x: sem-psll 32 x
   | PSLLDQ x: sem-pslldq x
   | PSLLQ x: sem-psll 64 x
   | PSLLW x: sem-psll 16 x
   | PSRAD x: sem-psra 32 x
   | PSRAW x: sem-psra 16 x
   | PSRLD x: sem-psrl 32 x
   | PSRLDQ x: sem-psrldq x
   | PSRLQ x: sem-psrl 64 x
   | PSRLW x: sem-psrl 16 x
   | PSUBB x: sem-psub 8 x
   | PSUBD x: sem-psub 32 x
   | PSUBQ x: sem-psub 64 x
   | PSUBSB x: sem-psubs 8 x
   | PSUBSW x: sem-psubs 16 x
   | PSUBUSB x: sem-psubus 8 x
   | PSUBUSW x: sem-psubus 16 x
   | PSUBW x: sem-psub 16 x
   | PTEST x: sem-ptest-vptest x
   | PUNPCKHBW x: sem-punpckh 8 x
   | PUNPCKHDQ x: sem-punpckh 32 x
   | PUNPCKHQDQ x: sem-punpckh 64 x
   | PUNPCKHWD x: sem-punpckh 16 x
   | PUNPCKLBW x: sem-punpckl 8 x
   | PUNPCKLDQ x: sem-punpckl 32 x
   | PUNPCKLQDQ x: sem-punpckl 64 x
   | PUNPCKLWD x: sem-punpckl 16 x
   | PUSH x: sem-push x
   | PUSHA x: sem-pusha-pushad x
   | PUSHAD x: sem-pusha-pushad x
   | PUSHF x: sem-pushf x
   | PUSHFD x: sem-pushf x
   | PUSHFQ x: sem-pushf x
   | PXOR x: sem-pxor x
   | RCL x: sem-rcl x
   | RCPPS x: sem-undef-arity2 x
   | RCPSS x: sem-undef-arity2 x
   | RCR x: sem-rcr x
   | RDFSBASE x: sem-undef-arity1 x
   | RDGSBASE x: sem-undef-arity1 x
   | RDMSR x: sem-undef-arity0 x
   | RDPMC x: sem-undef-arity0 x
   | RDRAND x: sem-undef-arity1 x
   | RDTSC x: sem-undef-arity0 x
   | RDTSCP x: sem-undef-arity0 x
   | RET x: sem-ret x
   | RET_FAR x: sem-ret-far x
   | ROL x: sem-rol x
   | ROR x: sem-ror x
   | ROUNDPD x: sem-undef-arity3 x
   | ROUNDPS x: sem-undef-arity3 x
   | ROUNDSD x: sem-undef-arity3 x
   | ROUNDSS x: sem-undef-arity3 x
   | RSM x: sem-undef-arity0 x
   | RSQRTPS x: sem-undef-arity2 x
   | RSQRTSS x: sem-undef-arity2 x
   | SAHF x: sem-sahf x
   | SAL x: sem-sal-shl x
   | SAR x: sem-shr-sar x '1'
   | SBB x: sem-sbb x
   | SCASB x: sem-scas 8 x
   | SCASD x: sem-scas 32 x
   | SCASQ x: sem-scas 64 x
   | SCASW x: sem-scas 16 x
   | SETA x: sem-a sem-setcc x
   | SETAE x: sem-ae sem-setcc x
   | SETB x: sem-b sem-setcc x
   | SETBE x: sem-be sem-setcc x
   | SETC x: sem-c sem-setcc x
   | SETE x: sem-e sem-setcc x
   | SETG x: sem-g sem-setcc x
   | SETGE x: sem-ge sem-setcc x
   | SETL x: sem-l sem-setcc x
   | SETLE x: sem-le sem-setcc x
   | SETNA x: sem-na sem-setcc x
   | SETNAE x: sem-nae sem-setcc x
   | SETNB x: sem-nb sem-setcc x
   | SETNBE x: sem-nbe sem-setcc x
   | SETNC x: sem-nc sem-setcc x
   | SETNE x: sem-ne sem-setcc x
   | SETNG x: sem-ng sem-setcc x
   | SETNGE x: sem-nge sem-setcc x
   | SETNL x: sem-nl sem-setcc x
   | SETNLE x: sem-nle sem-setcc x
   | SETNO x: sem-no sem-setcc x
   | SETNP x: sem-np sem-setcc x
   | SETNS x: sem-ns sem-setcc x
   | SETNZ x: sem-nz sem-setcc x
   | SETO x: sem-o sem-setcc x
   | SETP x: sem-p sem-setcc x
   | SETPE x: sem-pe sem-setcc x
   | SETPO x: sem-po sem-setcc x
   | SETS x: sem-s sem-setcc x
   | SETZ x: sem-z sem-setcc x
   | SFENCE x: sem-undef-arity0 x
   | SGDT x: sem-undef-arity1 x
   | SHL x: sem-sal-shl x
   | SHLD x: sem-shld x
   | SHR x: sem-shr-sar x '0'
   | SHRD x: sem-shrd x
   | SHUFPD x: sem-undef-arity3 x
   | SHUFPS x: sem-undef-arity3 x
   | SIDT x: sem-undef-arity1 x
   | SLDT x: sem-undef-arity1 x
   | SMSW x: sem-undef-arity1 x
   | SQRTPD x: sem-undef-arity2 x
   | SQRTPS x: sem-undef-arity2 x
   | SQRTSD x: sem-undef-arity2 x
   | SQRTSS x: sem-undef-arity2 x
   | STC x: sem-stc
   | STD x: sem-std
   | STI x: sem-undef-arity0 x
   | STMXCSR x: sem-undef-arity1 x
   | STOSB x: sem-stos 8 x
   | STOSD x: sem-stos 32 x
   | STOSQ x: sem-stos 64 x
   | STOSW x: sem-stos 16 x
   | STR x: sem-undef-arity1 x
   | SUB x: sem-sub x
   | SUBPD x: sem-undef-arity2 x
   | SUBPS x: sem-undef-arity2 x
   | SUBSD x: sem-undef-arity2 x
   | SUBSS x: sem-undef-arity2 x
   | SWAPGS x: sem-undef-arity0 x
   | SYSCALL x: sem-undef-arity0 x
   | SYSENTER x: sem-undef-arity0 x
   | SYSEXIT x: sem-undef-arity0 x
   | SYSRET x: sem-undef-arity0 x
   | TEST x: sem-test x
   | UCOMISD x: sem-undef-arity2 x
   | UCOMISS x: sem-undef-arity2 x
   | UD2 x: sem-undef-arity0 x
   | UNPCKHPD x: sem-undef-arity2 x
   | UNPCKHPS x: sem-undef-arity2 x
   | UNPCKLPD x: sem-undef-arity2 x
   | UNPCKLPS x: sem-undef-arity2 x
   | VADDPD x: sem-undef-varity x
   | VADDPS x: sem-undef-varity x
   | VADDSD x: sem-undef-varity x
   | VADDSS x: sem-undef-varity x
   | VADDSUBPD x: sem-undef-varity x
   | VADDSUBPS x: sem-undef-varity x
   | VAESDEC x: sem-undef-varity x
   | VAESDECLAST x: sem-undef-varity x
   | VAESENC x: sem-undef-varity x
   | VAESENCLAST x: sem-undef-varity x
   | VAESIMC x: sem-undef-varity x
   | VAESKEYGENASSIST x: sem-undef-varity x
   | VANDNPD v: sem-undef-varity v
   | VANDNPS x: sem-undef-varity x
   | VANDPD v:
       case v of
          VA3 x: sem-vandpd x
       end
   | VANDPS x: sem-undef-varity x
   | VBLENDPD x: sem-undef-varity x
   | VBLENDPS x: sem-undef-varity x
   | VBLENDVPD x: sem-undef-varity x
   | VBLENDVPS x: sem-undef-varity x
   | VBROADCASTF128 v: sem-vbroadcast v
   | VBROADCASTSD v: sem-vbroadcast v
   | VBROADCASTSS v: sem-vbroadcast v
   | VCMPEQB x: sem-undef-varity x
   | VCMPEQD x: sem-undef-varity x
   | VCMPEQW x: sem-undef-varity x
   | VCMPPD x: sem-undef-varity x
   | VCMPPS x: sem-undef-varity x
   | VCMPSD x: sem-undef-varity x
   | VCMPSS x: sem-undef-varity x
   | VCOMISD x: sem-undef-varity x
   | VCOMISS x: sem-undef-varity x
   | VCVTDQ2PD x: sem-undef-varity x
   | VCVTDQ2PS x: sem-undef-varity x
   | VCVTPD2DQ x: sem-undef-varity x
   | VCVTPD2PS x: sem-undef-varity x
   | VCVTPH2PS x: sem-undef-varity x
   | VCVTPS2DQ x: sem-undef-varity x
   | VCVTPS2PD x: sem-undef-varity x
   | VCVTPS2PH x: sem-undef-varity x
   | VCVTSD2SI x: sem-undef-varity x
   | VCVTSD2SS x: sem-undef-varity x
   | VCVTSI2SD x: sem-undef-varity x
   | VCVTSI2SS x: sem-undef-varity x
   | VCVTSS2SD x: sem-undef-varity x
   | VCVTSS2SI x: sem-undef-varity x
   | VCVTTPD2DQ x: sem-undef-varity x
   | VCVTTPS2DQ x: sem-undef-varity x
   | VCVTTSD2SI x: sem-undef-varity x
   | VCVTTSS2SI x: sem-undef-varity x
   | VDIVPD x: sem-undef-varity x
   | VDIVPS x: sem-undef-varity x
   | VDIVSD x: sem-undef-varity x
   | VDIVSS x: sem-undef-varity x
   | VDPPD x: sem-undef-varity x
   | VDPPS x: sem-undef-varity x
   | VERR x: sem-undef-arity1 x
   | VERW x: sem-undef-arity1 x
   | VEXTRACTF128 x: sem-undef-varity x
   | VEXTRACTPS x: sem-undef-varity x
   | VHADDPD x: sem-undef-varity x
   | VHADDPS x: sem-undef-varity x
   | VHSUBPD x: sem-undef-varity x
   | VHSUBPS x: sem-undef-varity x
   | VINSERTF128 x: sem-undef-varity x
   | VINSERTPS x: sem-undef-varity x
   | VLDDQU v:
       case v of
         VA2 x: sem-mov '1' x
       end
   | VLDMXCSR x: sem-undef-varity x
   | VMASKMOVDQU v:
       case v of
          VA3 x: sem-maskmovdqu-vmaskmovdqu x
       end
   | VMASKMOVPD x: sem-vmaskmovp 64 x
   | VMASKMOVPS x: sem-vmaskmovp 32 x
   | VMAXPD x: sem-undef-varity x
   | VMAXPS x: sem-undef-varity x
   | VMAXSD x: sem-undef-varity x
   | VMAXSS x: sem-undef-varity x
   | VMINPD x: sem-undef-varity x
   | VMINPS x: sem-undef-varity x
   | VMINSD x: sem-undef-varity x
   | VMINSS x: sem-undef-varity x
   | VMOVAPD v:
       case v of
          VA2 x: sem-mov '1' x
       end
   | VMOVAPS v:
       case v of
          VA2 x: sem-mov '1' x
       end
   | VMOVD v:
       case v of
          VA2 x: sem-movzx '1' x
       end
   | VMOVDDUP x: sem-undef-varity x
   | VMOVDQA v:
       case v of
          VA2 x: sem-mov '1' x
       end
   | VMOVDQU v:
       case v of
          VA2 x: sem-mov '1' x
       end
   | VMOVHLPS x: sem-undef-varity x
   | VMOVHPD x: sem-undef-varity x
   | VMOVHPS x: sem-undef-varity x
   | VMOVLHPS x: sem-undef-varity x
   | VMOVLPD x: sem-undef-varity x
   | VMOVLPS x: sem-undef-varity x
   | VMOVMSKPD x: sem-undef-varity x
   | VMOVMSKPS x: sem-undef-varity x
   | VMOVNTDQ v:
       case v of
          VA2 x: sem-mov '1' x
       end
   | VMOVNTDQA v:
       case v of
          VA2 x: sem-mov '1' x
       end
   | VMOVNTPD x: sem-undef-varity x
   | VMOVNTPS x: sem-undef-varity x
   | VMOVQ v:
       case v of
          VA2 x: sem-movzx '1' x
       end
   | VMOVSD x: sem-undef-varity x
   | VMOVSHDUP x: sem-undef-varity x
   | VMOVSLDUP x: sem-undef-varity x
   | VMOVSS x: sem-undef-varity x
   | VMOVUPD x: sem-undef-varity x
   | VMOVUPS x: sem-undef-varity x
   | VMPSADBW x: sem-undef-varity x
   | VMULPD x: sem-undef-varity x
   | VMULPS x: sem-undef-varity x
   | VMULSD x: sem-undef-varity x
   | VMULSS x: sem-undef-varity x
   | VORPD x: sem-undef-varity x
   | VORPS x: sem-undef-varity x
   | VPABSB v:
       case v of
          VA2 x: sem-pabs '1' 8 x
       end
   | VPABSD v:
       case v of
          VA2 x: sem-pabs '1' 32 x
       end
   | VPABSW v:
       case v of
          VA2 x: sem-pabs '1' 16 x
       end
   | VPACKSSDW v:
       case v of
          VA3 x: sem-vpacksswb-vpackssdw 16 x
       end
   | VPACKSSWB v:
       case v of
          VA3 x: sem-vpacksswb-vpackssdw 8 x
       end
   | VPACKUSDW v:
       case v of
          VA3 x: sem-vpackuswb-vpackusdw 16 x
       end
   | VPACKUSWB v:
       case v of
          VA3 x: sem-vpackuswb-vpackusdw 8 x
       end
   | VPADDB v:
       case v of
          VA3 x: sem-vpadd 8 x
       end
   | VPADDD v:
       case v of
          VA3 x: sem-vpadd 32 x
       end
   | VPADDQ v:
       case v of
          VA3 x: sem-vpadd 64 x
       end
   | VPADDSB v:
       case v of
          VA3 x: sem-vpadds 8 x
       end
   | VPADDSW v:
       case v of
          VA3 x: sem-vpadds 16 x
       end
   | VPADDUSB v:
       case v of
          VA3 x: sem-vpaddus 8 x
       end
   | VPADDUSW v:
       case v of
          VA3 x: sem-vpaddus 16 x
       end
   | VPADDW v:
       case v of
          VA3 x: sem-vpadd 16 x
       end
   | VPALIGNR v:
       case v of
          VA4 x: sem-vpalignr x
       end
   | VPAND v:
       case v of
          VA3 x: sem-vpand x
       end
   | VPANDN v:
       case v of
          VA3 x: sem-vpandn x
       end
   | VPAVGB v:
       case v of
          VA3 x: sem-vpavg 8 x
       end
   | VPAVGW v:
       case v of
          VA3 x: sem-vpavg 16 x
       end
   | VPBLENDVB v:
       case v of
          VA4 x: sem-vpblendvb x
       end
   | VPBLENDW v:
       case v of
          VA4 x: sem-vpblendw x
       end
   | VPCLMULQDQ v:
       case v of
          VA4 x: sem-vpclmulqdq x
       end
   | VPCMPEQB v:
       case v of
          VA3 x: sem-vpcmpeq 8 x
       end
   | VPCMPEQD v:
       case v of
          VA3 x: sem-vpcmpeq 32 x
       end
   | VPCMPEQQ v:
       case v of
          VA3 x: sem-vpcmpeq 64 x
       end
   | VPCMPEQW v:
       case v of
          VA3 x: sem-vpcmpeq 16 x
       end
   | VPCMPESTRI x: sem-undef-varity x
   | VPCMPESTRM x: sem-undef-varity x
   | VPCMPGTB v:
       case v of
          VA3 x: sem-vpcmpgt 8 x
       end
   | VPCMPGTD v:
       case v of
          VA3 x: sem-vpcmpgt 32 x
       end
   | VPCMPGTQ v:
       case v of
          VA3 x: sem-vpcmpgt 64 x
       end
   | VPCMPGTW v:
       case v of
          VA3 x: sem-vpcmpgt 16 x
       end
   | VPCMPISTRI x: sem-undef-varity x
   | VPCMPISTRM x: sem-undef-varity x
   | VPERM2F128 x: sem-undef-varity x
   | VPERMILPD x: sem-undef-varity x
   | VPERMILPS x: sem-undef-varity x
   | VPEXTRB v:
       case v of
          VA3 x: sem-pextr-vpextr 8 x
       end
   | VPEXTRD v:
       case v of
          VA3 x: sem-pextr-vpextr 32 x
       end
   | VPEXTRQ v:
       case v of
          VA3 x: sem-pextr-vpextr 64 x
       end
   | VPEXTRW v:
       case v of
          VA3 x: sem-pextr-vpextr 16 x
       end
   | VPHADDD v:
       case v of
          VA3 x: sem-vphadd 32 x
       end
   | VPHADDSW v:
       case v of
          VA3 x: sem-vphaddsw x
       end
   | VPHADDW v:
       case v of
          VA3 x: sem-vphadd 16 x
       end
   | VPHMINPOSUW v:
       case v of
          VA2 x: sem-phminposuw-vphminposuw '1' x
       end
   | VPHSUBD v:
       case v of
          VA3 x: sem-vphsub 32 x 
       end
   | VPHSUBSW v:
       case v of
          VA3 x: sem-vphsubsw x 
       end
   | VPHSUBW v:
       case v of
          VA3 x: sem-vphsub 16 x 
       end
   | VPINSRB v:
       case v of
          VA4 x: sem-vpinsr 8 x 
       end
   | VPINSRD v:
       case v of
          VA4 x: sem-vpinsr 32 x 
       end
   | VPINSRQ v:
       case v of
          VA4 x: sem-vpinsr 64 x 
       end
   | VPINSRW v:
       case v of
          VA4 x: sem-vpinsr 16 x 
       end
   | VPMADDUBSW v:
       case v of
          VA3 x: sem-vpmaddubsw x 
       end
   | VPMADDWD v:
       case v of
          VA3 x: sem-vpmaddwd x 
       end
   | VPMAXSB v:
       case v of
          VA3 x: sem-vpmaxs 8 x 
       end
   | VPMAXSD v:
       case v of
          VA3 x: sem-vpmaxs 32 x 
       end
   | VPMAXSW v:
       case v of
          VA3 x: sem-vpmaxs 16 x 
       end
   | VPMAXUB v:
       case v of
          VA3 x: sem-vpmaxu 8 x 
       end
   | VPMAXUD v:
       case v of
          VA3 x: sem-vpmaxu 32 x 
       end
   | VPMAXUW v:
       case v of
          VA3 x: sem-vpmaxu 16 x 
       end
   | VPMINSB v:
       case v of
          VA3 x: sem-vpmins 8 x 
       end
   | VPMINSD v:
       case v of
          VA3 x: sem-vpmins 32 x 
       end
   | VPMINSW v:
       case v of
          VA3 x: sem-vpmins 16 x 
       end
   | VPMINUB v:
       case v of
          VA3 x: sem-vpminu 8 x 
       end
   | VPMINUD v:
       case v of
          VA3 x: sem-vpminu 32 x 
       end
   | VPMINUW v:
       case v of
          VA3 x: sem-vpminu 16 x 
       end
   | VPMOVMSKB v:
       case v of
          VA2 x: sem-pmovmskb-vpmovmskb '1' x
       end
   | VPMOVSXBD v:
       case v of
          VA2 x: sem-pmovsx-vpmovsx '1' 8 32 x
       end
   | VPMOVSXBQ v:
       case v of
          VA2 x: sem-pmovsx-vpmovsx '1' 8 64 x
       end
   | VPMOVSXBW v:
       case v of
          VA2 x: sem-pmovsx-vpmovsx '1' 8 16 x
       end
   | VPMOVSXDQ v:
       case v of
          VA2 x: sem-pmovsx-vpmovsx '1' 32 64 x
       end
   | VPMOVSXWD v:
       case v of
          VA2 x: sem-pmovsx-vpmovsx '1' 16 32 x
       end
   | VPMOVSXWQ v:
       case v of
          VA2 x: sem-pmovsx-vpmovsx '1' 16 64 x
       end
   | VPMOVZXBD v:
       case v of
          VA2 x: sem-pmovzx-vpmovzx '1' 8 32 x
       end
   | VPMOVZXBQ v:
       case v of
          VA2 x: sem-pmovzx-vpmovzx '1' 8 64 x
       end
   | VPMOVZXBW v:
       case v of
          VA2 x: sem-pmovzx-vpmovzx '1' 8 16 x
       end
   | VPMOVZXDQ v:
       case v of
          VA2 x: sem-pmovzx-vpmovzx '1' 32 64 x
       end
   | VPMOVZXWD v:
       case v of
          VA2 x: sem-pmovzx-vpmovzx '1' 16 32 x
       end
   | VPMOVZXWQ v:
       case v of
          VA2 x: sem-pmovzx-vpmovzx '1' 16 64 x
       end
   | VPMULDQ v:
       case v of
          VA3 x: sem-vpmuldq x
       end
   | VPMULHRSW v:
       case v of
          VA3 x: sem-vpmulhrsw x
       end
   | VPMULHUW v:
       case v of
          VA3 x: sem-vpmulhuw x
       end
   | VPMULHW v:
       case v of
          VA3 x: sem-vpmulhw x
       end
   | VPMULLD v:
       case v of
          VA3 x: sem-vpmull 32 x
       end
   | VPMULLW v:
       case v of
          VA3 x: sem-vpmull 16 x
       end
   | VPMULUDQ v:
       case v of
          VA3 x: sem-vpmuludq x
       end
   | VPOR v:
       case v of
          VA3 x: sem-vpor x
       end
   | VPSADBW v:
       case v of
          VA3 x: sem-vpsadbw x
       end
   | VPSHUFB v:
       case v of
          VA3 x: sem-vpshufb x
       end
   | VPSHUFD v:
       case v of
          VA3 x: sem-pshufd-vpshufd '1' x
       end
   | VPSHUFHW v:
       case v of
          VA3 x: sem-pshufhw-vpshufhw '1' x
       end
   | VPSHUFLW v:
       case v of
          VA3 x: sem-pshuflw-vpshuflw '1' x
       end
   | VPSIGNB v:
       case v of
          VA3 x: sem-vpsign 8 x
       end
   | VPSIGND v:
       case v of
          VA3 x: sem-vpsign 32 x
       end
   | VPSIGNW v:
       case v of
          VA3 x: sem-vpsign 16 x
       end
   | VPSLLD v:
       case v of
          VA3 x: sem-vpsll 32 x
       end
   | VPSLLDQ v:
       case v of
          VA3 x: sem-vpslldq x
       end
   | VPSLLQ v:
       case v of
          VA3 x: sem-vpsll 64 x
       end
   | VPSLLW v:
       case v of
          VA3 x: sem-vpsll 16 x
       end
   | VPSRAD v:
       case v of
          VA3 x: sem-vpsra 32 x
       end
   | VPSRAW v:
       case v of
          VA3 x: sem-vpsra 16 x
       end
   | VPSRLD v:
       case v of
          VA3 x: sem-vpsrl 32 x
       end
   | VPSRLDQ v:
       case v of
          VA3 x: sem-vpsrldq x
       end
   | VPSRLQ v:
       case v of
          VA3 x: sem-vpsrl 64 x
       end
   | VPSRLW v:
       case v of
          VA3 x: sem-vpsrl 16 x
       end
   | VPSUBB v:
       case v of
          VA3 x: sem-vpsub 8 x
       end
   | VPSUBD v:
       case v of
          VA3 x: sem-vpsub 32 x
       end
   | VPSUBQ v:
       case v of
          VA3 x: sem-vpsub 64 x
       end
   | VPSUBSB v:
       case v of
          VA3 x: sem-vpsubs 8 x
       end
   | VPSUBSW v:
       case v of
          VA3 x: sem-vpsubs 16 x
       end
   | VPSUBUSB v:
       case v of
          VA3 x: sem-vpsubus 8 x
       end
   | VPSUBUSW v:
       case v of
          VA3 x: sem-vpsubus 16 x
       end
   | VPSUBW v:
       case v of
          VA3 x: sem-vpsub 16 x
       end
   | VPTEST v:
       case v of
          VA2 x: sem-ptest-vptest x
       end
   | VPUNPCKHBW v:
       case v of
          VA3 x: sem-vpunpckh 8 x
       end
   | VPUNPCKHDQ v:
       case v of
          VA3 x: sem-vpunpckh 32 x
       end
   | VPUNPCKHQDQ v:
       case v of
          VA3 x: sem-vpunpckh 64 x
       end
   | VPUNPCKHWD v:
       case v of
          VA3 x: sem-vpunpckh 16 x
       end
   | VPUNPCKLBW v:
       case v of
          VA3 x: sem-vpunpckl 8 x
       end
   | VPUNPCKLDQ v:
       case v of
          VA3 x: sem-vpunpckl 32 x
       end
   | VPUNPCKLQDQ v:
       case v of
          VA3 x: sem-vpunpckl 64 x
       end
   | VPUNPCKLWD v:
       case v of
          VA3 x: sem-vpunpckl 16 x
       end
   | VPXOR v:
       case v of
          VA3 x: sem-vpxor x
       end
   | VRCPPS x: sem-undef-varity x
   | VRCPSS x: sem-undef-varity x
   | VROUNDPD x: sem-undef-varity x
   | VROUNDPS x: sem-undef-varity x
   | VROUNDSD x: sem-undef-varity x
   | VROUNDSS x: sem-undef-varity x
   | VRSQRTPS x: sem-undef-varity x
   | VRSQRTSS x: sem-undef-varity x
   | VSHUFPD x: sem-undef-varity x
   | VSHUFPS x: sem-undef-varity x
   | VSQRTPD x: sem-undef-varity x
   | VSQRTPS x: sem-undef-varity x
   | VSQRTSD x: sem-undef-varity x
   | VSQRTSS x: sem-undef-varity x
   | VSTMXCSR x: sem-undef-varity x
   | VSUBPD x: sem-undef-varity x
   | VSUBPS x: sem-undef-varity x
   | VSUBSD x: sem-undef-varity x
   | VSUBSS x: sem-undef-varity x
   | VTESTPD x: sem-undef-varity x
   | VTESTPS x: sem-undef-varity x
   | VUCOMISD x: sem-undef-varity x
   | VUCOMISS x: sem-undef-varity x
   | VUNPCKHPD x: sem-undef-varity x
   | VUNPCKHPS x: sem-undef-varity x
   | VUNPCKLPD x: sem-undef-varity x
   | VUNPCKLPS x: sem-undef-varity x
   | VXORPD x: sem-undef-varity x
   | VXORPS x: sem-undef-varity x
   | VZEROALL v: sem-vzeroall
   | VZEROUPPER v: sem-vzeroupper
   | WAIT x: sem-undef-arity0 x
   | WBINVD x: sem-undef-arity0 x
   | WRFSBASE x: sem-undef-arity1 x
   | WRGSBASE x: sem-undef-arity1 x
   | WRMSR x: sem-undef-arity0 x
   | XADD x: sem-xadd x
   | XCHG x: sem-xchg x
   | XGETBV x: sem-undef-arity0 x
   | XLATB x: sem-undef-arity0 x
   | XOR x: sem-xor x
   | XORPD x: sem-undef-arity2 x
   | XORPS x: sem-undef-arity2 x
   | XRSTOR x: sem-undef-arity1 x
   | XRSTOR64 x: sem-undef-arity1 x
   | XSAVE x: sem-undef-arity1 x
   | XSAVE64 x: sem-undef-arity1 x
   | XSAVEOPT x: sem-undef-arity1 x
   | XSAVEOPT64 x: sem-undef-arity1 x
   | XSETBV x: sem-undef-arity0 x
  end
#s/^ | \([^\s]*\) of \(arity\|flow\)\(.\)\s*/ | \1 x: sem-undef-\2\3 x/g
#s/^ | \([^\s]*\) of varity\s*/ | \1 x: sem-undef-varity x/g
#s/^ | \(\S*\)\s*$/ | \1: sem-undef-arity0/g
#s/\(.*\)| \(\S*\):.*/\1| \2 x: sem-undef-arity0 x/g

val translate insn =
   do update@{stack=SEM_NIL,tmp=0,lab=0,mode64='1'};
#case 0 of 1: return 0 end;
      semantics insn;
      stack <- query $stack;
      return (rreil-stmts-rev stack)
   end

val translate-bottom-up insn =
   do update@{stack=SEM_NIL,tmp=0,lab=0};
      semantics insn;
      stack <- query $stack;
      return stack
   end

val transInstr = do
   ic <- query $ins_count;
   update@{tmp=0,ins_count=ic+1};
   insn <- decode;
   semantics insn
end

val transBlock = do
   transInstr;
   jmp <- query $foundJump;
   #ic <- query $ins_count;
   #if jmp or ic>1000 then query $stack else transBlock
   if jmp then query $stack else transBlock
end

val translateBlock = do
   update @{ins_count=0,mode64='1'};
   update@{stack=SEM_NIL,foundJump='0'};
   # the type checker is seriously broken when it comes to infinite recursion,
   # I cannot as of yet reproduce this bug
   update @{ptrsz=0, reg/opcode='000', rm='000', mod='00', vexm='00001', vexv='0000', vexl='0', vexw='0'};
	 stmts <- transBlock;
   return (rreil-stmts-rev stmts)
end

type int_option =
   IO_SOME of int
 | IO_NONE

val io a b = {a=a,b=b}
val io-to a = {a=a,b=IO_NONE}
val io-tw a = {a=a,b=a}

val relative-next stmts = let
  val raddress addr =
	  case addr.address of
		   SEM_LIN_ADD s:
			   case s.opnd1 of
				    SEM_LIN_VAR v:
						  case v.id of
							   Sem_IP:
								   case s.opnd2 of
									    SEM_LIN_IMM i: IO_SOME i.imm
									  | _: IO_NONE
									 end
							 | _: IO_NONE
							end
				  | SEM_LIN_IMM i:
					    case s.opnd2 of
							   SEM_LIN_VAR v:
								   case v.id of
									    Sem_IP: IO_SOME i.imm
									  | _: IO_NONE
									 end
							 | _: IO_NONE
							end
				 end
		 | SEM_LIN_VAR v:
		     case v.id of
				    Sem_IP: IO_SOME 0
				  | _: IO_NONE
				 end
		 | _: IO_NONE
		end
in
  case stmts of
	   SEM_CONS x:
		   case x.hd of
			    SEM_CBRANCH b: io (raddress b.target-true) (raddress b.target-false)
				| SEM_BRANCH b: io-to (raddress b.target)
				| SEM_ITE c: io (relative-next (rreil-stmts-rev c.then_branch)).a (relative-next (rreil-stmts-rev c.else_branch)).a
			  | _: io-tw IO_NONE
			 end
	 | SEM_NIL: (io-tw IO_NONE)
	end
end

type stmts_option =
   SO_SOME of sem_stmts
 | SO_NONE

val translateSuperBlock = let
  val translate-block-at idx = do
	  current <- idxget;
		error <- rseek idx;
		result <- if error === 0 then do
		  stmts <- translateBlock;
		  seek current;
			return (SO_SOME stmts)
		end else
		  return SO_NONE
		;
		return result
  end

  val seek-translate-block-at idx-opt = do
	  case idx-opt of
		   IO_SOME i: translate-block-at i
		 | IO_NONE: return SO_NONE
		end
	end
in do
   update @{ins_count=0,mode64='1'};
   update@{stack=SEM_NIL,foundJump='0'};
   # the type checker is seriously broken when it comes to infinite recursion,
   # I cannot as of yet reproduce this bug
   update @{ptrsz=0, reg/opcode='000', rm='000', mod='00', vexm='00001', vexv='0000', vexl='0', vexw='0'};
	 stmts <- transBlock;

   succs <- return (relative-next stmts);
   succ_a <- seek-translate-block-at succs.a;
   succ_b <- seek-translate-block-at succs.b;

   return {insns=(rreil-stmts-rev stmts), succ_a=succ_a, succ_b=succ_b}
end end
