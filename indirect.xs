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

#ifndef SvREFCNT_inc_simple_void_NN
# ifdef SvREFCNT_inc_simple_NN
#  define SvREFCNT_inc_simple_void_NN SvREFCNT_inc_simple_NN
# else
#  define SvREFCNT_inc_simple_void_NN SvREFCNT_inc
# endif
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

#ifndef OP_SIBLING
# define OP_SIBLING(O) ((O)->op_sibling)
#endif

#define I_HAS_PERL(R, V, S) (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

#if I_HAS_PERL(5, 10, 0) || defined(PL_parser)
# ifndef PL_linestr
#  define PL_linestr PL_parser->linestr
# endif
# ifndef PL_bufptr
#  define PL_bufptr PL_parser->bufptr
# endif
# ifndef PL_oldbufptr
#  define PL_oldbufptr PL_parser->oldbufptr
# endif
# ifndef PL_lex_inwhat
#  define PL_lex_inwhat PL_parser->lex_inwhat
# endif
#else
# ifndef PL_linestr
#  define PL_linestr PL_Ilinestr
# endif
# ifndef PL_bufptr
#  define PL_bufptr PL_Ibufptr
# endif
# ifndef PL_oldbufptr
#  define PL_oldbufptr PL_Ioldbufptr
# endif
# ifndef PL_lex_inwhat
#  define PL_lex_inwhat PL_Ilex_inwhat
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

#if defined(OP_CHECK_MUTEX_LOCK) && defined(OP_CHECK_MUTEX_UNLOCK)
# define I_CHECK_MUTEX_LOCK   OP_CHECK_MUTEX_LOCK
# define I_CHECK_MUTEX_UNLOCK OP_CHECK_MUTEX_UNLOCK
#else
# define I_CHECK_MUTEX_LOCK   OP_REFCNT_LOCK
# define I_CHECK_MUTEX_UNLOCK OP_REFCNT_UNLOCK
#endif

typedef OP *(*indirect_ck_t)(pTHX_ OP *);

#ifdef wrap_op_checker

# define indirect_ck_replace(T, NC, OCP) wrap_op_checker((T), (NC), (OCP))

#else

STATIC void indirect_ck_replace(pTHX_ OPCODE type, indirect_ck_t new_ck, indirect_ck_t *old_ck_p) {
#define indirect_ck_replace(T, NC, OCP) indirect_ck_replace(aTHX_ (T), (NC), (OCP))
 I_CHECK_MUTEX_LOCK;
 if (!*old_ck_p) {
  *old_ck_p      = PL_check[type];
  PL_check[type] = new_ck;
 }
 I_CHECK_MUTEX_UNLOCK;
}

#endif

STATIC void indirect_ck_restore(pTHX_ OPCODE type, indirect_ck_t *old_ck_p) {
#define indirect_ck_restore(T, OCP) indirect_ck_restore(aTHX_ (T), (OCP))
 I_CHECK_MUTEX_LOCK;
 if (*old_ck_p) {
  PL_check[type] = *old_ck_p;
  *old_ck_p      = 0;
 }
 I_CHECK_MUTEX_UNLOCK;
}

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
 char   *buf;
 STRLEN  pos;
 STRLEN  size;
 STRLEN  len;
 line_t  line;
} indirect_op_info_t;

#define PTABLE_NAME        ptable
#define PTABLE_VAL_FREE(V) if (V) { Safefree(((indirect_op_info_t *) (V))->buf); Safefree(V); }

#define pPTBL  pTHX
#define pPTBL_ pTHX_
#define aPTBL  aTHX
#define aPTBL_ aTHX_

#include "ptable.h"

#define ptable_store(T, K, V) ptable_store(aTHX_ (T), (K), (V))
#define ptable_delete(T, K)   ptable_delete(aTHX_ (T), (K))
#define ptable_clear(T)       ptable_clear(aTHX_ (T))
#define ptable_free(T)        ptable_free(aTHX_ (T))

#define MY_CXT_KEY __PACKAGE__ "::_guts" XS_VERSION

typedef struct {
#if I_THREADSAFE
 ptable *tbl; /* It really is a ptable_hints */
 tTHX    owner;
#endif
 ptable *map;
 SV     *global_code;
} my_cxt_t;

START_MY_CXT

#if I_THREADSAFE

typedef struct {
 ptable *tbl;
#if I_HAS_PERL(5, 13, 2)
 CLONE_PARAMS *params;
#else
 CLONE_PARAMS params;
#endif
} indirect_ptable_clone_ud;

