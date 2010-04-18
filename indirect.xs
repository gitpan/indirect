/* This file is part of the indirect Perl module.
 * See http://search.cpan.org/dist/indirect/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define __PACKAGE__     "indirect"
#define __PACKAGE_LEN__ (sizeof(__PACKAGE__)-1)

/* --- Compatibility wrappers ---------------------------------------------- */

#ifndef NOOP
# define NOOP
#endif

#ifndef dNOOP
# define dNOOP
#endif

#ifndef Newx
# define Newx(v, n, c) New(0, v, n, c)
#endif

#ifndef SvPV_const
# define SvPV_const SvPV
#endif

#ifndef SvPV_nolen_const
# define SvPV_nolen_const SvPV_nolen
#endif

#ifndef SvPVX_const
# define SvPVX_const SvPVX
#endif

#ifndef SvREFCNT_inc_simple_NN
# define SvREFCNT_inc_simple_NN SvREFCNT_inc
#endif

#ifndef sv_catpvn_nomg
# define sv_catpvn_nomg sv_catpvn
#endif

#ifndef mPUSHp
# define mPUSHp(P, L) PUSHs(sv_2mortal(newSVpvn((P), (L))))
#endif

#ifndef mPUSHu
# define mPUSHu(U) PUSHs(sv_2mortal(newSVuv(U)))
#endif

#ifndef HvNAME_get
# define HvNAME_get(H) HvNAME(H)
#endif

#ifndef HvNAMELEN_get
# define HvNAMELEN_get(H) strlen(HvNAME_get(H))
#endif

#define I_HAS_PERL(R, V, S) (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

#undef ENTERn
#if defined(ENTER_with_name) && !I_HAS_PERL(5, 11, 4)
# define ENTERn(N) ENTER_with_name(N)
#else
# define ENTERn(N) ENTER
#endif

#undef LEAVEn
#if defined(LEAVE_with_name) && !I_HAS_PERL(5, 11, 4)
# define LEAVEn(N) LEAVE_with_name(N)
#else
# define LEAVEn(N) LEAVE
#endif

#if I_HAS_PERL(5, 10, 0) || defined(PL_parser)
# ifndef PL_lex_inwhat
#  define PL_lex_inwhat PL_parser->lex_inwhat
# endif
# ifndef PL_linestr
#  define PL_linestr PL_parser->linestr
# endif
# ifndef PL_bufptr
#  define PL_bufptr PL_parser->bufptr
# endif
# ifndef PL_oldbufptr
#  define PL_oldbufptr PL_parser->oldbufptr
# endif
#else
# ifndef PL_lex_inwhat
#  define PL_lex_inwhat PL_Ilex_inwhat
# endif
# ifndef PL_linestr
#  define PL_linestr PL_Ilinestr
# endif
# ifndef PL_bufptr
#  define PL_bufptr PL_Ibufptr
# endif
# ifndef PL_oldbufptr
#  define PL_oldbufptr PL_Ioldbufptr
# endif
#endif

#ifndef I_WORKAROUND_REQUIRE_PROPAGATION
# define I_WORKAROUND_REQUIRE_PROPAGATION !I_HAS_PERL(5, 10, 1)
#endif

/* ... Thread safety and multiplicity ...................................... */

/* Safe unless stated otherwise in Makefile.PL */
#ifndef I_FORKSAFE
# define I_FORKSAFE 1
#endif

#ifndef I_MULTIPLICITY
# if defined(MULTIPLICITY) || defined(PERL_IMPLICIT_CONTEXT)
#  define I_MULTIPLICITY 1
# else
#  define I_MULTIPLICITY 0
# endif
#endif
#if I_MULTIPLICITY && !defined(tTHX)
# define tTHX PerlInterpreter*
#endif

#if I_MULTIPLICITY && defined(USE_ITHREADS) && defined(dMY_CXT) && defined(MY_CXT) && defined(START_MY_CXT) && defined(MY_CXT_INIT) && (defined(MY_CXT_CLONE) || defined(dMY_CXT_SV))
# define I_THREADSAFE 1
# ifndef MY_CXT_CLONE
#  define MY_CXT_CLONE \
    dMY_CXT_SV;                                                      \
    my_cxt_t *my_cxtp = (my_cxt_t*)SvPVX(newSV(sizeof(my_cxt_t)-1)); \
    Copy(INT2PTR(my_cxt_t*, SvUV(my_cxt_sv)), my_cxtp, 1, my_cxt_t); \
    sv_setuv(my_cxt_sv, PTR2UV(my_cxtp))
