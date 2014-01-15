structure Environment : sig
   type environment

   structure SpanMap : ORD_MAP where type Key.ord_key = Error.span

   structure SymbolSet : ORD_SET where type Key.ord_key = SymbolTable.symid
   
   val primitiveEnvironment : (SymbolTable.symid *
                               Types.texp *
                               (BooleanDomain.bfun -> BooleanDomain.bfun) *
                               (Types.texp option)) list *
                               SizeConstraint.size_constraint list ->
                               environment
   
   val pushSingle : VarInfo.symid * Types.texp * environment -> environment
   
   (*add a group of bindings to the current environment, each element in a
   binding is identified by its symbol, the flag is true if the symbol
   is a decoder function*)
   val pushGroup : (VarInfo.symid * bool) list * environment ->
                  environment
   (*remove a binding group from the stack; the flag is true if the outermost
   scope should be kept, the result is a list of error messages about
   ambiguous type variables*)
   val popGroup : environment * bool ->
                  (Error.span * string) list * environment
   
   (*ask for all the symbols in the binding group*)
   val getGroupSyms : environment -> VarInfo.symid list
   
   val pushTop : environment -> environment
   
   (*pushes the given type onto the stack, if the flag is true, type variables
   are renamed*)
   val pushType : bool * Types.texp * environment -> environment

   val pushMonadType : Types.texp * environment -> environment
   
   (* push the width of a decode onto the stack*)
   val pushWidth : VarInfo.symid * environment -> environment

   (* For a function from a type containing several type variables to an
   algoebraic data type, generate implications from the arguments of the
   algebraic data type to the argument of this function. *)
   val genConstructorFlow : (bool * environment) -> environment
   
    (*given an occurrence of a symbol at a position, push its type onto the
    stack; arguments are the symbol to look up, the position it occurred and a
    Boolean flag indicating if this usage should be recorded (True) or if an
    existing type should be used (False), and a flag that indicates if
    a fresh instance or the plain type should be pushed *)
   val pushSymbol : VarInfo.symid * Error.span * bool * bool * environment -> environment

   (*search in the current stack for the symbol and, if unsuccessful, in the
   nested definitions and push all nested groups onto the stack, returns the
   new stack and the number of nested groups that had to be pushed*)
   val pushNested : VarInfo.symid * environment -> (int * environment)

   (*pops the nested groups that were pushed by pushNested*)
   val popNested : int * environment -> environment

   (*obtain a fresh temporary symbol*)
   val acquireTempSymbol : environment -> VarInfo.symid * environment
   val releaseTempSymbol : VarInfo.symid * environment -> environment
   
   val getUsages : VarInfo.symid * environment -> Error.span list
   
   val getContextOfUsage : VarInfo.symid * Error.span * environment ->
                           VarInfo.symid

   val getCtxt : environment -> VarInfo.symid list

      (*stack: [...,t] -> [...] and type of f for call-site s is set to t*)
   val popToUsage : VarInfo.symid * Error.span * environment -> environment

   (*stack: [...] -> [...,t] where t is type of usage of f at call-site s*)
   val pushUsage : VarInfo.symid * Error.span * environment -> environment
   
   (*stack: [...] -> [..., x:a], 'a' fresh; primed version also returns 'a'*)
   val pushLambdaVar' : VarInfo.symid * environment -> (Types.texp * environment)
   val pushLambdaVar : VarInfo.symid * environment -> environment
   
   (*stack: [..., t0, t1, ... tn] -> [..., {f1:t1, ... fn:tn, t0:...}]*)
   val reduceToRecord : (BooleanDomain.bvar * FieldInfo.symid) list *
                        environment -> environment

   (*stack: [..., tn, ..., t2, t1, t0] -> [..., SUM (tn,..t0)]*)
   val reduceToSum : int * environment -> environment
   
   (*stack: [...,t1,t2,...,tn] -> [...,(t1, ... t n-1) -> tn]*)
   val reduceToFunction : environment * int -> environment
   
   (*stack: [...,t1 -> t2] -> [...t2]*)
   val reduceToResult : environment -> environment

   (*stack: [...,t1 -> t2] -> [...t1]*)
   val reduceToArgument : environment -> environment

   (*stack: [..., tn, ..., t2, t1, t0] -> [..., t0]*)
   val return : int * environment -> environment

   val popKappa : environment -> environment

   (*stack: [..., t2, t1], meet t1=t2 for types and flow *)
   val equateKappas : environment -> environment

   (*stack: [..., t2, t1], meet t1=t2 for types and t2=>t1 for flow*)
   val equateKappasFlow : environment -> environment

   (*stack: [..., t2, t1] -> [..., t1, t2] *)
   val flipKappas : environment -> environment

   (*stack: [..., t1, t2], compute mgu(t1,t2) and return the set
     of substitutions for t1; this set is empty if t1 is smaller
     (more specific) than t2; when testing for stability t1 is
     the usage site and t2 the fresh function instance *)
   val subsetKappas : environment -> Substitutions.Substs

   (*stack: [...,t] -> [...] and type of function f is set to t*)
   val popToFunction : VarInfo.symid * environment -> environment

   (*push the name of the function into the current context (the context
   determines in which function calls to unknown functions are recorded)*)
   val enterFunction : VarInfo.symid * environment -> environment

   (*pop the last function from the current context*)
   val leaveFunction : VarInfo.symid * environment -> environment
   
   (*unset the type of function f if possible; if the function type was set,
   return an environment in which the function type was pushed, otherwise
   return nothing*)
   val clearFunction : VarInfo.symid * environment -> environment option
   
   val forceNoInputs : VarInfo.symid * VarInfo.symid list *
                     environment -> VarInfo.symid list

    (*apply the Boolean function*)
   val meetBoolean : (BooleanDomain.bfun -> BooleanDomain.bfun) *
         environment -> environment

   val reduceFlow :  environment -> environment

   val meetSizeConstraint : (SizeConstraint.size_constraint_set ->
                             SizeConstraint.size_constraint_set) *
                             environment -> environment

   (*query all function symbols in binding groups that would be modified by
   the given substitutions*)
   val affectedFunctions : Substitutions.Substs * environment -> SymbolSet.set

   val toString : environment -> string
   val toStringSI : environment * TVar.varmap -> string * TVar.varmap
   val topToString : environment -> string
   val topToStringSI : environment * TVar.varmap -> string * TVar.varmap
   val kappaToString : environment -> string
   val kappaToStringSI : environment * TVar.varmap -> string * TVar.varmap
   val funTypeToStringSI  : environment * VarInfo.symid * TVar.varmap ->
                            string * TVar.varmap