#if I_HAS_PERL(5, 13, 2)
# define indirect_ptable_clone_ud_init(U, T, O) \
   (U).tbl    = (T); \
   (U).params = Perl_clone_params_new((O), aTHX)
# define indirect_ptable_clone_ud_deinit(U) Perl_clone_params_del((U).params)
# define indirect_dup_inc(S, U)             SvREFCNT_inc(sv_dup((S), (U)->params))
#else
# define indirect_ptable_clone_ud_init(U, T, O) \
   (U).tbl               = (T);     \
   (U).params.stashes    = newAV(); \
   (U).params.flags      = 0;       \
   (U).params.proto_perl = (O)
# define indirect_ptable_clone_ud_deinit(U) SvREFCNT_dec((U).params.stashes)
# define indirect_dup_inc(S, U)             SvREFCNT_inc(sv_dup((S), &((U)->params)))
#endif

STATIC void indirect_ptable_clone(pTHX_ ptable_ent *ent, void *ud_) {
 indirect_ptable_clone_ud *ud = ud_;
 indirect_hint_t          *h1 = ent->val;
 indirect_hint_t          *h2;

#if I_HINT_STRUCT

 h2              = PerlMemShared_malloc(sizeof *h2);
 h2->code        = indirect_dup_inc(h1->code, ud);
#if I_WORKAROUND_REQUIRE_PROPAGATION
 h2->require_tag = PTR2IV(indirect_dup_inc(INT2PTR(SV *, h1->require_tag), ud));
#endif

#else  /*  I_HINT_STRUCT */

 h2 = indirect_dup_inc(h1, ud);

#endif /* !I_HINT_STRUCT */

 ptable_hints_store(ud->tbl, ent->key, h2);
}

STATIC void indirect_thread_cleanup(pTHX_ void *ud) {
 dMY_CXT;

 SvREFCNT_dec(MY_CXT.global_code);
 MY_CXT.global_code = NULL;
 ptable_free(MY_CXT.map);
 MY_CXT.map = NULL;
 ptable_hints_free(MY_CXT.tbl);
 MY_CXT.tbl = NULL;
}

STATIC int indirect_endav_free(pTHX_ SV *sv, MAGIC *mg) {
 SAVEDESTRUCTOR_X(indirect_thread_cleanup, NULL);

 return 0;
}

STATIC MGVTBL indirect_endav_vtbl = {
 0,
 0,
 0,
 0,
 indirect_endav_free
#if MGf_COPY
 , 0
#endif
#if MGf_DUP
 , 0
#endif
#if MGf_LOCAL
 , 0
#endif
};

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
 SV              *code = NULL;
#if I_THREADSAFE
 dMY_CXT;

 if (!MY_CXT.tbl)
  return newSViv(0);