# endif
#else
# define I_THREADSAFE 0
# undef  dMY_CXT
# define dMY_CXT      dNOOP
# undef  MY_CXT
# define MY_CXT       indirect_globaldata
# undef  START_MY_CXT
# define START_MY_CXT STATIC my_cxt_t MY_CXT;
# undef  MY_CXT_INIT
# define MY_CXT_INIT  NOOP
# undef  MY_CXT_CLONE
# define MY_CXT_CLONE NOOP
#endif

/* --- Helpers ------------------------------------------------------------- */

/* ... Thread-safe hints ................................................... */

#if I_WORKAROUND_REQUIRE_PROPAGATION

typedef struct {
 SV *code;
 IV  require_tag;
} indirect_hint_t;

#define I_HINT_STRUCT 1

#define I_HINT_CODE(H) ((H)->code)

#define I_HINT_FREE(H) {   \
 indirect_hint_t *h = (H); \
 SvREFCNT_dec(h->code);    \
 PerlMemShared_free(h);    \
}

#else  /*  I_WORKAROUND_REQUIRE_PROPAGATION */

typedef SV indirect_hint_t;

#define I_HINT_STRUCT 0

#define I_HINT_CODE(H) (H)

#define I_HINT_FREE(H) SvREFCNT_dec(H);

#endif /* !I_WORKAROUND_REQUIRE_PROPAGATION */

#if I_THREADSAFE

#define PTABLE_NAME        ptable_hints
#define PTABLE_VAL_FREE(V) I_HINT_FREE(V)

#define pPTBL  pTHX
#define pPTBL_ pTHX_
#define aPTBL  aTHX
#define aPTBL_ aTHX_

#include "ptable.h"

#define ptable_hints_store(T, K, V) ptable_hints_store(aTHX_ (T), (K), (V))
#define ptable_hints_free(T)        ptable_hints_free(aTHX_ (T))

#endif /* I_THREADSAFE */

/* Define the op->str ptable here because we need to be able to clean it during
 * thread cleanup. */

typedef struct {
 const char *pos;
 char       *buf;
 STRLEN      len, size;
 line_t      line;
} indirect_op_info_t;

#define PTABLE_NAME        ptable
#define PTABLE_VAL_FREE(V) if (V) { Safefree(((indirect_op_info_t *) (V))->buf); Safefree(V); }

#define pPTBL  pTHX
#define pPTBL_ pTHX_
#define aPTBL  aTHX
#define aPTBL_ aTHX_

#include "ptable.h"

#define ptable_store(T, K, V) ptable_store(aTHX_ (T), (K), (V))
#define ptable_clear(T)       ptable_clear(aTHX_ (T))
#define ptable_free(T)        ptable_free(aTHX_ (T))

#define MY_CXT_KEY __PACKAGE__ "::_guts" XS_VERSION

typedef struct {
#if I_THREADSAFE
 ptable     *tbl; /* It really is a ptable_hints */
 tTHX        owner;
#endif
 ptable     *map;
 const char *linestr;
} my_cxt_t;

START_MY_CXT

#if I_THREADSAFE

STATIC SV *indirect_clone(pTHX_ SV *sv, tTHX owner) {
#define indirect_clone(S, O) indirect_clone(aTHX_ (S), (O))
 CLONE_PARAMS  param;
 AV           *stashes = NULL;
 SV           *dupsv;

 if (SvTYPE(sv) == SVt_PVHV && HvNAME_get(sv))
  stashes = newAV();

 param.stashes    = stashes;
 param.flags      = 0;
 param.proto_perl = owner;

 dupsv = sv_dup(sv, &param);

 if (stashes) {
  av_undef(stashes);
  SvREFCNT_dec(stashes);
 }

 return SvREFCNT_inc(dupsv);
}

