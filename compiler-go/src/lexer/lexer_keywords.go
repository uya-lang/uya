package lexer

// keywordMap maps keyword strings to their TokenType values
var keywordMap = map[string]TokenType{
	"struct":    TOKEN_STRUCT,
	"mut":       TOKEN_MUT,
	"const":     TOKEN_CONST,
	"var":       TOKEN_VAR,
	"fn":        TOKEN_FN,
	"return":    TOKEN_RETURN,
	"extern":    TOKEN_EXTERN,
	"true":      TOKEN_TRUE,
	"false":     TOKEN_FALSE,
	"if":        TOKEN_IF,
	"else":      TOKEN_ELSE,
	"for":       TOKEN_FOR,
	"while":     TOKEN_WHILE,
	"break":     TOKEN_BREAK,
	"continue":  TOKEN_CONTINUE,
	"defer":     TOKEN_DEFER,
	"errdefer":  TOKEN_ERRDEFER,
	"try":       TOKEN_TRY,
	"catch":     TOKEN_CATCH,
	"error":     TOKEN_ERROR,
	"null":      TOKEN_NULL,
	"interface": TOKEN_INTERFACE,
	"enum":      TOKEN_ENUM,
	"atomic":    TOKEN_ATOMIC,
	"max":       TOKEN_MAX,
	"min":       TOKEN_MIN,
	"as":        TOKEN_AS,
	"as!":       TOKEN_AS_EXCLAMATION,
	"type":      TOKEN_TYPE,
	"mc":        TOKEN_MC,
	"match":     TOKEN_MATCH,
	// Note: "impl" is no longer a keyword (version 0.24 change:
	// interface implementation syntax simplified to StructName : InterfaceName { ... })
}

// isKeyword checks if the given string is a keyword and returns its TokenType.
// Returns 0 if the string is not a keyword.
func isKeyword(str string) TokenType {
	if tokenType, ok := keywordMap[str]; ok {
		return tokenType
	}
	return 0
}

