require "parslet"

# Expr           = ConditionalOr ["?" ConditionalOr ":" Expr] ;
# ConditionalOr  = [ConditionalOr "||"] ConditionalAnd ;
# ConditionalAnd = [ConditionalAnd "&&"] Relation ;
# Relation       = [Relation Relop] Addition ;
# Relop          = "<" | "<=" | ">=" | ">" | "==" | "!=" | "in" ;
# Addition       = [Addition ("+" | "-")] Multiplication ;
# Multiplication = [Multiplication ("*" | "/" | "%")] Unary ;
# Unary          = Member
#                | "!" {"!"} Member
#                | "-" {"-"} Member
#                ;
# Member         = Primary
#                | Member "." IDENT ["(" [ExprList] ")"]
#                | Member "[" Expr "]"
#                | Member "{" [FieldInits] "}"
#                ;
# Primary        = ["."] IDENT ["(" [ExprList] ")"]
#                | "(" Expr ")"
#                | "[" [ExprList] "]"
#                | "{" [MapInits] "}"
#                | LITERAL
#                ;
# ExprList       = Expr {"," Expr} ;
# FieldInits     = IDENT ":" Expr {"," IDENT ":" Expr} ;
# MapInits       = Expr ":" Expr {"," Expr ":" Expr} ;

# IDENT          ::= [_a-zA-Z][_a-zA-Z0-9]* - RESERVED
# LITERAL        ::= INT_LIT | UINT_LIT | FLOAT_LIT | STRING_LIT | BYTES_LIT
# | BOOL_LIT | NULL_LIT
# INT_LIT        ::= -? DIGIT+ | -? 0x HEXDIGIT+
# UINT_LIT       ::= INT_LIT [uU]
# FLOAT_LIT      ::= -? DIGIT* . DIGIT+ EXPONENT? | -? DIGIT+ EXPONENT
# DIGIT          ::= [0-9]
# HEXDIGIT       ::= [0-9abcdefABCDEF]
# EXPONENT       ::= [eE] [+-]? DIGIT+
# STRING_LIT     ::= [rR]? ( "    ~( " | NEWLINE )*  "
#         | '    ~( ' | NEWLINE )*  '
#         | """  ~"""*              """
#         | '''  ~'''*              '''
#         )
# BYTES_LIT      ::= [bB] STRING_LIT
# ESCAPE         ::= \ [bfnrt"'\]
# | \ x HEXDIGIT HEXDIGIT
# | \ u HEXDIGIT HEXDIGIT HEXDIGIT HEXDIGIT
# | \ U HEXDIGIT HEXDIGIT HEXDIGIT HEXDIGIT HEXDIGIT HEXDIGIT HEXDIGIT HEXDIGIT
# | \ [0-3] [0-7] [0-7]
# NEWLINE        ::= \r\n | \r | \n
# BOOL_LIT       ::= "true" | "false"
# NULL_LIT       ::= "null"
# RESERVED       ::= BOOL_LIT | NULL_LIT | "in"
# | "as" | "break" | "const" | "continue" | "else"
# | "for" | "function" | "if" | "import" | "let"
# | "loop" | "package" | "namespace" | "return"
# | "var" | "void" | "while"
# WHITESPACE     ::= [\t\n\f\r ]+
# COMMENT        ::= '//' ~NEWLINE* NEWLINE