STATIC void indirect_ptable_clone(pTHX_ ptable_ent *ent, void *ud_) {
 my_cxt_t        *ud = ud_;
 indirect_hint_t *h1 = ent->val;
 indirect_hint_t *h2;

 if (ud->owner == aTHX)
  return;

#if I_HINT_STRUCT

 h2       = PerlMemShared_malloc(sizeof *h2);
 h2->code = indirect_clone(h1->code, ud->owner);
 SvREFCNT_inc(h2->code);
#if I_WORKAROUND_REQUIRE_PROPAGATION
 h2->require_tag = PTR2IV(indirect_clone(INT2PTR(SV *, h1->require_tag),
                                         ud->owner));
#endif

#else  /*  I_HINT_STRUCT */

 h2 = indirect_clone(h1, ud->owner);
 SvREFCNT_inc(h2);

#endif /* !I_HINT_STRUCT */

 ptable_hints_store(ud->tbl, ent->key, h2);
}

STATIC void indirect_thread_cleanup(pTHX_ void *);

STATIC void indirect_thread_cleanup(pTHX_ void *ud) {
 int *level = ud;

 if (*level) {
  *level = 0;
  LEAVE;
  SAVEDESTRUCTOR_X(indirect_thread_cleanup, level);
  ENTER;
 } else {
  dMY_CXT;
  PerlMemShared_free(level);
  ptable_free(MY_CXT.map);
  ptable_hints_free(MY_CXT.tbl);
 }
}

#endif /* I_THREADSAFE */

#if I_WORKAROUND_REQUIRE_PROPAGATION
STATIC IV indirect_require_tag(pTHX) {
#define indirect_require_tag() indirect_require_tag(aTHX)
 const CV *cv, *outside;

 cv = PL_compcv;

 if (!cv) {
  /* If for some reason the pragma is operational at run-time, try to discover
   * the current cv in use. */
  const PERL_SI *si;

  for (si = PL_curstackinfo; si; si = si->si_prev) {
   I32 cxix;

   for (cxix = si->si_cxix; cxix >= 0; --cxix) {
    const PERL_CONTEXT *cx = si->si_cxstack + cxix;

    switch (CxTYPE(cx)) {
     case CXt_SUB:
     case CXt_FORMAT:
      /* The propagation workaround is only needed up to 5.10.0 and at that
       * time format and sub contexts were still identical. And even later the
       * cv members offsets should have been kept the same. */
      cv = cx->blk_sub.cv;
      goto get_enclosing_cv;
     case CXt_EVAL:
      cv = cx->blk_eval.cv;
      goto get_enclosing_cv;
     default:
      break;
    }
   }
  }

  cv = PL_main_cv;
 }

get_enclosing_cv:
 for (outside = CvOUTSIDE(cv); outside; outside = CvOUTSIDE(cv))
  cv = outside;

 return PTR2IV(cv);
}
#endif /* I_WORKAROUND_REQUIRE_PROPAGATION */

STATIC SV *indirect_tag(pTHX_ SV *value) {
#define indirect_tag(V) indirect_tag(aTHX_ (V))
 indirect_hint_t *h;
 SV *code = NULL;
 dMY_CXT;

 if (SvROK(value)) {
  value = SvRV(value);
  if (SvTYPE(value) >= SVt_PVCV) {
   code = value;
   SvREFCNT_inc_simple_NN(code);
  }
 }

#if I_HINT_STRUCT
 h = PerlMemShared_malloc(sizeof *h);
 h->code        = code;
# if I_WORKAROUND_REQUIRE_PROPAGATION
 h->require_tag = indirect_require_tag();
# endif /* I_WORKAROUND_REQUIRE_PROPAGATION */
#else  /*  I_HINT_STRUCT */
 h = code;
#endif /* !I_HINT_STRUCT */

#if I_THREADSAFE
 /* We only need for the key to be an unique tag for looking up the value later.
  * Allocated memory provides convenient unique identifiers, so that's why we
  * use the hint as the key itself. */
 ptable_hints_store(MY_CXT.tbl, h, h);
#endif /* I_THREADSAFE */

 return newSViv(PTR2IV(h));
}

STATIC SV *indirect_detag(pTHX_ const SV *hint) {
#define indirect_detag(H) indirect_detag(aTHX_ (H))
 indirect_hint_t *h;
 dMY_CXT;

 if (!(hint && SvIOK(hint)))
  return NULL;

 h = INT2PTR(indirect_hint_t *, SvIVX(hint));
#if I_THREADSAFE
 h = ptable_fetch(MY_CXT.tbl, h);
#endif /* I_THREADSAFE */

#if I_WORKAROUND_REQUIRE_PROPAGATION
 if (indirect_require_tag() != h->require_tag)
  return NULL;
#endif /* I_WORKAROUND_REQUIRE_PROPAGATION */

 return I_HINT_CODE(h);
}