end = struct
   structure ST = SymbolTable
   structure BD = BooleanDomain
   structure SC = SizeConstraint
   structure TT = TypeTable
   structure SpanMap = SpanMap
   open Types
   open Substitutions

   type kappa = ST.symid

   (*restrict which symbols toString prints*)
   val debugSymbol : int option = NONE

   (*any error that is not due to unification*)
   exception InferenceBug
   
   datatype binding
      = KAPPA of {
         kappa : kappa
      } | SINGLE of {
         name : ST.symid
      } | GROUP of {
         name : ST.symid,
         (* true if the type of this function is known*)
         ty : bool,
         (*this is SOME (CONST w) if this is a decode function with pattern width w*)
         width : texp option,
         uses : (kappa * ST.symid) SpanMap.map,
         (*a tree of nested binding groups*)
         nested : binding list
      } list
   
   datatype bind_info
      = SIMPLE
      | COMPOUND of { ty : bool, width : texp option,
                      uses : (kappa * ST.symid) SpanMap.map,
                      nested : binding list }

   structure Scope : sig
      type scopes = binding list
      type constraints

      type environment = scopes * constraints

      val acquireKappa : environment -> VarInfo.symid * environment
      val releaseKappa : VarInfo.symid * environment -> environment
      
      val getCurFun : environment -> VarInfo.symid
      val setCtxt : VarInfo.symid list -> environment -> environment
      val getCtxt : environment -> VarInfo.symid list
      
      val getTypeTable : environment -> TypeTable.table
      val initial : binding * SC.size_constraint_set * TypeTable.table -> environment
      val wrap : binding * environment -> environment
      val unwrap : environment -> (binding * environment)
      val lookup : ST.symid * environment -> SymSet.set * bind_info
      val update : ST.symid  *
                   (bind_info * constraints -> bind_info * constraints) *
                   environment-> environment
      val toString : binding * TT.table * TVar.varmap -> string * TVar.varmap
   end = struct
      type scopes = binding list

      type constraints = {
         context : VarInfo.symid list,
         typeTable : TT.table,
         kappas : VarInfo.symid list,
         kappaCount : int
      }

      type environment = scopes * constraints
   
      fun acquireKappa (scs,{ context = ctxt, typeTable = ti, kappas = [], kappaCount = kc }) =
         let
            val st = !SymbolTables.varTable
            val (st, kappaSym) = SymbolTable.fresh (st,Atom.atom ("kappa" ^ Int.toString kc))
            val _ = SymbolTables.varTable := st
         in
            (kappaSym, (scs,{ context = ctxt, typeTable = ti, kappas = [], kappaCount = kc+1 }))
         end
        | acquireKappa (scs,{ context = ctxt, typeTable = ti, kappas = k::ks, kappaCount = kc }) =
         (k, (scs,{ context = ctxt, typeTable = ti, kappas = ks, kappaCount = kc }))
      fun releaseKappa (k,(scs,{ context = ctxt, typeTable = ti, kappas = ks, kappaCount = kc })) =
         (scs, { context = ctxt, typeTable = ti, kappas = k::ks, kappaCount = kc })

      fun getCurFun (scs,{ context = ctxt, typeTable, kappas, kappaCount = kc }) =
         case ctxt of
              (curFun :: _) => curFun
            | [] => raise InferenceBug
      fun setCtxt ctxt (scs,{ context = _, typeTable = tt, kappas = ks, kappaCount = kc }) =
         (scs,{ context = ctxt, typeTable = tt, kappas = ks, kappaCount = kc })
      fun getCtxt (_,{ context = ctxt, typeTable, kappas, kappaCount }) = ctxt

      fun getTypeTable (_,{ context, typeTable = tt, kappas, kappaCount }) = tt
      fun initial (b, scs, tt) =
         ([b], {
            context = [],
            typeTable = TT.modifySizes (fn scs' => SC.merge (scs,scs'), tt),
            kappas = [],
            kappaCount = 0
          })
      fun wrap (b, (scs, state)) = (b::scs,state)
      fun unwrap (bi :: scs, state) = (bi, (scs, state))
        | unwrap ([], state) = raise InferenceBug

      fun lookup (sym, (scs, cons) : environment) =
         let    
            fun l (ss, []) =
                  (TextIO.print ("urk, tried to lookup non-existent symbol " ^ Int.toString (SymbolTable.toInt sym) ^ ": " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^ "\n")
                  ;raise InferenceBug)
              | l (ss, KAPPA {kappa}::scs) = l (ss, scs)
              | l (ss, SINGLE {name}::scs) =
                  if ST.eq_symid (sym,name) then (ss,SIMPLE) else l (SymSet.add (ss,name), scs)
              | l (ss, GROUP bs::scs) =
                  let fun lG other [] = l (SymSet.empty, scs)
                        | lG other ((b as {name, ty, width, uses, nested})::bs) =
                           if ST.eq_symid (sym,name) then
                              (ss, COMPOUND { ty = ty, width = width, uses = uses, nested = nested })
                           else lG (b :: other) bs
                  in
                     lG [] bs                     
                  end
      
         in
            l (SymSet.empty, scs)
         end

      fun update (sym, action, env) =
         let
            fun tryUpdate (KAPPA _, cons) = NONE
              | tryUpdate (SINGLE {name}, cons) =
                if ST.eq_symid (sym,name) then
                  let
                     val (SIMPLE, cons) = action (SIMPLE, cons)
                  in
                     SOME (SINGLE {name = name}, cons)
                  end
                else NONE
              | tryUpdate (GROUP bs, cons) =
               let fun upd (otherBs, []) = NONE
                     | upd (otherBs, (b as {name, ty, width, uses, nested})::bs) =
                        if ST.eq_symid (sym,name) then
                           let val (COMPOUND { ty = ty, width = width,
                                               uses = uses, nested = nested}, cons) =
                                   action (COMPOUND { ty = ty, width = width,
                                                      uses = uses, nested = nested}, cons)
                           in
                              SOME (GROUP (List.revAppend (otherBs,
                                          {name = name, ty = ty,
                                           width = width, uses = uses,
                                           nested = nested} :: bs))
                                   ,cons)
                           end
                        else upd (b::otherBs, bs)
               in
                  upd ([],bs)
               end
            fun unravel (bs, ([],_)) = raise InferenceBug
              | unravel (bs, env) = case unwrap env of
               (b, env as (scs, cons)) =>
                  (case tryUpdate (b, cons) of
                       NONE => unravel (b::bs, env)
                     | SOME (b,cons) => List.foldl wrap (scs, cons) (b::bs) )
         in
            unravel ([], env)
         end

      fun showVarsVer (typeVars,boolVars,ver,si) =
         let
            val (vsStr, si) = TVar.setToString (typeVars,si)
            val bsStr = BD.setToString boolVars
         in
            ("ver=" ^ Int.toString(ver) ^
             ", bvars = " ^ bsStr ^  ", vars=" ^ vsStr ^ "\n", si)
         end

      and toString (KAPPA {kappa}, tt, si) =
            let
               val ty = TT.getSymbol (kappa,tt)
               val _ = TT.addSymbol (kappa,ty,tt)
               val (tStr, si) = showTypeSI (ty,si)
            in
               case debugSymbol of
                  (SOME _) => ("",si)
                | NONE => ("KAPPA : " ^ tStr, si)
            end
        | toString (SINGLE {name}, tt, si) =
            let
               val ty = TT.getSymbol (name,tt)
               val _ = TT.addSymbol (name,ty,tt)
               val (tStr, si) = showTypeSI (ty,si)
               val visible = case debugSymbol of
                     NONE => true
                   | (SOME sid) => sid=SymbolTable.toInt name
            in
               if visible then
                  ("SYMBOL " ^ ST.getString(!SymbolTables.varTable, name) ^
                  " : " ^ tStr, si)
               else
                  ("",si)
            end
        | toString (GROUP bs, tt, si) =
            let
               fun prTyOpt (NONE, str, si) = ("", si)
                 | prTyOpt (SOME t, str, si) = let
                    val (tStr, si) = showTypeSI (t, si)
                 in
                     (str ^ tStr, si)
                 end
               fun prBTyOpt (false, sym, str, si) = ("", si)
                 | prBTyOpt (true, sym, str, si) = let
                    val ty = TT.getSymbol (sym,tt)
                    val _ = TT.addSymbol (sym,ty,tt)
                    val (tStr, si) = showTypeSI (ty, si)
                     val vs = texpBVarset (fn ((_,v),vs) => BD.addToSet (v,vs)) (ty,BD.emptySet)
                     val bStr = if concisePrint then "" else
                                 ", flow:" ^ BD.showBFunPart (vs, TT.getFlow tt)
                     val vs = texpVarset (ty,TVar.empty)
                     val (sStr,si) = SC.toStringSI (TT.getSizes tt,SOME vs,si)
                 in
                     (str ^ tStr ^ bStr ^ sStr, si)
                 end
               fun printU (({span=(p1,p2),file=_}, (kappa, ctxt)), (str, sep, si)) =
                  let
                     val ty = TT.getSymbol (kappa,tt)
                    val _ = TT.addSymbol (kappa,ty,tt)
                     val (tStr, si) = showTypeSI (ty, si)
                  in
                     (str ^
                      sep ^ Int.toString(Position.toInt p1) ^
                      "-" ^ Int.toString(Position.toInt p2) ^
                      "@" ^ ST.getString(!SymbolTables.varTable, ctxt) ^
                      ":" ^ tStr
                     ,"\n\tuse at ", si)
                  end
               fun printB ({name,ty,width,uses,nested}, (str, si)) =
                  let
                     val visible = case debugSymbol of
                           NONE => true
                         | (SOME sid) => sid=SymbolTable.toInt name
                     val (tStr, si) = prBTyOpt (ty, name, " : ", si)
                     val (wStr, si) = prTyOpt (width, ", width = ", si)
                     val (uStr, _, si) = 
                           List.foldl printU ("", "\n\tuse at ", si)
                                      (SpanMap.listItemsi uses)
                     fun showBindInfosSI n (b :: bs,si) =
                        let
                           val (bStr, si) = toString (b,tt,si)
                           fun spaces n = if n<=0 then "" else "  " ^ spaces (n-1)
                           val sStr = spaces n
                           val (bsStr, si) = showBindInfosSI (n+1) (bs, si)
                           val fs1 = Substring.fields (fn c => c= #"\n") (Substring.full bStr)
                           val fs2 = Substring.fields (fn c => c= #"\n") (Substring.full bsStr)
                        in
                           (List.foldl
                              (fn (f,str) => str ^ sStr ^ Substring.string f ^ "\n")
                              "\n" (fs1 @ fs2),
                            si)
                        end
                       | showBindInfosSI n ([], si) = ("", si)
                     val (nStr, si) = showBindInfosSI 1 (nested,si)
                  in
                    if not visible then (str, si) else
                    (str ^
                     "\n  " ^ ST.getString(!SymbolTables.varTable, name) ^
                     tStr ^ wStr ^ nStr ^ uStr
                    ,si)
                  end
                val (bsStr, si) = List.foldr printB ("", si) bs
            in
               ("GROUP" ^ bsStr, si)
            end
               
   end
   
   exception Unimplemented

   type environment = Scope.environment

   fun toStringSI (env,si) = 
      let
         val tt = Scope.getTypeTable env
         (*val (ttStr, si) = TypeTable.toStringSI (fn _ => true, tt, si)*)
         fun showCons (s, (str, si)) =
            let
               val (bStr, si) = Scope.toString (s, tt, si)
            in
               (bStr ^ "\n" ^ str, si)
            end
         val (sStr, si) = SC.toStringSI (TypeTable.getSizes tt, NONE, si)
         val (envConsStr, si) = List.foldr showCons ("", si) (#1 env)
         fun showCtxt [] = "top level"
           | showCtxt [f] = ST.getString(!SymbolTables.varTable, f)
           | showCtxt (f::fs) = showCtxt [f] ^ ";" ^ showCtxt fs
      in
         ("environment at " ^ showCtxt (Scope.getCtxt env) ^ "\n" ^
          envConsStr ^ "\n", si)
      end

   fun toString env =
      let
         val (str, _) = toStringSI (env,TVar.emptyShowInfo)
      in
         str
      end
   
   fun topToStringSI ((scs, state), si) =
        toStringSI (((List.rev (List.drop (List.rev scs, 2))), state), si)

   fun topToString env =
      let
         val (str, _) = topToStringSI (env,TVar.emptyShowInfo)
      in
         str
      end

   fun kappaToStringSI (env, si) = raise Unimplemented
(* (case Scope.unwrap env of
        (KAPPA {ty = t}, _) =>
         let
            val (tStr, si) = showTypeSI (t,si)
         in
            (tStr ^ "\n", si)
         end
      | _ => raise InferenceBug
   )
*)
   fun kappaToString env =
      let
         val (str, _) = kappaToStringSI (env,TVar.emptyShowInfo)
      in
         str
      end

   fun funTypeToStringSI (env, f, si) = raise Unimplemented
(*  (case Scope.lookup (f,env) of
        (_, COMPOUND { ty = SOME (t,_), width, uses, nested }) =>
            showTypeSI (t,si)
      | _ => raise InferenceBug
   )
*)
   fun primitiveEnvironment (l,scs) = Scope.initial
      (GROUP (List.map (fn (s,t,bFunGen,ow) =>
         {name = s, ty = true,
          width = ow, uses = SpanMap.empty, nested = []}) l),
       scs,
       List.foldl (fn ((s,t,bFunGen,ow),tt) =>
         (TT.addSymbol (s,t,tt); TT.modifyFlow (bFunGen,tt); tt)
         ) TT.emptyTable l
       )
   
   fun pushSingle (sym, t, env) = raise Unimplemented
(*  Scope.wrap (SINGLE {name = sym, ty = t},env)
*)
   structure SymbolSet = RedBlackSetFn (
      struct
         type ord_key = SymbolTable.symid
         val compare = SymbolTable.compare_symid
      end)
          
   fun pushGroup (syms, env) =
      let
         val (funs, nonFuns) = List.partition (fn (s,dec) => not dec) syms
         val funDefs = List.map
            (fn (s,_) => {name = s, ty = false, width = NONE,
                          uses = SpanMap.empty, nested = []})
            funs
         val nonFunSyms =
            SymbolSet.listItems (SymbolSet.fromList (List.map (fn (s,_) => s) nonFuns))
         val nonFunDefs = List.map
            (fn s => {name = s, ty = false, width =
              SOME (VAR (TVar.freshTVar (), BD.freshBVar ())),
              uses = SpanMap.empty, nested = []}) nonFunSyms
      in                                                                    
         Scope.wrap (GROUP (funDefs @ nonFunDefs), env)
      end                                    

   fun popGroup (env, true) = raise Unimplemented
(*  (case Scope.unwrap env of
        (KAPPA {ty=t}, env) =>
         let
           val (badUses, env) = popGroup (env, false)
         in
            (badUses, Scope.wrap (KAPPA {ty=t}, env))
         end
       | _ => raise InferenceBug)
*)     | popGroup (env, false) = raise Unimplemented
(* case Scope.unwrap env of
        (GROUP bs, env) =>
         let
            val remVars = Scope.getVars env
            val (scs, state) = env
            (*figure out if there are any function usages that have unresolved
            type variables that relate to sizes*)
            val curVars = SC.getVarset (Scope.getSize state)
            val unbounded = TVar.difference (curVars,remVars)
            (*val _ = TextIO.print ("unbounded vars: " ^ #1 (TVar.setToString (unbounded,TVar.emptyShowInfo)) ^ "\n")*)
            val siRef = ref TVar.emptyShowInfo
            fun showUse (n, (ctxt,t)) =
               let
                  val nStr = SymbolTable.getString(!SymbolTables.varTable, n)
                  val (tStr, si) = showTypeSI (t, !siRef)
                  val vs = texpVarset (t,TVar.empty)
                  val (cStr, si) = SC.toStringSI (Scope.getSize state, SOME vs, si)
               in
                  (siRef := si
                  ; nStr ^ " : call to " ^ tStr ^ " has ambiguous vector sizes" ^
                     (if String.size cStr=0 then "" else " where " ^ cStr))
               end
            fun remBoundVars ({name,ty=SOME (t,_),width,uses,nested=ns},vs) =
                  List.foldl remBoundVars 
                     (TVar.difference (vs, texpVarset (t,TVar.empty)))
                     (List.concat (List.map (fn g => case g of
                          GROUP bs => bs
                        | _ => raise InferenceBug) ns))
              | remBoundVars (_,vs) = vs
            val unbounded = List.foldl remBoundVars unbounded bs
            (*TODO: we should also descend into the nested definitions,
            since the letrec expression cannot report ambigueties since
            when letrec groups are popped, the fixpoint has not been
            calculated yet*)
            val badSizes = List.concat (
               List.map (fn {name = n,ty,width,uses = us,nested} =>
                  List.map (fn (sp,t) => (sp, showUse (n, t))) (
                     SpanMap.listItemsi (
                        SpanMap.filter (fn (_,t) =>
                           not (TVar.isEmpty (TVar.intersection
                              (texpVarset (t,TVar.empty), unbounded)))
                           ) us))) bs)
            (*project out variables from the size and Boolean domains that are
            no longer needed*)
            val sCons = SC.filter (remVars, Scope.getSize state)
            val env = (scs, Scope.setSize sCons state)
            
            (*in case we are inside a function, store this group in the nested
            field of the function entry*)
            val bs = if List.null (Scope.getCtxt state) then [] else bs
            (* the following filters out those functions that aren't needed;
              however, it is too aggressive as certain functions that are
              defined in the "in" part of a let may reference a function of
              the let body but are not visible *)
            (*val inScope = SymSet.fromList (Scope.getCtxt state)
            val _ = TextIO.print ("popGroup: in scope are " ^ List.foldl (fn (s,acc) => SymbolTable.getString(!SymbolTables.varTable, s) ^ ", " ^ acc) "" (Scope.getCtxt state) ^ "\n")
            val _ = TextIO.print ("popGroup: group symbols are " ^ List.foldl (fn ({name, ty, width, uses, nested},acc) => SymbolTable.getString(!SymbolTables.varTable, name) ^ ", " ^ acc) "" bs ^ "\n")
            val bs = List.filter
                        (fn {name, ty, width, uses = us, nested} =>
                           (if SymbolTable.toInt name=1630 then TextIO.print ("usages of conv-mem are " ^ List.foldl (fn ((name,_),acc) => SymbolTable.getString(!SymbolTables.varTable, name) ^ ", " ^ acc) "" (SpanMap.listItems us) ^ " with " ^ Int.toString (List.length nested) ^ " nested\n") else ();
                           List.exists (fn (f,_) => SymSet.member (inScope,f))
                              (SpanMap.listItems us) )
                        ) bs*)
            fun action group (COMPOUND {ty, width, uses, nested},cons) =
               (COMPOUND {ty = ty, width = width,
                uses = uses, nested = group :: nested}, cons)
              | action ns _ = raise InferenceBug
            val env = if List.null bs then env else
               Scope.update (Scope.getCurFun state, action (GROUP bs), env)
            (*val _ = if not (List.null bs) then
                    TextIO.print ("popGroup, updating " ^ SymbolTable.getString(!SymbolTables.varTable, Scope.getCurFun state) ^
                              " to contain group " ^ List.foldl (fn ({name, ty, width, uses, nested},acc) => SymbolTable.getString(!SymbolTables.varTable, name) ^ ", " ^ acc) "" bs ^ "\n" ^ topToString env)
                    else ()*)
         in
            (badSizes, env)
         end
      | _ => raise InferenceBug
*)
   fun getGroupSyms env = raise Unimplemented
(*  case Scope.unwrap env of
        (GROUP bs, env) => List.map #name bs
      | _ => raise InferenceBug
*)
   fun pushTop env =
      let
         val tt = Scope.getTypeTable env
         val (k,env) = Scope.acquireKappa env
         val _ = TT.addSymbol (k,VAR (TVar.freshTVar (), BD.freshBVar ()), tt)
      in
         Scope.wrap (KAPPA {kappa = k}, env)
      end

   fun pushType (true, t, env) =
      let
         val tt = Scope.getTypeTable env
         val (kProto,env) = Scope.acquireKappa env
         val (k,env) = Scope.acquireKappa env
         val _ = TT.addSymbol (kProto,t,tt)
         val _ = TT.addSymbol (k,VAR (TVar.freshTVar (), BD.freshBVar ()), tt)
         val _ = TT.instantiateSymbol (kProto,SymSet.empty,k,tt)
         val _ = TT.delSymbol (kProto,tt)
         val env = Scope.releaseKappa (kProto,env)
      in
         Scope.wrap (KAPPA {kappa = k}, env)
      end
     | pushType (false, t, env) =
      let
         val (k,env) = Scope.acquireKappa env
         val _ = TT.addSymbol (k,t,Scope.getTypeTable env)
      in
         Scope.wrap (KAPPA {kappa = k}, env)
      end

   fun pushMonadType (t, (scs, state)) = raise Unimplemented
(* 
      let
         val tvar = TVar.freshTVar ()
         val fromBVar = BD.freshBVar ()
         val toBVar = BD.freshBVar ()
         val fromVar = VAR (tvar, fromBVar)
         val toVar = VAR (tvar, toBVar)
         val bFun = BD.meetVarImpliesVar (fromBVar, toBVar) (Scope.getFlow state)
         val (t,bFun,sCons) = instantiateType (texpVarset(t,TVar.empty),t,
                                               TVar.empty,
                                               bFun,
                                               Scope.getSize state)
      in
         Scope.wrap (KAPPA {ty = MONAD (t, fromVar, toVar)},
                     (scs, Scope.setSize sCons (Scope.setFlow bFun state)))
      end
*)
   fun pushWidth (sym, env) = raise Unimplemented
(* 
      (case Scope.lookup (sym,env) of
          (_, COMPOUND {ty, width = SOME t, uses, nested}) =>
            Scope.wrap (KAPPA {ty = t}, env)
        | _ => raise (UnificationFailure (Clash,
            SymbolTable.getString(!SymbolTables.varTable, sym) ^
            " is not a decoder"))
      )
*)
   exception LookupNeedsToAddUse

   fun eq_span ((p1s,p1e), (p2s,p2e)) =
      Position.toInt p1s=Position.toInt p2s andalso
      Position.toInt p1e=Position.toInt p2e

   fun reduceBooleanFormula (sym,t,setType,reduceToMono,env) = raise Unimplemented
(* 
      let
         (*we need to restrict the size of the Boolean formula in two
         ways: first, for the function we need all Boolean variables
         in its type, all lambda- and kappa-bound types in the
         environment as well as all the uses of other functions that
         occur in it; secondly, the analysis must continue with a
         Boolean formula that contians the Boolean variables of all
         lambda- and kappa-bound types in the environment. Since the
         latter is usually an empty environment (namely for all
         top-level functions), we first calculate the set of Boolean
         variables in kappa- and lambda-bound types and use that for
         the Boolean formula of the function; then we project onto
         the variables in kappa- and lambda-bound types*)
         val texpBVarset = texpBVarset (fn ((_,v),vs) => BD.addToSet (v,vs))

         val (monoTVars, monoBVars) = Scope.getMonoVars env
         val (usesTVars, usesBVars) = Scope.getVarsUses (sym, env)
         val funBVars = texpBVarset (t,
                           BD.union (monoBVars, usesBVars))
                           
         val (scs, state) = env
         val bFun = BD.projectOnto (funBVars,Scope.getFlow state)
         val bFunRem = if reduceToMono then BD.projectOnto (monoBVars,bFun)
                       else bFun
         (*val _ = TextIO.print ("projecting for " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^ ": " ^ showType t ^ " where \n" ^ toString env)*)
         val groupTVars = texpVarset (t,Scope.getVars env)
         val sCons = SC.filter (groupTVars, Scope.getSize state)
         val state = Scope.setSize sCons (Scope.setFlow bFunRem state)
         val env = Scope.update (sym, setType (t,bFun), (scs, state))
      in
         env
      end
*)
   fun affectedFunctions (substs, env) = raise Unimplemented
(* 
      let
         fun aF (ss, substs, ([], _)) = ss
           | aF (ss, substs, env) =
               if isEmpty substs then ss else aFB ss (Scope.unwrap env)
         and aFB ss (GROUP l,env) =
            let
               fun aFL (ss, []) =
                   aF (ss, substsFilter (substs, Scope.getVars env), env)
                 | aFL (ss, {name = n, ty, width, uses = us, nested = ns} :: l) =
                     List.foldl (fn (b,ss) => aFB ss (b,env))
                     (if List.all (fn (_,t) => isEmpty
                              (substsFilter (substs, texpVarset (t,TVar.empty))))
                           (SpanMap.listItems us)
                     then aFL (ss, l)
                     else aFL (SymbolSet.add' (n, ss), l)
                     ) ns
            in
               aFL (ss, l)
            end
           | aFB ss (_, env) =
               aF (ss, substsFilter (substs, Scope.getVars env), env)
      in
         aF (SymbolSet.empty, substs, env)
      end
*)
   fun affectedField (bVars, env as (scs,state)) = raise Unimplemented
(* 
      let
         fun aF (_, SOME f) = SOME f
           | aF (([],_), NONE) = NONE
           | aF (env, NONE) = case Scope.unwrap env of
              (KAPPA {ty = t}, env) =>
               aF (env, fieldOfBVar (bVars, t))
            | (SINGLE {name, ty = t}, env) => aF (env, fieldOfBVar (bVars, t))
            | (GROUP l, env) =>
            let
               fun findField ((_,t), SOME f) = SOME f
                 | findField ((_,t), NONE) = fieldOfBVar (bVars, t)
               fun aFL {name, ty = tOpt, width, uses, nested} =
                  List.foldl findField
                     (case tOpt of
                          NONE => NONE
                        | SOME (t,_) => fieldOfBVar (bVars, t))
                     (SpanMap.listItems uses)
            in
               aF (env, case List.mapPartial aFL l of
                       [] => NONE
                     | (f :: _) => SOME f)
            end
      in
         aF (env, NONE)
      end
*)
   fun flowError (bVars, fOpt, env) =
      let
         val tt = Scope.getTypeTable env
         val fStr = case TT.affectedField (bVars, tt) of
                 NONE => "some field"
               | SOME f => "field " ^
                  SymbolTable.getString(!SymbolTables.fieldTable, f)
         val fStr = if Types.concisePrint then fStr else
                    fStr ^ " with vars " ^ BD.setToString bVars
      in
         raise UnificationFailure (Clash, fStr ^ " may not be present")
      end

   fun meetBoolean (update, env) =
      (TT.modifyFlow (update, Scope.getTypeTable env); env)
         handle (BD.Unsatisfiable bVars) => flowError (bVars, NONE, env)

   fun reduceFlow env = env

   fun meetSizeConstraint (update, (scs, state)) = raise Unimplemented
(* 
      (scs, Scope.setSize (update (Scope.getSize state)) state)
*)
   fun genConstructorFlow (contra, env) =
      case Scope.unwrap env of
        (KAPPA {kappa=k}, _) =>
         let
            val tt = Scope.getTypeTable env
            val (t,vs) = case TT.peekSymbol (k,tt) of
               FUN ([t], ALG (_,vs)) => (t,vs)
             | _ => raise InferenceBug
               
            val dtVars = List.map (fn v => case v of
                             VAR p => p
                           | _ => raise InferenceBug) vs
            val flow = texpConstructorFlow dtVars contra t
            val _ = TT.modifyFlow (fn bFun => BD.meet (flow,bFun), tt)
         in
            env
         end
      | _ => raise InferenceBug

   fun pushSymbol (sym, span, recordUsage, createInstance, env) =
      (
      if SOME (SymbolTable.toInt sym)=debugSymbol then
         TextIO.print ("pushSymbol debug symbol:\n" ^ toString env) else ();
      case Scope.lookup (sym,env) of
          (_, SIMPLE) =>
         let
            val (k,env) = Scope.acquireKappa env
            val tt = Scope.getTypeTable env
            val _ = TT.addSymbol (k, VAR (TVar.freshTVar (), BD.freshBVar ()), tt)
            val _ = TT.equateSymbolsFlow (k,sym,tt)
            val env = Scope.wrap (KAPPA {kappa = k}, env)
         in
            env
         end
        | (ss, COMPOUND {ty = true, width = w, uses, nested}) =>
         let
            val (k,env) = Scope.acquireKappa env
            val tt = Scope.getTypeTable env
            val _ = if createInstance then
                  TT.instantiateSymbol (sym,ss,k,tt)
               else
                  (TT.addSymbol (k, VAR (TVar.freshTVar (), BD.freshBVar ()), tt)
                  ;TT.equateSymbolsFlow (k,sym,tt))
            val decVars = case w of
                 SOME t => texpVarset (t,TVar.empty)
               | NONE => TVar.empty
            (*we need to record the usage sites of all functions (primitives,
            really) that have explicit size constraints in order to be able
            to later generate error messages for ambiguous uses of these
            functions*)
            fun action kUsage (COMPOUND {ty, width, uses, nested},cons) =
               (COMPOUND {ty = ty, width = width,
                uses = SpanMap.insert (uses, span, (Scope.getCurFun env, kUsage)),
                nested = nested}, cons)
              | action kUsage _ = raise InferenceBug
            val env =
               if not recordUsage andalso
                  TVar.isEmpty (TVar.intersection (decVars, SC.getVarset (TT.getSizes tt)))
               then env
               else
                  let
                     val (kUsage,env) = Scope.acquireKappa env
                     val _ = TT.addSymbol (kUsage, VAR (TVar.freshTVar (), BD.freshBVar ()), tt)
                     val _ = TT.equateSymbols (k,kUsage,tt)
                  in
                     Scope.update (sym, action kUsage, env)
                  end
         in
            Scope.wrap (KAPPA {kappa = k}, env)
         end
        | (_, COMPOUND {ty = false, width, uses, nested}) =>
          (case SpanMap.find (uses, span) of
               SOME (_,kUsage) =>
                let
                  val (k,env) = Scope.acquireKappa env
                  val tt = Scope.getTypeTable env
                  val _ = TT.addSymbol (k, VAR (TVar.freshTVar (), BD.freshBVar ()), tt)
                  val _ = TT.equateSymbols (k,kUsage,tt)
                in
                   Scope.wrap (KAPPA {kappa = k}, env)
                end
             | NONE =>
               let
                  val (k,env) = Scope.acquireKappa env
                  val (kUsage,env) = Scope.acquireKappa env
                  val tt = Scope.getTypeTable env
                  val _ = TT.addSymbol (k, VAR (TVar.freshTVar (), BD.freshBVar ()), tt)
                  val _ = TT.addSymbol (kUsage, VAR (TVar.freshTVar (), BD.freshBVar ()), tt)
                  val _ = TT.equateSymbols (k,kUsage,tt)
                  fun action (COMPOUND {ty, width, uses, nested},cons) =
                        (COMPOUND {ty = ty, width = width,
                        uses = SpanMap.insert (uses, span, (Scope.getCurFun env,kUsage)),
                        nested = nested}, cons)
                    | action _ = raise InferenceBug
                    val env = Scope.update (sym, action, env)
                    (*val _ = TextIO.print ("added usage for " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^ " with state " ^ #1 (TVar.setToString (Scope.getVars env,TVar.emptyShowInfo)) ^ "\n")*)
               in
                  Scope.wrap (KAPPA {kappa = k}, env)
               end
          )
      )
    
   fun acquireTempSymbol env = Scope.acquireKappa env
   fun releaseTempSymbol kEnv = Scope.releaseKappa kEnv

   fun getUsages (sym, env) = raise Unimplemented
(*  (case Scope.lookup (sym, env) of
           (_, SIMPLE {ty}) => []
         | (_, COMPOUND {ty, width, uses = us, nested}) => SpanMap.listKeys us
         )
*)
   fun getContextOfUsage (sym, span, env) = raise Unimplemented
(*  (case Scope.lookup (sym, env) of
           (_, SIMPLE {ty}) => raise InferenceBug
         | (_, COMPOUND {ty, width, uses = us, nested}) => 
           #1 (SpanMap.lookup (us, span))
         )
*)
   fun pushUsage (sym, span, env) = raise Unimplemented
(*  (case Scope.lookup (sym, env) of
           (_, SIMPLE {ty}) => raise InferenceBug
         | (_, COMPOUND {ty, width, uses = us, nested}) =>
            let
               val (fid, t) = SpanMap.lookup (us, span)
               (*fun gatherBFun (f,bFun) =
                  case List.find (fn (f',_) => ST.eq_symid (f,f')) funList of
                       SOME (_, VALUE { symFlow = bFun', ... }) =>
                        BD.meet (bFun',bFun)
                     | SOME (_, DECODE { symFlow = bFun', ... }) =>
                        BD.meet (bFun',bFun)
                     | NONE => bFun
               fun addUsageBFun bFun = List.foldl gatherBFun bFun fs
               val env = meetBoolean (addUsageBFun, env)*)
            in
               Scope.wrap (KAPPA {ty = t}, env)
            end
         )
*)
   fun getCtxt env = Scope.getCtxt env

   fun popToUsage (sym, span, env) = raise Unimplemented
(*  (case Scope.unwrap env of
        (KAPPA {ty = tUse}, env) =>
         let
            val funRef = ref (NONE : SymbolTable.symid option)
            fun setUsage (COMPOUND {ty, width, uses = us, nested}, cons) =
               (case SpanMap.find (us,span) of
                    NONE => raise InferenceBug
                  | SOME (fid, _) =>
                     (funRef := SOME fid;
                     (COMPOUND {
                        ty = ty, width = width,
                        uses = SpanMap.insert (us,span,(fid,tUse)),
                        nested = nested
                     }, cons))
               )
              | setUsage _ = raise InferenceBug
            val env = Scope.update (sym, setUsage, env)
            fun setType t (COMPOUND {ty = _, width, uses, nested}, cons) =
                  (COMPOUND {ty = SOME t, width = width, uses = uses, nested = nested},
                   cons)
              | setType t _ = raise InferenceBug
            val fid = case !funRef of
                 SOME fid => fid
               | NONE => raise InferenceBug
            (*val _ = TextIO.print ("popToUsage " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^ ":\n")*)
      
            val env = case Scope.lookup (fid,env) of
                 (_, COMPOUND { ty = SOME (t,_), width, uses, nested}) =>
                  reduceBooleanFormula (fid,t,setType,true,env)
               | _ => raise InferenceBug
         in
            env
         end
     | _ => raise InferenceBug)
*)
   fun pushLambdaVar' (sym, env) =
      let
         val t = VAR (TVar.freshTVar (), BD.freshBVar ())
         val _ = TypeTable.addSymbol (sym, t, Scope.getTypeTable env)
      in
         (t, Scope.wrap (SINGLE {name = sym}, env))
      end

   fun pushLambdaVar (sym, env) =
      let
         val t = VAR (TVar.freshTVar (), BD.freshBVar ())
         val _ = TypeTable.addSymbol (sym, t, Scope.getTypeTable env)
      in
         Scope.wrap (SINGLE {name = sym}, env)
      end

   fun reduceToRecord (bns, env) = raise Unimplemented
(* 
      let
         fun genFields (fs, [], env) = (case Scope.unwrap env of
                 (KAPPA {ty=VAR (tv,bv)}, env) =>
                  Scope.wrap (KAPPA {ty = RECORD (tv, bv, fs)}, env)
               | _ => raise InferenceBug
            )
           | genFields (fs, (bVar, fName) :: bns, env) =
               (case Scope.unwrap env of
                    (KAPPA {ty=t}, env) =>
                        genFields (insertField (
                           RField { name = fName, fty = t, exists = bVar},
                           fs), bns, env)
                  | _ => raise InferenceBug)
      in
         genFields ([], bns, env)
      end
*)
   fun reduceToSum (n, env) = raise Unimplemented
(* 
      let
         fun rTS (n, vars, const, env) = if n>0 then
               case Scope.unwrap env of
                    (KAPPA {ty = CONST c}, env) => rTS (n-1, vars, c+const, env)
                  | (KAPPA {ty = VAR (v,_)}, env) => rTS (n-1, v::vars, const, env)
                  | _ => raise InferenceBug
            else case vars of
                 [] => Scope.wrap (KAPPA {ty = CONST const}, env)
               | [v] => Scope.wrap (KAPPA {ty = VAR (v, BD.freshBVar ())}, env)
               | vs =>
                  let
                     val v = TVar.freshTVar ()
                     val scs = SC.fromList [SC.equality (v, vs, const)]
                     val env = meetSizeConstraint
                                 (fn scs' => SC.merge (scs,scs'), env)
                     (*val (scsStr,si) = SC.toStringSI (scs, NONE, TVar.emptyShowInfo)
                     val (eStr, si) = topToStringSI (env, si)
                     val _ = TextIO.print ("reduceToSum: " ^ scsStr ^ ", resulting in\n" ^ eStr ^ "\n")*)
                  in
                     Scope.wrap (KAPPA { ty = VAR (v, BD.freshBVar ())}, env)
                  end
      in
         rTS (n, [], 0, env)
      end
*)
   fun reduceToFunction (env,nArgs) = if nArgs=0 then env else
      let
         val tt = Scope.getTypeTable env
         val (tSym, env) = case Scope.unwrap env of
                             (KAPPA {kappa}, env) => (kappa,env)
                           | (SINGLE {name}, env) => (name,env)
                           | _ => raise InferenceBug
         val tRes = TT.getSymbol (tSym,tt)
         fun getArgs (tys,n,env) = if n=0 then (tys,env) else
            case Scope.unwrap env of
                 (KAPPA {kappa}, env) => getArgs (TT.getSymbol (kappa,tt) :: tys,n-1,env)
               | (SINGLE {name}, env) => getArgs (TT.getSymbol (name,tt) :: tys,n-1,env)
               | _ => raise InferenceBug
         val (tArgs,env) = getArgs ([],nArgs,env)
         val (k,env) = Scope.acquireKappa env
         val _ = TT.addSymbol (k,FUN (tArgs,tRes),tt)
      in
         Scope.wrap (KAPPA {kappa=k}, env)
      end

   fun reduceToResult env =
     case Scope.unwrap env of
           (KAPPA {kappa}, env) =>
            let
               val tt = Scope.getTypeTable env
               val ty = TT.getSymbol (kappa,tt)
               val (t1,t2) = case ty of
                     FUN (t1,t2) => (t1,t2)
                   | _ => raise InferenceBug
               val bVars = List.foldl
                  (texpBVarset (fn ((_,v),vs) => BD.addToSet (v,vs)))
                  BD.emptySet t1
               val _ = TT.modifyFlow (fn bFun => BD.projectOut (bVars,bFun), tt)
               val _ = TT.addSymbol (kappa,t2,tt)
            in
               Scope.wrap (KAPPA {kappa=kappa}, env)
            end
         | _ => raise InferenceBug

   fun reduceToArgument env = raise Unimplemented
(*  case Scope.unwrap env of
           (KAPPA {ty = FUN ([t1],t2)}, env) =>
            Scope.wrap (KAPPA {ty = t1}, env)
         | _ => raise InferenceBug
*)
   (* local helper: equate or imply the flags of two types *)
   fun flowForType (directed,t1,t2,bFun) = raise Unimplemented
(* 
      let
         fun genImpl (t1,t2) ((contra1,f1), (contra2,f2),bFun) =
            if contra1<>contra2 then
               let
                  val (t1Str, si) = showTypeSI (t1,TVar.emptyShowInfo)
                  val (t2Str, si) = showTypeSI (t2,si)
                  val (mStr, si) = showSubstsSI (mgu (t1,t2,emptySubsts), si)
                  val _ = TextIO.print ("cannot gen impl flow from\n" ^ t1Str ^ "\nand\n" ^ t2Str ^ "\nsince mgu = " ^ mStr ^ "\n")
               in
                  raise InferenceBug
               end
            else if BD.eq(f1,f2) then bFun else
            let
               (*val _ = TextIO.print ("add directed flow: " ^ BD.showVar f1 ^
                  (if contra1 then "<-" else "->") ^ BD.showVar f2 ^ "\n")*)
            in
               if contra1 then BD.meetVarImpliesVar (f2,f1) bFun
               else BD.meetVarImpliesVar (f1,f2) bFun
            end
      in
         if directed then
            ListPair.foldlEq (genImpl (t1,t2)) bFun
               (texpBVarset (op ::) (t1, []), texpBVarset (op ::) (t2, []))
         else
         let
            (*val _ = TextIO.print ("forcing bVars to be equal:" ^
               ListPair.foldlEq (fn (f1,f2,str) => str ^ " " ^ BD.showVar f1 ^ "=" ^ BD.showVar f2) ""
               (texpBVarset (fn ((_,f),fs) => f::fs) (t1, []),
                texpBVarset (fn ((_,f),fs) => f::fs) (t2, [])) ^ "\n")*)
         in
            ListPair.foldlEq BD.meetEqual bFun
               (texpBVarset (fn ((_,f),fs) => f::fs) (t1, []),
                texpBVarset (fn ((_,f),fs) => f::fs) (t2, []))
         end
      end
*)
   fun return (n,env) =  
      let
         val (t, env) = Scope.unwrap env
         fun popN (n,env) = if n<=0 then env else
            let
               val (b, env) = Scope.unwrap env
               val tt = Scope.getTypeTable env
               val env = case b of
                  KAPPA {kappa} => (TT.delSymbol (kappa,tt); Scope.releaseKappa (kappa,env))
                | SINGLE {name} => (TT.delSymbol (name,tt); env)
                | _ => raise InferenceBug
            in
               popN (n-1, env)
            end
      in
         Scope.wrap (t, popN (n,env))
      end

   fun popKappa env =
      case Scope.unwrap env of
        (KAPPA {kappa}, env) =>
         let
            val tt = Scope.getTypeTable env
            val _ = TT.delSymbol (kappa,tt)
            val env = Scope.releaseKappa (kappa,env)
         in
            env
         end
      | _ => raise InferenceBug

   fun equateKappasGeneric (env,directed) =
      let
         fun getKappaTypes env =
            case Scope.unwrap env of
              (KAPPA {kappa=t1}, env) => (case Scope.unwrap env of
                 (KAPPA {kappa=t2}, env) => (t2,t1)
               | (SINGLE {name=t2}, env) => (t2,t1)
               | _ => raise InferenceBug) 
            | _ => raise InferenceBug

         (* generate flow between kappas *)
         val (t1,t2) = getKappaTypes env
         val tt = Scope.getTypeTable env
         val _ = (if directed then
               TT.equateSymbolsFlow (t1,t2,tt)
             else
               TT.equateSymbols (t1,t2,tt)
            ) handle (BD.Unsatisfiable bVar) =>
               flowError (bVar, NONE, env)
      in
         env
      end

   fun equateKappas env = equateKappasGeneric (env,true) 
   fun equateKappasFlow env = equateKappasGeneric (env,false)

   fun flipKappas env =
         case Scope.unwrap env of
              (KAPPA {kappa=t1}, env) => (case Scope.unwrap env of
                 (KAPPA {kappa=t2}, env) => Scope.wrap (KAPPA {kappa=t2},Scope.wrap (KAPPA {kappa=t1},env))
               | _ => raise InferenceBug) 
            | _ => raise InferenceBug

   fun subsetKappas env = raise Unimplemented
(* 
      let
         fun getKappaTypes env =
            case Scope.unwrap env of
              (KAPPA {ty=t2}, env) => (case Scope.unwrap env of
                 (KAPPA {ty=t1}, env) => (t1,t2)
               | (SINGLE {ty=t1, ...}, env) => (t1,t2)
               | _ => raise InferenceBug) 
            | _ => raise InferenceBug

         val (t1,t2) = getKappaTypes env
         val substs = mgu (t1,t2,emptySubsts)
         val substs = substsFilter (substs, texpVarset (t1, TVar.empty))

         (*val (t1Str,si) = showTypeSI (t1,TVar.emptyShowInfo)
         val (t2Str,si) = showTypeSI (t2,si)
         val (sStr, _) = showSubstsSI (substs,si)
         val _ = TextIO.print ("subsetKappas: " ^ t1Str ^ " <= " ^ t2Str ^ " gives " ^ sStr ^ "\n")*)


      in
         substs
      end
*)
   fun popToFunction (sym, env) = 
      let
         fun setType kappa (COMPOUND {ty = false, width, uses, nested}, cons) =
            let
               val tt = Scope.getTypeTable env
               val ty = TypeTable.getSymbol (kappa,tt)
               val _ = TypeTable.addSymbol (sym, ty, tt)
            in
               (COMPOUND {ty = true, width = width, uses = uses, nested = nested},
                cons)
            end
           | setType kappa _ = (TextIO.print ("popToFunction " ^ SymbolTable.getString(!SymbolTables.varTable, sym) ^ ":\n" ^ toString env); raise InferenceBug)
      in
         case Scope.unwrap env of
              (KAPPA {kappa}, env) => Scope.update (sym, setType kappa, env)
            | _ => raise InferenceBug
      end

   fun enterFunction (sym, env) = 
      Scope.setCtxt (sym :: Scope.getCtxt env) env

   fun leaveFunction (sym, env) = 
      case Scope.getCtxt env of
           (fid :: fids) =>
            if SymbolTable.eq_symid(fid,sym) then Scope.setCtxt fids env
            else raise InferenceBug
         | [] => raise InferenceBug

   fun inScope (sym,([],_)) = false
     | inScope (sym,env) = raise Unimplemented
(*  case Scope.unwrap env of
        (GROUP bs,env) =>
         if List.exists (fn {name, ty, width, uses, nested} =>
                           SymbolTable.eq_symid (sym,name)) bs then true
         else inScope (sym,env)
      | (_,env) => inScope (sym,env)
*)      
   fun pushNested (sym, env) = raise Unimplemented
(*
      if inScope (sym,env) then (0,env) else
      let
         val (sc,_) = Scope.unwrap env
         fun findSymInGroups (n, ns, env) =
            List.foldl
               (fn (g,res) => case res of
                    SOME r => SOME r
                  | NONE => findSymInGroup (n+1,g,Scope.wrap (g, env))
               ) NONE ns
         and findSymInGroup (n,GROUP bs,env) =
            (case List.find (fn {name, ty, width, uses, nested} =>
                              SymbolTable.eq_symid (sym,name)) bs of
               SOME {name, ty, width, uses, nested} =>
                  SOME (n, env)
             | NONE =>
               List.foldl (fn ({name, ty, width, uses, nested=ns},res) =>
                  case res of
                     SOME r => SOME r
                   | NONE => findSymInGroups (n, ns, env)
               ) NONE bs
            )
           | findSymInGroup (n,_,env) = raise InferenceBug
      in
         case findSymInGroup (0, sc, env) of
              NONE => (0,env)
            | SOME r => r
      end
*)   
   fun popNested (n, env) = raise Unimplemented
(* if n<=0 then env else
      case Scope.unwrap env of
        (GROUP bs, env) => (case Scope.unwrap env of
             (GROUP bsPrev, env) =>
               let
                  fun replGroup (GROUP bs' :: gs) =
                     if List.all (fn (b,b') =>
                           SymbolTable.eq_symid (#name b, #name b'))
                        (ListPair.zip (bs,bs'))
                     then GROUP bs :: gs else GROUP bs' :: replGroup gs
                    | replGroup [] = []
                    | replGroup _ = raise InferenceBug
                  
                  fun replBs ({name, ty, width, uses, nested}) =
                     {name = name, ty = ty, width = width,
                      uses = uses, nested = replGroup nested}
                  val bsPrev = List.map replBs bsPrev
                  val env = Scope.wrap (GROUP bsPrev,env)
               in
                  popNested (n-1,env)
               end
            | _ => raise InferenceBug
          )
      | (_, env) => raise InferenceBug
*)

   fun clearFunction (sym, env) = raise Unimplemented
(*
      let
         val tOptRef = ref (NONE : (texp * BD.bfun) option)
         fun resetType (COMPOUND {ty = tOpt, width, uses, nested}, cons) =
               (tOptRef := tOpt
               ;(COMPOUND {ty = NONE, width = width, uses = uses, nested = nested}, cons))
           | resetType _ = raise InferenceBug
         val env = Scope.update (sym, resetType, env)
      in
         case !tOptRef of
              NONE => NONE
            | SOME (ty,flow) =>
               SOME (meetBoolean (
                     fn bFun => BD.meet (flow,bFun),
                     Scope.wrap (KAPPA { ty = ty },env)))
      end
*)   
   fun forceNoInputs (sym, fields, env) = raise Unimplemented
(* case Scope.lookup (sym,env) of
               (_,COMPOUND {ty = SOME (t,bFun), width, uses, nested}) =>
               let
                  val fs = case t of
                       (MONAD (r,RECORD (_,_,fs),out)) => fs
                     | FUN (args,(MONAD (r,RECORD (_,_,fs),out))) =>
                        List.foldl (fn (arg,fs) => case arg of
                             RECORD (_,_,fs') => fs' @ fs
                           | _ => fs) fs args
                     | FUN (args,_) =>
                        List.foldl (fn (arg,fs) => case arg of
                             RECORD (_,_,fs') => fs' @ fs
                           | _ => fs) [] args
                     | _ => []
                  fun checkField bVar =
                     (case BD.meetVarZero bVar bFun of _ => true)
                     handle (BD.Unsatisfiable bVars) => false
               in
                  List.foldl (fn (RField { name = f, fty, exists = bVar},fs) =>
                     if List.exists (fn s => SymbolTable.eq_symid(s,f)) fields
                     then fs
                     else if checkField bVar then fs else f :: fs)
                  [] fs
               end
             | (_,COMPOUND {ty = NONE, width, uses, nested}) => []  (*allow type errors*)
             | _ => raise InferenceBug
*)
end