#endif /* I_THREADSAFE */

 if (SvROK(value)) {
  value = SvRV(value);
  if (SvTYPE(value) >= SVt_PVCV) {
   code = value;
   SvREFCNT_inc_simple_void_NN(code);
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
 /* We only need for the key to be an unique tag for looking up the value later
  * Allocated memory provides convenient unique identifiers, so that's why we
  * use the hint as the key itself. */
 ptable_hints_store(MY_CXT.tbl, h, h);
#endif /* I_THREADSAFE */

 return newSViv(PTR2IV(h));
}

STATIC SV *indirect_detag(pTHX_ const SV *hint) {
#define indirect_detag(H) indirect_detag(aTHX_ (H))
 indirect_hint_t *h;
#if I_THREADSAFE || I_WORKAROUND_REQUIRE_PROPAGATION
 dMY_CXT;
#endif

#if I_THREADSAFE
 if (!MY_CXT.tbl)
  return NULL;
#endif /* I_THREADSAFE */

 h = INT2PTR(indirect_hint_t *, SvIVX(hint));
#if I_THREADSAFE
 h = ptable_fetch(MY_CXT.tbl, h);
#endif /* I_THREADSAFE */

#if I_WORKAROUND_REQUIRE_PROPAGATION
 if (indirect_require_tag() != h->require_tag)
  return MY_CXT.global_code;
#endif /* I_WORKAROUND_REQUIRE_PROPAGATION */

 return I_HINT_CODE(h);
}

STATIC U32 indirect_hash = 0;

STATIC SV *indirect_hint(pTHX) {
#define indirect_hint() indirect_hint(aTHX)
 SV *hint = NULL;

 if (IN_PERL_RUNTIME)
  return NULL;

#if I_HAS_PERL(5, 10, 0) || defined(PL_parser)
 if (!PL_parser)
  return NULL;
#endif

#ifdef cop_hints_fetch_pvn
 hint = cop_hints_fetch_pvn(PL_curcop, __PACKAGE__, __PACKAGE_LEN__,
                                                              indirect_hash, 0);
#elif I_HAS_PERL(5, 9, 5)
 hint = Perl_refcounted_he_fetch(aTHX_ PL_curcop->cop_hints_hash,
                                       NULL,
                                       __PACKAGE__, __PACKAGE_LEN__,
                                       0,
                                       indirect_hash);
#else
 {
  SV **val = hv_fetch(GvHV(PL_hintgv), __PACKAGE__, __PACKAGE_LEN__, 0);
  if (val)
   hint = *val;
 }
#endif

 if (hint && SvIOK(hint))
  return indirect_detag(hint);
 else {
  dMY_CXT;
  return MY_CXT.global_code;
 }
}

/* ... op -> source position ............................................... */

STATIC void indirect_map_store(pTHX_ const OP *o, STRLEN pos, SV *sv, line_t line) {
#define indirect_map_store(O, P, N, L) indirect_map_store(aTHX_ (O), (P), (N), (L))
 indirect_op_info_t *oi;
 const char *s;
 STRLEN len;
 dMY_CXT;

 /* No need to check for MY_CXT.map != NULL because this code path is always
  * guarded by indirect_hint(). */

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
 oi->pos  = pos;
 oi->line = line;
}

STATIC const indirect_op_info_t *indirect_map_fetch(pTHX_ const OP *o) {
#define indirect_map_fetch(O) indirect_map_fetch(aTHX_ (O))
 dMY_CXT;

 /* No need to check for MY_CXT.map != NULL because this code path is always
  * guarded by indirect_hint(). */

 return ptable_fetch(MY_CXT.map, o);
}

STATIC void indirect_map_delete(pTHX_ const OP *o) {
#define indirect_map_delete(O) indirect_map_delete(aTHX_ (O))
 dMY_CXT;

 if (MY_CXT.map)
  ptable_delete(MY_CXT.map, o);
}

/* --- Check functions ----------------------------------------------------- */

STATIC int indirect_find(pTHX_ SV *name_sv, const char *line_bufptr, STRLEN *name_pos) {
#define indirect_find(NSV, LBP, NP) indirect_find(aTHX_ (NSV), (LBP), (NP))
 STRLEN      name_len, line_len;
 const char *name, *name_end;
 const char *line, *line_end;
 const char *p;

 line     = SvPV_const(PL_linestr, line_len);
 line_end = line + line_len;

 name = SvPV_const(name_sv, name_len);
 if (name_len >= 1 && *name == '$') {
  ++name;
  --name_len;
  while (line_bufptr < line_end && *line_bufptr != '$')
   ++line_bufptr;
  if (line_bufptr >= line_end)
   return 0;
 }
 name_end = name + name_len;

 p = line_bufptr;
 while (1) {
  p = ninstr(p, line_end, name, name_end);
  if (!p)
   return 0;
  if (!isALNUM(p[name_len]))
   break;
  /* p points to a word that has name as prefix, skip the rest of the word */
  p += name_len + 1;
  while (isALNUM(*p))
   ++p;
 }

 *name_pos = p - line;

 return 1;
}

/* ... ck_const ............................................................ */

STATIC OP *(*indirect_old_ck_const)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_const(pTHX_ OP *o) {
 o = indirect_old_ck_const(aTHX_ o);

 if (indirect_hint()) {
  SV *sv = cSVOPo_sv;

  if (SvPOK(sv) && (SvTYPE(sv) >= SVt_PV)) {
   STRLEN pos;

   if (indirect_find(sv, PL_oldbufptr, &pos)) {
    STRLEN len;

    /* If the constant is equal to the current package name, try to look for
     * a "__PACKAGE__" coming before what we got. We only need to check this
     * when we already had a match because __PACKAGE__ can only appear in
     * direct method calls ("new __PACKAGE__" is a syntax error). */
    len = SvCUR(sv);
    if (PL_curstash
        && len == (STRLEN) HvNAMELEN_get(PL_curstash)
        && memcmp(SvPVX(sv), HvNAME_get(PL_curstash), len) == 0) {
     STRLEN pos_pkg;
     SV    *pkg = sv_newmortal();
     sv_setpvn(pkg, "__PACKAGE__", sizeof("__PACKAGE__")-1);

     if (indirect_find(pkg, PL_oldbufptr, &pos_pkg) && pos_pkg < pos) {
      sv  = pkg;
      pos = pos_pkg;
     }
    }

    indirect_map_store(o, pos, sv, CopLINE(&PL_compiling));
    return o;
   }
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
  const char *name = NULL;
  STRLEN pos, len;
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
  if (!indirect_find(sv, PL_oldbufptr, &pos)) {
   /* If it failed, retry without the current stash */
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
   if (!indirect_find(sv, PL_oldbufptr, &pos))
    goto done;
  }

  o = indirect_old_ck_rv2sv(aTHX_ o);

  indirect_map_store(o, pos, sv, CopLINE(&PL_compiling));
  return o;
 }

done:
 o = indirect_old_ck_rv2sv(aTHX_ o);

 indirect_map_delete(o);
 return o;
}

/* ... ck_padany ........................................................... */

STATIC OP *(*indirect_old_ck_padany)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_padany(pTHX_ OP *o) {
 o = indirect_old_ck_padany(aTHX_ o);

 if (indirect_hint()) {
  SV *sv;
  const char *s = PL_oldbufptr, *t = PL_bufptr - 1;

  while (s < t && isSPACE(*s)) ++s;
  if (*s == '$' && ++s <= t) {
   while (s < t && isSPACE(*s)) ++s;
   while (s < t && isSPACE(*t)) --t;
   sv = sv_2mortal(newSVpvn("$", 1));
   sv_catpvn_nomg(sv, s, t - s + 1);
   indirect_map_store(o, s - SvPVX_const(PL_linestr),
                         sv, CopLINE(&PL_compiling));
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
 o = old_ck(aTHX_ o);

 if (indirect_hint()) {
  indirect_map_store(o, PL_oldbufptr - SvPVX_const(PL_linestr),
                        NULL, CopLINE(&PL_compiling));
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

  /* Indirect method call is only possible when the method is a bareword, so
   * don't trip up on $obj->$meth. */
  if (op && op->op_type == OP_CONST) {
   const indirect_op_info_t *oi = indirect_map_fetch(op);
   STRLEN pos;
   line_t line;
   SV *sv;

   if (!oi)
    goto done;

   sv   = sv_2mortal(newSVpvn(oi->buf, oi->len));
   pos  = oi->pos;
   /* Keep the old line so that we really point to the first line of the
    * expression. */
   line = oi->line;

   o = indirect_old_ck_method(aTHX_ o);
   /* o may now be a method_named */

   indirect_map_store(o, pos, sv, line);
   return o;
  }
 }

done:
 o = indirect_old_ck_method(aTHX_ o);

 indirect_map_delete(o);
 return o;
}

/* ... ck_method_named ..................................................... */

/* "use foo/no foo" compiles its call to import/unimport directly to a
 * method_named op. */

STATIC OP *(*indirect_old_ck_method_named)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_method_named(pTHX_ OP *o) {
 if (indirect_hint()) {
  STRLEN pos;
  line_t line;
  SV *sv;

  sv = cSVOPo_sv;
  if (!SvPOK(sv) || (SvTYPE(sv) < SVt_PV))
   goto done;
  sv = sv_mortalcopy(sv);

  if (!indirect_find(sv, PL_oldbufptr, &pos))
   goto done;
  line = CopLINE(&PL_compiling);

  o = indirect_old_ck_method_named(aTHX_ o);

  indirect_map_store(o, pos, sv, line);
  return o;
 }

done:
 o = indirect_old_ck_method_named(aTHX_ o);

 indirect_map_delete(o);
 return o;
}

/* ... ck_entersub ......................................................... */

STATIC OP *(*indirect_old_ck_entersub)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_entersub(pTHX_ OP *o) {
 SV *code = indirect_hint();

 o = indirect_old_ck_entersub(aTHX_ o);

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
  oop = OP_SIBLING(oop);
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
  if (!moi)
   goto done;

  ooi = indirect_map_fetch(oop);
  if (!ooi)
   goto done;

  /* When positions are identical, the method and the object must have the
   * same name. But it also means that it is an indirect call, as "foo->foo"
   * results in different positions. */
  if (   moi->line < ooi->line
      || (moi->line == ooi->line && moi->pos <= ooi->pos)) {
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
 if (!indirect_initialized)
  return;

#if I_MULTIPLICITY
 if (aTHX != root)
  return;
#endif

 {
  dMY_CXT;
  ptable_free(MY_CXT.map);
  MY_CXT.map = NULL;
#if I_THREADSAFE
  ptable_hints_free(MY_CXT.tbl);
  MY_CXT.tbl = NULL;
#endif
 }

 indirect_ck_restore(OP_CONST,   &indirect_old_ck_const);
 indirect_ck_restore(OP_RV2SV,   &indirect_old_ck_rv2sv);
 indirect_ck_restore(OP_PADANY,  &indirect_old_ck_padany);
 indirect_ck_restore(OP_SCOPE,   &indirect_old_ck_scope);
 indirect_ck_restore(OP_LINESEQ, &indirect_old_ck_lineseq);

 indirect_ck_restore(OP_METHOD,       &indirect_old_ck_method);
 indirect_ck_restore(OP_METHOD_NAMED, &indirect_old_ck_method_named);
 indirect_ck_restore(OP_ENTERSUB,     &indirect_old_ck_entersub);

 indirect_initialized = 0;
}

STATIC void indirect_setup(pTHX) {
#define indirect_setup() indirect_setup(aTHX)
 if (indirect_initialized)
  return;

 {
  MY_CXT_INIT;
#if I_THREADSAFE
  MY_CXT.tbl         = ptable_new();
  MY_CXT.owner       = aTHX;
#endif
  MY_CXT.map         = ptable_new();
  MY_CXT.global_code = NULL;
 }

 indirect_ck_replace(OP_CONST,   indirect_ck_const,  &indirect_old_ck_const);
 indirect_ck_replace(OP_RV2SV,   indirect_ck_rv2sv,  &indirect_old_ck_rv2sv);
 indirect_ck_replace(OP_PADANY,  indirect_ck_padany, &indirect_old_ck_padany);
 indirect_ck_replace(OP_SCOPE,   indirect_ck_scope,  &indirect_old_ck_scope);
 indirect_ck_replace(OP_LINESEQ, indirect_ck_scope,  &indirect_old_ck_lineseq);

 indirect_ck_replace(OP_METHOD,       indirect_ck_method,
                                      &indirect_old_ck_method);
 indirect_ck_replace(OP_METHOD_NAMED, indirect_ck_method_named,
                                      &indirect_old_ck_method_named);
 indirect_ck_replace(OP_ENTERSUB,     indirect_ck_entersub,
                                      &indirect_old_ck_entersub);

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
 SV     *global_code_dup;
 GV     *gv;
PPCODE:
 {
  indirect_ptable_clone_ud ud;
  dMY_CXT;
  t = ptable_new();
  indirect_ptable_clone_ud_init(ud, t, MY_CXT.owner);
  ptable_walk(MY_CXT.tbl, indirect_ptable_clone, &ud);
  global_code_dup = indirect_dup_inc(MY_CXT.global_code, &ud);
  indirect_ptable_clone_ud_deinit(ud);
 }
 {
  MY_CXT_CLONE;
  MY_CXT.map         = ptable_new();
  MY_CXT.tbl         = t;
  MY_CXT.owner       = aTHX;
  MY_CXT.global_code = global_code_dup;
 }
 gv = gv_fetchpv(__PACKAGE__ "::_THREAD_CLEANUP", 0, SVt_PVCV);
 if (gv) {
  CV *cv = GvCV(gv);
  if (!PL_endav)
   PL_endav = newAV();
  SvREFCNT_inc(cv);
  if (!av_store(PL_endav, av_len(PL_endav) + 1, (SV *) cv))
   SvREFCNT_dec(cv);
  sv_magicext((SV *) PL_endav, NULL, PERL_MAGIC_ext, &indirect_endav_vtbl, NULL, 0);
 }
 XSRETURN(0);

void
_THREAD_CLEANUP(...)
PROTOTYPE: DISABLE
PPCODE:
 indirect_thread_cleanup(aTHX_ NULL);
 XSRETURN(0);

#endif

SV *
_tag(SV *value)
PROTOTYPE: $
CODE:
 RETVAL = indirect_tag(value);
OUTPUT:
 RETVAL

void
_global(SV *code)
PROTOTYPE: $
PPCODE:
 if (!SvOK(code))
  code = NULL;
 else if (SvROK(code))
  code = SvRV(code);
 {
  dMY_CXT;
  SvREFCNT_dec(MY_CXT.global_code);
  MY_CXT.global_code = SvREFCNT_inc(code);
 }
 XSRETURN(0);