STATIC U32 indirect_hash = 0;

STATIC SV *indirect_hint(pTHX) {
#define indirect_hint() indirect_hint(aTHX)
 SV *hint;

 if (IN_PERL_RUNTIME)
  return NULL;

#if I_HAS_PERL(5, 9, 5)
 hint = Perl_refcounted_he_fetch(aTHX_ PL_curcop->cop_hints_hash,
                                       NULL,
                                       __PACKAGE__, __PACKAGE_LEN__,
                                       0,
                                       indirect_hash);
#else
 {
  SV **val = hv_fetch(GvHV(PL_hintgv), __PACKAGE__, __PACKAGE_LEN__,
                                                                 indirect_hash);
  if (!val)
   return 0;
  hint = *val;
 }
#endif
 return indirect_detag(hint);
}

/* ... op -> source position ............................................... */

STATIC void indirect_map_store(pTHX_ const OP *o, const char *src, SV *sv, line_t line) {
#define indirect_map_store(O, S, N, L) indirect_map_store(aTHX_ (O), (S), (N), (L))
 indirect_op_info_t *oi;
 const char *s;
 STRLEN len;
 dMY_CXT;

 /* When lex_inwhat is set, we're in a quotelike environment (qq, qr, but not q)
  * In this case the linestr has temporarly changed, but the old buffer should
  * still be alive somewhere. */

 if (!PL_lex_inwhat) {
  const char *pl_linestr = SvPVX_const(PL_linestr);
  if (MY_CXT.linestr != pl_linestr) {
   ptable_clear(MY_CXT.map);
   MY_CXT.linestr = pl_linestr;
  }
 }

 if (!(oi = ptable_fetch(MY_CXT.map, o))) {
  Newx(oi, 1, indirect_op_info_t);
  ptable_store(MY_CXT.map, o, oi);
  oi->buf  = NULL;
  oi->size = 0;
 }

 if (sv) {
  s = SvPV_const(sv, len);
 } else {
  s   = "{";
  len = 1;
 }

 if (len > oi->size) {
  Safefree(oi->buf);
  Newx(oi->buf, len, char);
  oi->size = len;
 }
 Copy(s, oi->buf, len, char);

 oi->len  = len;
 oi->pos  = src;
 oi->line = line;
}

STATIC const indirect_op_info_t *indirect_map_fetch(pTHX_ const OP *o) {
#define indirect_map_fetch(O) indirect_map_fetch(aTHX_ (O))
 dMY_CXT;

 if (MY_CXT.linestr != SvPVX_const(PL_linestr))
  return NULL;

 return ptable_fetch(MY_CXT.map, o);
}

STATIC void indirect_map_delete(pTHX_ const OP *o) {
#define indirect_map_delete(O) indirect_map_delete(aTHX_ (O))
 dMY_CXT;

 ptable_store(MY_CXT.map, o, NULL);
}

/* --- Check functions ----------------------------------------------------- */

STATIC const char *indirect_find(pTHX_ SV *sv, const char *s) {
#define indirect_find(N, S) indirect_find(aTHX_ (N), (S))
 STRLEN len;
 const char *p = NULL, *r = SvPV_const(sv, len);

 if (len >= 1 && *r == '$') {
  ++r;
  --len;
  s = strchr(s, '$');
  if (!s)
   return NULL;
 }

 p = strstr(s, r);
 while (p) {
  p += len;
  if (!isALNUM(*p))
   break;
  p = strstr(p + 1, r);
 }

 return p;
}

/* ... ck_const ............................................................ */

STATIC OP *(*indirect_old_ck_const)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_const(pTHX_ OP *o) {
 o = CALL_FPTR(indirect_old_ck_const)(aTHX_ o);

 if (indirect_hint()) {
  SV *sv = cSVOPo_sv;
  if (SvPOK(sv) && (SvTYPE(sv) >= SVt_PV)) {
   const char *s = indirect_find(sv, PL_oldbufptr);
   indirect_map_store(o, s, sv, CopLINE(&PL_compiling));
   return o;
  }
 }

 indirect_map_delete(o);
 return o;
}

