/*
 * CDDL HEADER START
 *
 * The contents of this file are subject to the terms of the
 * Common Development and Distribution License (the "License").  
 * You may not use this file except in compliance with the License.
 *
 * See LICENSE.txt included in this distribution for the specific
 * language governing permissions and limitations under the License.
 *
 * When distributing Covered Code, include this CDDL HEADER in each
 * file and include the License file at LICENSE.txt.
 * If applicable, add the following below this CDDL HEADER, with the
 * fields enclosed by brackets "[]" replaced with your own identifying
 * information: Portions Copyright [yyyy] [name of copyright owner]
 *
 * CDDL HEADER END
 */

/*
 * Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved.
 * Portions Copyright (c) 2017, Chris Fraire <cfraire@me.com>.
 */

/*
 * Gets Perl symbols - ignores comments, strings, keywords
 */

package org.opensolaris.opengrok.analysis.perl;
import java.io.IOException;
import java.io.Reader;
import org.opensolaris.opengrok.analysis.JFlexTokenizer;

%%
%public
%class PerlSymbolTokenizer
%extends JFlexTokenizer
%implements PerlLexListener
%unicode
%init{
super(in);

        h = new PerlLexHelper(QUO, QUOxN, QUOxL, QUOxLxN, this,
            HERE, HERExN, HEREin, HEREinxN);
%init}
%{
    private final PerlLexHelper h;

    private String lastSymbol;

    private int lastSymbolOffset;

    public void pushState(int state) { yypush(state); }

    public void popState() throws IOException { yypop(); }

    public void write(String value) throws IOException { /* noop */ }

    public void writeHtmlized(String value) throws IOException {
        // noop
    }

    public void writeSymbol(String value, int captureOffset, boolean ignoreKwd)
            throws IOException {
        if (ignoreKwd || !Consts.kwd.contains(value)) {
            lastSymbol = value;
            lastSymbolOffset = captureOffset;
        } else {
            lastSymbol = null;
            lastSymbolOffset = 0;
        }
    }

    public void skipSymbol() {
        lastSymbol = null;
        lastSymbolOffset = 0;
    }

    public void writeKeyword(String value) throws IOException {
        lastSymbol = value;
        lastSymbolOffset = 0;
    }

    public void doStartNewLine() throws IOException { /* noop */ }

    public void abortQuote() throws IOException {
        yypop();
        if (h.areModifiersOK()) yypush(QM);
    }

    public void pushback(int numChars) {
        yypushback(numChars);
    }

    // If the state is YYINITIAL, then transitions to INTRA; otherwise does
    // nothing, because other transitions would have saved the state.
    void maybeIntraState() {
        if (yystate() == YYINITIAL) yybegin(INTRA);
    }
%}
%type boolean
%eofval{
this.finalOffset =  zzEndRead;
return false;
%eofval}
%char

WhspChar      = [ \t\f]
WhiteSpace    = {WhspChar}+
MaybeWhsp     = {WhspChar}*
EOL = \r|\n|\r\n
Identifier = [a-zA-Z_] [a-zA-Z0-9_]*
Sigils = ("$" | "@" | "%" | "&" | "*")
WxSigils = [[\W]--[\$\@\%\&\*]]

// Perl special identifiers (four of six from
// https://perldoc.perl.org/perldata.html#Identifier-parsing):
//
// 1. A sigil, followed solely by digits matching \p{POSIX_Digit} , like $0 ,
// $1 , or $10000 .
SPIdentifier1 = "$" \d+

