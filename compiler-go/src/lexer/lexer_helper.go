package lexer

// NewLexerFromString creates a new lexer from a string content (for internal use, e.g., string interpolation)
func NewLexerFromString(content string, filename string, line int, column int) *Lexer {
	return &Lexer{
		buffer:   content,
		filename: filename,
		line:     line,
		column:   column,
		position: 0,
	}
}