/* ... ck_rv2sv ............................................................ */

STATIC OP *(*indirect_old_ck_rv2sv)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_rv2sv(pTHX_ OP *o) {
 if (indirect_hint()) {
  OP *op = cUNOPo->op_first;
  SV *sv;
  const char *name = NULL, *s;
  STRLEN len;
  OPCODE type = (OPCODE) op->op_type;

  switch (type) {
   case OP_GV:
   case OP_GVSV: {
    GV *gv = cGVOPx_gv(op);
    name = GvNAME(gv);
    len  = GvNAMELEN(gv);
    break;
   }
   default:
    if ((PL_opargs[type] & OA_CLASS_MASK) == OA_SVOP) {
     SV *nsv = cSVOPx_sv(op);
     if (SvPOK(nsv) && (SvTYPE(nsv) >= SVt_PV))
      name = SvPV_const(nsv, len);
    }
  }
  if (!name)
   goto done;

  sv = sv_2mortal(newSVpvn("$", 1));
  sv_catpvn_nomg(sv, name, len);
  s = indirect_find(sv, PL_oldbufptr);
  if (!s) { /* If it failed, retry without the current stash */
   const char *stash = HvNAME_get(PL_curstash);
   STRLEN stashlen = HvNAMELEN_get(PL_curstash);

   if ((len < stashlen + 2) || strnNE(name, stash, stashlen)
       || name[stashlen] != ':' || name[stashlen+1] != ':') {
    /* Failed again ? Try to remove main */
    stash = "main";
    stashlen = 4;
    if ((len < stashlen + 2) || strnNE(name, stash, stashlen)
        || name[stashlen] != ':' || name[stashlen+1] != ':')
     goto done;
   }

   sv_setpvn(sv, "$", 1);
   stashlen += 2;
   sv_catpvn_nomg(sv, name + stashlen, len - stashlen);
   s = indirect_find(sv, PL_oldbufptr);
   if (!s)
    goto done;
  }

  o = CALL_FPTR(indirect_old_ck_rv2sv)(aTHX_ o);
  indirect_map_store(o, s, sv, CopLINE(&PL_compiling));
  return o;
 }

done:
 o = CALL_FPTR(indirect_old_ck_rv2sv)(aTHX_ o);

 indirect_map_delete(o);
 return o;
}

/* ... ck_padany ........................................................... */

STATIC OP *(*indirect_old_ck_padany)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_padany(pTHX_ OP *o) {
 o = CALL_FPTR(indirect_old_ck_padany)(aTHX_ o);

 if (indirect_hint()) {
  SV *sv;
  const char *s = PL_oldbufptr, *t = PL_bufptr - 1;

  while (s < t && isSPACE(*s)) ++s;
  if (*s == '$' && ++s <= t) {
   while (s < t && isSPACE(*s)) ++s;
   while (s < t && isSPACE(*t)) --t;
   sv = sv_2mortal(newSVpvn("$", 1));
   sv_catpvn_nomg(sv, s, t - s + 1);
   indirect_map_store(o, s, sv, CopLINE(&PL_compiling));
   return o;
  }
 }

 indirect_map_delete(o);
 return o;
}

/* ... ck_scope ............................................................ */

STATIC OP *(*indirect_old_ck_scope)  (pTHX_ OP *) = 0;
STATIC OP *(*indirect_old_ck_lineseq)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_scope(pTHX_ OP *o) {
 OP *(*old_ck)(pTHX_ OP *) = 0;

 switch (o->op_type) {
  case OP_SCOPE:   old_ck = indirect_old_ck_scope;   break;
  case OP_LINESEQ: old_ck = indirect_old_ck_lineseq; break;
 }
 o = CALL_FPTR(old_ck)(aTHX_ o);

 if (indirect_hint()) {
  indirect_map_store(o, PL_oldbufptr, NULL, CopLINE(&PL_compiling));
  return o;
 }

 indirect_map_delete(o);
 return o;
}

/* We don't need to clean the map entries for leave ops because they can only
 * be created by mutating from a lineseq. */

/* ... ck_method ........................................................... */

