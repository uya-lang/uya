package lexer

import "fmt"

// TokenType represents the type of a token
type TokenType int

// Token type constants - matching C lexer.h
const (
	TOKEN_EOF TokenType = iota
	TOKEN_IDENTIFIER
	TOKEN_NUMBER
	TOKEN_STRING
	TOKEN_CHAR

	// Keywords
	TOKEN_STRUCT
	TOKEN_MUT
	TOKEN_CONST
	TOKEN_VAR
	TOKEN_FN
	TOKEN_RETURN
	TOKEN_EXTERN
	TOKEN_TRUE
	TOKEN_FALSE
	TOKEN_IF
	TOKEN_ELSE
	TOKEN_FOR
	TOKEN_WHILE
	TOKEN_BREAK
	TOKEN_CONTINUE
	TOKEN_DEFER
	TOKEN_ERRDEFER
	TOKEN_TRY
	TOKEN_CATCH
	TOKEN_ERROR
	TOKEN_NULL
	TOKEN_INTERFACE
	TOKEN_IMPL
	TOKEN_ENUM
	TOKEN_ATOMIC
	TOKEN_MAX
	TOKEN_MIN
	TOKEN_AS
	TOKEN_AS_EXCLAMATION
	TOKEN_TYPE
	TOKEN_MC
	TOKEN_MATCH

	// Operators
	TOKEN_PLUS
	TOKEN_MINUS
	TOKEN_ASTERISK
	TOKEN_SLASH
	TOKEN_PERCENT
	TOKEN_ASSIGN
	TOKEN_EQUAL
	TOKEN_NOT_EQUAL
	TOKEN_LESS
	TOKEN_LESS_EQUAL
	TOKEN_GREATER
	TOKEN_GREATER_EQUAL
	TOKEN_LEFT_PAREN
	TOKEN_RIGHT_PAREN
	TOKEN_LEFT_BRACE
	TOKEN_RIGHT_BRACE
	TOKEN_LEFT_BRACKET
	TOKEN_RIGHT_BRACKET
	TOKEN_SEMICOLON
	TOKEN_COMMA
	TOKEN_DOT
	TOKEN_COLON
	TOKEN_EXCLAMATION
	TOKEN_AMPERSAND
	TOKEN_PIPE
	TOKEN_CARET
	TOKEN_TILDE
	TOKEN_LEFT_SHIFT
	TOKEN_RIGHT_SHIFT
	TOKEN_LOGICAL_AND
	TOKEN_LOGICAL_OR

	// Saturation operators (explicit overflow handling)
	TOKEN_PLUS_PIPE      // +|
	TOKEN_MINUS_PIPE     // -|
	TOKEN_ASTERISK_PIPE  // *|

	// Wrapping operators (explicit overflow handling)
	TOKEN_PLUS_PERCENT   // +%
	TOKEN_MINUS_PERCENT  // -%
	TOKEN_ASTERISK_PERCENT // *%

	// Special symbols
	TOKEN_ARROW    // =>
	TOKEN_ELLIPSIS // ...
	TOKEN_RANGE    // ..
)