// 2. A sigil followed by a single character matching the \p{POSIX_Punct}
// property, like $! or %+ , except the character "{" doesn't work.
SPIdentifier2 = [\$\%] [[\p{P}--{]]

// 3. A sigil, followed by a caret and any one of the characters [][A-Z^_?\\] ,
// like $^V or $^] .
SPIdentifier3 = "$^" ( "]" | "[" | [A-Z\^_?\\] )

// 4. Similar to the above, a sigil, followed by bareword text in braces, where
// the first character is a caret. The next character is any one of the
// characters [][A-Z^_?\\] , followed by ASCII word characters. An example is
// ${^GLOBAL_PHASE} . ASCII \w matches the 63 characters: [a-zA-Z0-9_].
SPIdentifier4 = "${^" ( "]" | "[" | [A-Z\^_?\\] ) [a-zA-Z0-9_]* "}"

// prototype attribute must be recognized explicitly or else "($)" can be
// mistaken for an SPIdentifier2
ProtoAttr = "(" ( [\\]? {Sigils} | ";" | {WhiteSpace} )* ")"

FNameChar = [a-zA-Z0-9_\-\.]
FileExt = ("pl"|"perl"|"pm"|"conf"|"txt"|"htm"|"html"|"xml"|"ini"|"diff"|"patch"|
           "PL"|"PERL"|"PM"|"CONF"|"TXT"|"HTM"|"HTML"|"XML"|"INI"|"DIFF"|"PATCH")
File = [a-zA-Z]{FNameChar}* "." {FileExt}
Path = "/"? [a-zA-Z]{FNameChar}* ("/" [a-zA-Z]{FNameChar}*[a-zA-Z0-9])+

Number = (0[xX][0-9a-fA-F]+|[0-9]+\.[0-9]+|[0-9][0-9_]*)([eE][+-]?[0-9]+)?

PodEND = "=cut"

Quo0 =           [[\`\(\)\<\>\[\]\{\}\p{P}\p{S}]]
Quo0xHash =      [[\`\(\)\<\>\[\]\{\}\p{P}\p{S}]--\#]
Quo0xHashxApos = [[\`\(\)\<\>\[\]\{\}\p{P}\p{S}]--[\#\']]

MSapos = [ms] {MaybeWhsp} \'
MShash = [ms]\#
MSpunc = [ms] {MaybeWhsp} {Quo0xHashxApos}
MSword = [ms] {WhiteSpace} \w
QYhash = [qy]\#
QYpunc = [qy] {MaybeWhsp} {Quo0xHash}
QYword = [qy] {WhiteSpace} \w

QXRapos  = "q"[xr] {MaybeWhsp} \'
QQXRhash = "q"[qxr]\#
QQXRPunc = "q"[qxr] {MaybeWhsp} {Quo0xHash}
QQXRword = "q"[qxr] {WhiteSpace} \w

QWhash = "qw"\#
QWpunc = "qw" {MaybeWhsp} {Quo0xHash}
QWword = "qw" {WhiteSpace} \w
TRhash = "tr"\#
TRpunc = "tr" {MaybeWhsp} {Quo0xHash}
TRword = "tr" {WhiteSpace} \w

HereContinuation = \,{MaybeWhsp} "<<"\~? {MaybeWhsp}
MaybeHereMarkers = ([\"\'\`\\]?{Identifier} [^\n\r]* {HereContinuation})?

//
// Track some keywords that can be used to identify heuristically a possible
// beginning of the shortcut syntax, //, for m//. Also include any perlfunc
// that takes /PATTERN/ -- which is just "split". Heuristics using punctuation
// are defined inline later in some rules.
//
Mwords_1 = ("eq" | "ne" | "le" | "ge" | "lt" | "gt" | "cmp")
Mwords_2 = ("if" | "unless" | "or" | "and" | "not")
Mwords_3 = ("split")
Mwords = ({Mwords_1} | {Mwords_2} | {Mwords_3})

Mpunc1YYIN = [\(\!]
Mpunc2IN = ([!=]"~" | [\:\?\=\+\-\<\>] | "=="|"!="|"<="|">="|"<=>")

//
// There are two dimensions to quoting: "link"-or-not and "interpolate"-or-not.
// Unfortunately, we cannot control the %state values, so we have to declare
// a cross-product of states. (Technically, state values are not guaranteed to
// be unique by jflex, but states that do not have identical rules will have
// different values. The following four "QUO" states satisfy this difference
// criterion. Likewise with the four "HERE" states.)
//
// YYINITIAL : nothing yet parsed or just after a non-quoted [;{}]
// INTRA : saw content from YYINITIAL but not yet other state or [;{}]
// SCOMMENT : single-line comment
// POD : Perl Plain-Old-Documentation
// QUO : quote-like that is OK to match paths|files|URLs|e-mails
// QUOxN : "" but with no interpolation
// QUOxL : quote-like that is not OK to match paths|files|URLs|e-mails
//      because a non-traditional character is used as the quote-like delimiter
// QUOxLxN : "" but with no interpolation
// QM : a quote-like has ended, and quote modifier chars are awaited
// HERE : Here-docs
// HERExN : Here-docs with no interpolation
// HEREin : Indented Here-docs
// HEREinxN : Indented Here-docs with no interpolation
// FMT : an output record format
//
%state INTRA SCOMMENT POD FMT QUO QUOxN QUOxL QUOxLxN QM HERE HERExN HEREin HEREinxN

%%
<HERE, HERExN> {
    ^ {Identifier} / {MaybeWhsp}{EOL}    {
        if (h.maybeEndHere(yytext())) yyjump(YYINITIAL);
    }
}

<HEREin, HEREinxN> {
    ^ {MaybeWhsp} {Identifier} / {MaybeWhsp}{EOL}    {
        if (h.maybeEndHere(yytext())) yyjump(YYINITIAL);
    }
}

<YYINITIAL, INTRA>{

    [;\{\}] |
    "&&" |
    "||" |
    {ProtoAttr}    {
        yyjump(YYINITIAL);
    }

 // Following are rules for Here-documents. Stacked multiple here-docs are
 // recognized, but not fully supported, as only the interpolation setting
 // of the first marker will apply to all sections. (The final, second HERE
 // quoting character is not demanded, as it is superfluous for the needs of
 // xref lexing; and leaving it off simplifies parsing.)

 "<<"  {MaybeWhsp} {MaybeHereMarkers} [\"\`]?{Identifier}    {
    h.hop(yytext(), false/*nointerp*/, false/*indented*/);
 }
 "<<~" {MaybeWhsp} {MaybeHereMarkers} [\"\`]?{Identifier}    {
    h.hop(yytext(), false/*nointerp*/, true/*indented*/);
 }
 "<<"  {MaybeWhsp} {MaybeHereMarkers} [\'\\]{Identifier}    {
    h.hop(yytext(), true/*nointerp*/, false/*indented*/);
 }
 "<<~" {MaybeWhsp} {MaybeHereMarkers} [\'\\]{Identifier}    {
    h.hop(yytext(), true/*nointerp*/, true/*indented*/);
 }

{Identifier} {
    maybeIntraState();
    String id = yytext();
    if (!Consts.kwd.contains(id)){
        setAttribs(id, yychar, yychar + yylength());
        return true;
    }
}

"<" ({File}|{Path}) ">" {
        maybeIntraState();
}

{Number}        {
    maybeIntraState();
}

 [\"\`] { h.qop(yytext(), 0, false); }
 \'     { h.qop(yytext(), 0, true); }
 \#     {
        yypush(SCOMMENT);
 }

 // qq//, qx//, qw//, qr/, tr/// and variants -- all with 2 character names
 ^ {QXRapos} |
 {WxSigils}{QXRapos}   { h.qop(yytext(), 2, true); } // qx'' qr''
 ^ {QQXRhash} |
 {WxSigils}{QQXRhash}  { h.qop(yytext(), 2, false); }
 ^ {QQXRPunc} |
 {WxSigils}{QQXRPunc}  { h.qop(yytext(), 2, false); }
 ^ {QQXRword} |
 {WxSigils}{QQXRword}  { h.qop(yytext(), 2, false); }

// In Perl these do not actually "interpolate," but "interpolate" for OpenGrok
// xref just means to cross-reference, which is appropriate for qw//.
 ^ {QWhash} |
 {WxSigils}{QWhash}  { h.qop(yytext(), 2, false); }
 ^ {QWpunc} |
 {WxSigils}{QWpunc}  { h.qop(yytext(), 2, false); }
 ^ {QWword} |
 {WxSigils}{QWword}  { h.qop(yytext(), 2, false); }

 ^ {TRhash} |
 {WxSigils}{TRhash}  { h.qop(yytext(), 2, true); }
 ^ {TRpunc} |
 {WxSigils}{TRpunc}  { h.qop(yytext(), 2, true); }
 ^ {TRword} |
 {WxSigils}{TRword}  { h.qop(yytext(), 2, true); }

 // q//, m//, s//, y// and variants -- all with 1 character names
 ^ {MSapos} |
 {WxSigils}{MSapos}  { h.qop(yytext(), 1, true); } // m'' s''
 ^ {MShash} |
 {WxSigils}{MShash}  { h.qop(yytext(), 1, false); }
 ^ {MSpunc} |
 {WxSigils}{MSpunc}  { h.qop(yytext(), 1, false); }
 ^ {MSword} |
 {WxSigils}{MSword}  { h.qop(yytext(), 1, false); }
 ^ {QYhash} |
 {WxSigils}{QYhash}  { h.qop(yytext(), 1, true); }
 ^ {QYpunc} |
 {WxSigils}{QYpunc}  { h.qop(yytext(), 1, true); }
 ^ {QYword} |
 {WxSigils}{QYword}  { h.qop(yytext(), 1, true); }

 ^ {PodEND} [^\n\r]*    {
 }

 // POD start
 ^ "=" [a-zA-Z_] [a-zA-Z0-9_]*    {
        yypush(POD);
 }

 // FORMAT start
 ^ {MaybeWhsp} "format" ({WhiteSpace} {Identifier})? {MaybeWhsp} "="    {
    yypush(FMT);
 }
}

<YYINITIAL> {
    "/"    {
        // OK to pass a fake "m/" with doWrite=false
        h.qop(false, "m/", 1, false);
    }
}

<YYINITIAL, INTRA> {
    // Use some heuristics to identify double-slash syntax for the m//
    // operator. We can't handle all possible appearances of `//', because the
    // first slash cannot always be distinguished from division (/) without
    // true parsing.

    {Mpunc1YYIN} \s* "/"    { h.hqopPunc(yytext()); }
}

<INTRA> {
    // Continue with more punctuation heuristics

    {Mpunc2IN} \s* "/"      { h.hqopPunc(yytext()); }
}

<YYINITIAL, INTRA> {
    // Define keyword heuristics

    ^ {Mwords} \s* "/"    {
        h.hqopSymbol(yytext());
    }

    {WxSigils}{Mwords} \s* "/"    {
        String capture = yytext();
        h.hqopSymbol(capture.substring(1));
    }
}

<YYINITIAL, INTRA> {
    {Sigils} {MaybeWhsp} {Identifier} {
        maybeIntraState();
        //we ignore keywords if the identifier starts with a sigil ...
        h.sigilID(yytext());
        if (lastSymbol != null) {
            setAttribs(lastSymbol, yychar + lastSymbolOffset, yychar +
                lastSymbolOffset + lastSymbol.length());
            return true;
        }
    }
}

<YYINITIAL, INTRA, FMT, QUO, QUOxL, HERE, HEREin> {
    {Sigils} {MaybeWhsp} "{" {MaybeWhsp} {Identifier} {MaybeWhsp} "}" {
        maybeIntraState();
        //we ignore keywords if the identifier starts with a sigil ...
        h.bracedSigilID(yytext());
        setAttribs(lastSymbol, yychar + lastSymbolOffset, yychar +
            lastSymbolOffset + lastSymbol.length());
        return true;
    }

    {SPIdentifier1} |
    {SPIdentifier2} |
    {SPIdentifier3} |
    {SPIdentifier4} {
        maybeIntraState();
        h.specialID(yytext());
    }
}

<FMT, QUO, QUOxL, HERE, HEREin> {
    {Sigils} {Identifier} {
        //we ignore keywords if the identifier starts with a sigil ...
        h.sigilID(yytext());
        if (lastSymbol != null) {
            setAttribs(lastSymbol, yychar + lastSymbolOffset, yychar +
                lastSymbolOffset + lastSymbol.length());
            return true;
        }
    }
}

<QUO, QUOxN, QUOxL, QUOxLxN> {
    \\[\&\<\>\"\']    {
    }
    \\ \S    {
    }
    {Quo0} |
    \w    {
        String capture = yytext();
        if (h.isQuoteEnding(capture)) {
            yypop();
            if (h.areModifiersOK()) yypush(QM);
        }
    }
}

<FMT, QUO, QUOxN, QUOxL, QUOxLxN, HERE, HERExN, HEREin, HEREinxN> {
    {WhiteSpace}{EOL} |
    {EOL} {
        // noop
    }
}

<QM> {
    // m/PATTERN/msixpodualngc and /PATTERN/msixpodualngc
    // qr/STRING/msixpodualn
    // s/PATTERN/REPLACEMENT/msixpodualngcer
    // tr/SEARCHLIST/REPLACEMENTLIST/cdsr
    // y/SEARCHLIST/REPLACEMENTLIST/cdsr
    [a-z]    {
        // noop
    }
    [^]    {
        yypop();
        yypushback(1);
    }
}

<POD> {
^ {PodEND} [^\n\r]*    {
    yypop();
  }
}

<FMT> {
    // terminate a format
    ^ "." / {MaybeWhsp} {EOL}    {
        yypop();
    }

    // "A comment, indicated by putting a '#' in the first column."
    ^ "#" [^\n\r]*    {
        /* noop */
    }

    // The other two types of line in a format FORMLIST -- "a 'picture' line
    // giving the format for one output line" and "an argument line supplying
    // values to plug into the previous picture line" -- are not handled
    // in a particular way by this lexer.
}

<SCOMMENT> {
  {WhiteSpace}{EOL} |
  {EOL} {
    yypop();
  }
}

<YYINITIAL, INTRA, SCOMMENT, POD, FMT, QUO, QUOxN, QUOxL, QUOxLxN,
    HERE, HERExN, HEREin, HEREinxN> {
<<EOF>>   { this.finalOffset =  zzEndRead; return false;}
 [&<>\"\']      {
        maybeIntraState();
 }
 {WhiteSpace}{EOL} |
 {EOL}          {
        // noop
 }

 // Only one whitespace char at a time or else {WxSigils} can be broken
 {WhspChar}     {
        // noop
 }
 [!-~]          {
        maybeIntraState();
 }
 [^\n\r]          {
        maybeIntraState();
 }
}

// "string links" and "comment links" are not processed specially