STATIC OP *(*indirect_old_ck_method)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_method(pTHX_ OP *o) {
 if (indirect_hint()) {
  OP *op = cUNOPo->op_first;
  const indirect_op_info_t *oi = indirect_map_fetch(op);
  const char *s = NULL;
  line_t line;
  SV *sv;

  if (oi && (s = oi->pos)) {
   sv   = sv_2mortal(newSVpvn(oi->buf, oi->len));
   line = oi->line; /* Keep the old line so that we really point to the first */
  } else {
   sv = cSVOPx_sv(op);
   if (!SvPOK(sv) || (SvTYPE(sv) < SVt_PV))
    goto done;
   sv   = sv_mortalcopy(sv);
   s    = indirect_find(sv, PL_oldbufptr);
   line = CopLINE(&PL_compiling);
  }

  o = CALL_FPTR(indirect_old_ck_method)(aTHX_ o);
  /* o may now be a method_named */

  indirect_map_store(o, s, sv, line);
  return o;
 }

done:
 o = CALL_FPTR(indirect_old_ck_method)(aTHX_ o);

 indirect_map_delete(o);
 return o;
}

/* ... ck_entersub ......................................................... */

STATIC int indirect_is_indirect(const indirect_op_info_t *moi, const indirect_op_info_t *ooi) {
 if (moi->pos > ooi->pos)
  return 0;

 if (moi->pos == ooi->pos)
  return moi->len == ooi->len && !memcmp(moi->buf, ooi->buf, moi->len);

 return 1;
}

STATIC OP *(*indirect_old_ck_entersub)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_entersub(pTHX_ OP *o) {
 SV *code = indirect_hint();

 o = CALL_FPTR(indirect_old_ck_entersub)(aTHX_ o);

 if (code) {
  const indirect_op_info_t *moi, *ooi;
  OP     *mop, *oop;
  LISTOP *lop;

  oop = o;
  do {
   lop = (LISTOP *) oop;
   if (!(lop->op_flags & OPf_KIDS))
    goto done;
   oop = lop->op_first;
  } while (oop->op_type != OP_PUSHMARK);
  oop = oop->op_sibling;
  mop = lop->op_last;

  if (!oop)
   goto done;

  switch (oop->op_type) {
   case OP_CONST:
   case OP_RV2SV:
   case OP_PADSV:
   case OP_SCOPE:
   case OP_LEAVE:
    break;
   default:
    goto done;
  }

  if (mop->op_type == OP_METHOD)
   mop = cUNOPx(mop)->op_first;
  else if (mop->op_type != OP_METHOD_NAMED)
   goto done;

  moi = indirect_map_fetch(mop);
  if (!(moi && moi->pos))
   goto done;

  ooi = indirect_map_fetch(oop);
  if (!(ooi && ooi->pos))
   goto done;

  if (indirect_is_indirect(moi, ooi)) {
   SV *file;
   dSP;

   ENTER;
   SAVETMPS;

#ifdef USE_ITHREADS
   file = sv_2mortal(newSVpv(CopFILE(&PL_compiling), 0));
#else
   file = sv_mortalcopy(CopFILESV(&PL_compiling));
#endif

   PUSHMARK(SP);
   EXTEND(SP, 4);
   mPUSHp(ooi->buf, ooi->len);
   mPUSHp(moi->buf, moi->len);
   PUSHs(file);
   mPUSHu(moi->line);
   PUTBACK;

   call_sv(code, G_VOID);

   PUTBACK;

   FREETMPS;
   LEAVE;
  }
 }

done:
 return o;
}

STATIC U32 indirect_initialized = 0;

STATIC void indirect_teardown(pTHX_ void *root) {
 dMY_CXT;

 if (!indirect_initialized)
  return;

#if I_MULTIPLICITY
 if (aTHX != root)
  return;
#endif

 ptable_free(MY_CXT.map);
#if I_THREADSAFE
 ptable_hints_free(MY_CXT.tbl);
#endif

 PL_check[OP_CONST]       = MEMBER_TO_FPTR(indirect_old_ck_const);
 indirect_old_ck_const    = 0;
 PL_check[OP_RV2SV]       = MEMBER_TO_FPTR(indirect_old_ck_rv2sv);
 indirect_old_ck_rv2sv    = 0;
 PL_check[OP_PADANY]      = MEMBER_TO_FPTR(indirect_old_ck_padany);
 indirect_old_ck_padany   = 0;
 PL_check[OP_SCOPE]       = MEMBER_TO_FPTR(indirect_old_ck_scope);
 indirect_old_ck_scope    = 0;
 PL_check[OP_LINESEQ]     = MEMBER_TO_FPTR(indirect_old_ck_lineseq);
 indirect_old_ck_lineseq  = 0;

 PL_check[OP_METHOD]      = MEMBER_TO_FPTR(indirect_old_ck_method);
 indirect_old_ck_method   = 0;
 PL_check[OP_ENTERSUB]    = MEMBER_TO_FPTR(indirect_old_ck_entersub);
 indirect_old_ck_entersub = 0;

 indirect_initialized = 0;
}