// String returns the string representation of a TokenType
func (tt TokenType) String() string {
	switch tt {
	case TOKEN_EOF:
		return "TOKEN_EOF"
	case TOKEN_IDENTIFIER:
		return "TOKEN_IDENTIFIER"
	case TOKEN_NUMBER:
		return "TOKEN_NUMBER"
	case TOKEN_STRING:
		return "TOKEN_STRING"
	case TOKEN_CHAR:
		return "TOKEN_CHAR"
	case TOKEN_STRUCT:
		return "TOKEN_STRUCT"
	case TOKEN_MUT:
		return "TOKEN_MUT"
	case TOKEN_CONST:
		return "TOKEN_CONST"
	case TOKEN_VAR:
		return "TOKEN_VAR"
	case TOKEN_FN:
		return "TOKEN_FN"
	case TOKEN_RETURN:
		return "TOKEN_RETURN"
	case TOKEN_EXTERN:
		return "TOKEN_EXTERN"
	case TOKEN_TRUE:
		return "TOKEN_TRUE"
	case TOKEN_FALSE:
		return "TOKEN_FALSE"
	case TOKEN_IF:
		return "TOKEN_IF"
	case TOKEN_ELSE:
		return "TOKEN_ELSE"
	case TOKEN_FOR:
		return "TOKEN_FOR"
	case TOKEN_WHILE:
		return "TOKEN_WHILE"
	case TOKEN_BREAK:
		return "TOKEN_BREAK"
	case TOKEN_CONTINUE:
		return "TOKEN_CONTINUE"
	case TOKEN_DEFER:
		return "TOKEN_DEFER"
	case TOKEN_ERRDEFER:
		return "TOKEN_ERRDEFER"
	case TOKEN_TRY:
		return "TOKEN_TRY"
	case TOKEN_CATCH:
		return "TOKEN_CATCH"
	case TOKEN_ERROR:
		return "TOKEN_ERROR"
	case TOKEN_NULL:
		return "TOKEN_NULL"
	case TOKEN_INTERFACE:
		return "TOKEN_INTERFACE"
	case TOKEN_IMPL:
		return "TOKEN_IMPL"
	case TOKEN_ENUM:
		return "TOKEN_ENUM"
	case TOKEN_ATOMIC:
		return "TOKEN_ATOMIC"
	case TOKEN_MAX:
		return "TOKEN_MAX"
	case TOKEN_MIN:
		return "TOKEN_MIN"
	case TOKEN_AS:
		return "TOKEN_AS"
	case TOKEN_AS_EXCLAMATION:
		return "TOKEN_AS_EXCLAMATION"
	case TOKEN_TYPE:
		return "TOKEN_TYPE"
	case TOKEN_MC:
		return "TOKEN_MC"
	case TOKEN_MATCH:
		return "TOKEN_MATCH"
	case TOKEN_PLUS:
		return "TOKEN_PLUS"
	case TOKEN_MINUS:
		return "TOKEN_MINUS"
	case TOKEN_ASTERISK:
		return "TOKEN_ASTERISK"
	case TOKEN_SLASH:
		return "TOKEN_SLASH"
	case TOKEN_PERCENT:
		return "TOKEN_PERCENT"
	case TOKEN_ASSIGN:
		return "TOKEN_ASSIGN"
	case TOKEN_EQUAL:
		return "TOKEN_EQUAL"
	case TOKEN_NOT_EQUAL:
		return "TOKEN_NOT_EQUAL"
	case TOKEN_LESS:
		return "TOKEN_LESS"
	case TOKEN_LESS_EQUAL:
		return "TOKEN_LESS_EQUAL"
	case TOKEN_GREATER:
		return "TOKEN_GREATER"
	case TOKEN_GREATER_EQUAL:
		return "TOKEN_GREATER_EQUAL"
	case TOKEN_LEFT_PAREN:
		return "TOKEN_LEFT_PAREN"
	case TOKEN_RIGHT_PAREN:
		return "TOKEN_RIGHT_PAREN"
	case TOKEN_LEFT_BRACE:
		return "TOKEN_LEFT_BRACE"
	case TOKEN_RIGHT_BRACE:
		return "TOKEN_RIGHT_BRACE"
	case TOKEN_LEFT_BRACKET:
		return "TOKEN_LEFT_BRACKET"
	case TOKEN_RIGHT_BRACKET:
		return "TOKEN_RIGHT_BRACKET"
	case TOKEN_SEMICOLON:
		return "TOKEN_SEMICOLON"
	case TOKEN_COMMA:
		return "TOKEN_COMMA"
	case TOKEN_DOT:
		return "TOKEN_DOT"
	case TOKEN_COLON:
		return "TOKEN_COLON"
	case TOKEN_EXCLAMATION:
		return "TOKEN_EXCLAMATION"
	case TOKEN_AMPERSAND:
		return "TOKEN_AMPERSAND"
	case TOKEN_PIPE:
		return "TOKEN_PIPE"
	case TOKEN_CARET:
		return "TOKEN_CARET"
	case TOKEN_TILDE:
		return "TOKEN_TILDE"
	case TOKEN_LEFT_SHIFT:
		return "TOKEN_LEFT_SHIFT"
	case TOKEN_RIGHT_SHIFT:
		return "TOKEN_RIGHT_SHIFT"
	case TOKEN_LOGICAL_AND:
		return "TOKEN_LOGICAL_AND"
	case TOKEN_LOGICAL_OR:
		return "TOKEN_LOGICAL_OR"
	case TOKEN_PLUS_PIPE:
		return "TOKEN_PLUS_PIPE"
	case TOKEN_MINUS_PIPE:
		return "TOKEN_MINUS_PIPE"
	case TOKEN_ASTERISK_PIPE:
		return "TOKEN_ASTERISK_PIPE"
	case TOKEN_PLUS_PERCENT:
		return "TOKEN_PLUS_PERCENT"
	case TOKEN_MINUS_PERCENT:
		return "TOKEN_MINUS_PERCENT"
	case TOKEN_ASTERISK_PERCENT:
		return "TOKEN_ASTERISK_PERCENT"
	case TOKEN_ARROW:
		return "TOKEN_ARROW"
	case TOKEN_ELLIPSIS:
		return "TOKEN_ELLIPSIS"
	case TOKEN_RANGE:
		return "TOKEN_RANGE"
	default:
		return fmt.Sprintf("TOKEN_UNKNOWN(%d)", tt)
	}
}

// Token represents a lexical token
type Token struct {
	Type     TokenType
	Value    string
	Line     int
	Column   int
	Filename string
}

// NewToken creates a new token with the given properties
func NewToken(tokenType TokenType, value string, line, column int, filename string) *Token {
	return &Token{
		Type:     tokenType,
		Value:    value,
		Line:     line,
		Column:   column,
		Filename: filename,
	}
}