module Cel
  class Parser < Parslet::Parser
    def spaced(character = nil)
      space.repeat >> (block_given? ? yield : str(character)) >> space.repeat
    end

    root :op

    rule(:op) do
      comment | (expr >> newline.maybe)
    end

    rule(:expr) do
      conditional_or >> (spaced("?") >> conditional_or >> spaced(":") >> expr).maybe
    end

    rule(:conditional_or) do
      (conditional_and >> spaced("||")).maybe >> conditional_and
    end

    rule(:conditional_and) do
      (relation >> spaced("&&")).maybe >> relation
    end

    rule(:relation) do
      (addition >> spaced { relop }).repeat >> addition
    end

    rule(:addition) do
      (multiplication >> spaced { match["+-"] }).repeat >> multiplication
    end

    rule(:multiplication) do
      (unary >> spaced { match["*/%"] }).repeat >> unary
    end

    rule(:unary) do
      (match("!!?") | match("--?")).maybe >> member
    end

    rule(:member) do
      primary >> (primary | member_suffix).repeat
    end

    rule(:member_suffix) do
      (str(".") >> ident >> (str("(") >> expr_list.maybe >> str(")")).maybe) |
      (str("[") >> expr >> str("]")) |
      (str("{") >> field_inits.maybe >> str("}"))
    end

    rule(:primary) do
      (str(".").maybe >> ident >> (str("(") >> expr_list >> str(")")).maybe) |
      (str("(") >> spaced { expr } >> str(")")) |
      (str("[") >> spaced { expr_list } >> str("]")) |
      (str("{") >> spaced { map_inits } >> str("}")) |
      literal
    end

    rule(:expr_list) { expr >> (str(",") >> expr).repeat }

    rule(:field_inits) { ident >> str(":") >> space.repeat >> expr >> (spaced(",") >> ident >> str(":") >> space.repeat >> expr).repeat }
    
    rule(:map_inits) { expr >> str(":") >> space.repeat >> expr >> (spaced(",") >> expr >> str(":") >> space.repeat >> expr).repeat }

    rule(:relop) do
      str("<") | str("<=") | str(">=") | str(">") | str("==") | str("!=") | str("in")
    end

    rule(:ident) { reserved.absent? >> match("[_a-zA-Z]") >> match("[_a-zA-Z0-9]").repeat }

    rule(:literal) do
      float_lit | uint_lit | int_lit | bool_lit | null_lit | bytes_lit | string_lit
    end

    rule(:null_lit) { str("null") }
    
    rule(:bool_lit) { str("true") | str("false") }

    rule(:bytes_lit) { match["bB"] >> string_lit }

    rule(:string_lit) do
      # double-quotes
      (
        str('"') >> (
          str('\\') >> any | str('"').absent? >> any
        ).repeat >> str('"')
      ) |
      # single-quotes
      (
        str("'") >> (
          str('\\') >> any | str("'").absent? >> any
        ).repeat >> str("'")
      )
    end

    rule(:uint_lit) do
      integer >> match["uU"]
    end

    rule(:int_lit) do
      integer | (str("-").maybe >> str("0x") >> hexdigit.repeat(1))
    end

    rule(:float_lit) do
      # may be negative
      int_lit >> str(".") >> digit.repeat(1) >> exponent.maybe |
      int_lit >> exponent
    end

    rule(:integer) do
      str("-").maybe >> (
        # may be 0, or 1234567632
        str("0") | (match("[1-9]") >> digit.repeat)
      )
    end

    rule(:exponent) { match["eE"] >> match["+-"].maybe >> digit.repeat(1) }
    rule(:digit) { match["0-9"] }
    rule(:hexdigit) { match["0-9abcdefABCDEF"] }
    rule(:space) do
      # this rule match all not important text
      match('[ \t]').repeat(1)
    end

    rule(:comment) { str("//") >> (newline.absent? >> any).repeat >> newline }

    rule(:newline) { match("\r\n") | match["\r\n"] }

    rule(:space) do
      # this rule match all not important text
      match('[ \t\r\n]') | comment
    end

    rule(:reserved) do
      bool_lit | null_lit | str("in") |
      str("as") | str("break") | str("const") | str("continue") | str("else") |
      str("for") | str("function") | str("if") | str("import") | str("let") |
      str("loop") | str("package") | str("namespace") | str("return") |
      str("var") | str("void") | str("while")
    end
  end
end

DATA.each_line do |operation|
  puts "evaluating: #{operation.inspect}..."
  puts Cel::Parser.new.parse(operation).inspect
end

__END__
a.b.c == 1
d > 2
a.b.c == 1 && d > 2
a.b.c
123
12345
1.2
1e2
-1.2e2
" Some String with \"escapes\""
'another string'
wiri
// a.driving_license = "CA"
// 1 = 2
// 2 = "a"
// a.b.c > "a"