STATIC void indirect_setup(pTHX) {
#define indirect_setup() indirect_setup(aTHX)
 if (indirect_initialized)
  return;

 MY_CXT_INIT;
#if I_THREADSAFE
 MY_CXT.tbl     = ptable_new();
 MY_CXT.owner   = aTHX;
#endif
 MY_CXT.map     = ptable_new();
 MY_CXT.linestr = NULL;

 indirect_old_ck_const    = PL_check[OP_CONST];
 PL_check[OP_CONST]       = MEMBER_TO_FPTR(indirect_ck_const);
 indirect_old_ck_rv2sv    = PL_check[OP_RV2SV];
 PL_check[OP_RV2SV]       = MEMBER_TO_FPTR(indirect_ck_rv2sv);
 indirect_old_ck_padany   = PL_check[OP_PADANY];
 PL_check[OP_PADANY]      = MEMBER_TO_FPTR(indirect_ck_padany);
 indirect_old_ck_scope    = PL_check[OP_SCOPE];
 PL_check[OP_SCOPE]       = MEMBER_TO_FPTR(indirect_ck_scope);
 indirect_old_ck_lineseq  = PL_check[OP_LINESEQ];
 PL_check[OP_LINESEQ]     = MEMBER_TO_FPTR(indirect_ck_scope);

 indirect_old_ck_method   = PL_check[OP_METHOD];
 PL_check[OP_METHOD]      = MEMBER_TO_FPTR(indirect_ck_method);
 indirect_old_ck_entersub = PL_check[OP_ENTERSUB];
 PL_check[OP_ENTERSUB]    = MEMBER_TO_FPTR(indirect_ck_entersub);

#if I_MULTIPLICITY
 call_atexit(indirect_teardown, aTHX);
#else
 call_atexit(indirect_teardown, NULL);
#endif

 indirect_initialized = 1;
}

STATIC U32 indirect_booted = 0;

/* --- XS ------------------------------------------------------------------ */

MODULE = indirect      PACKAGE = indirect

PROTOTYPES: ENABLE

BOOT:
{
 if (!indirect_booted++) {
  HV *stash;

  PERL_HASH(indirect_hash, __PACKAGE__, __PACKAGE_LEN__);

  stash = gv_stashpvn(__PACKAGE__, __PACKAGE_LEN__, 1);
  newCONSTSUB(stash, "I_THREADSAFE", newSVuv(I_THREADSAFE));
  newCONSTSUB(stash, "I_FORKSAFE",   newSVuv(I_FORKSAFE));
 }

 indirect_setup();
}

#if I_THREADSAFE

void
CLONE(...)
PROTOTYPE: DISABLE
PREINIT:
 ptable *t;
 int    *level;
CODE:
 {
  my_cxt_t ud;
  dMY_CXT;
  ud.tbl   = t = ptable_new();
  ud.owner = MY_CXT.owner;
  ptable_walk(MY_CXT.tbl, indirect_ptable_clone, &ud);
 }
 {
  MY_CXT_CLONE;
  MY_CXT.map     = ptable_new();
  MY_CXT.linestr = NULL;
  MY_CXT.tbl     = t;
  MY_CXT.owner   = aTHX;
 }
 {
  level = PerlMemShared_malloc(sizeof *level);
  *level = 1;
  LEAVEn("sub");
  SAVEDESTRUCTOR_X(indirect_thread_cleanup, level);
  ENTERn("sub");
 }

#endif

SV *
_tag(SV *value)
PROTOTYPE: $
CODE:
 RETVAL = indirect_tag(value);
OUTPUT:
 RETVAL
