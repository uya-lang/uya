package lexer

// readString reads a string literal, including handling escape sequences
// and detecting string interpolation start (${)
func (l *Lexer) readString() (*Token, error) {
	start := l.position
	line := l.line
	column := l.column

	// Skip opening quote
	l.advance()

	for l.position < len(l.buffer) {
		c := l.advance()

		if c == '"' {
			// Found closing quote
			value := l.buffer[start:l.position]
			return NewToken(TOKEN_STRING, value, line, column, l.filename), nil
		} else if c == '\\' {
			// Escape sequence - skip the escaped character
			if l.position < len(l.buffer) {
				l.advance()
			}
		} else if c == '$' && l.position < len(l.buffer) && l.peek(0) == '{' {
			// String interpolation start: ${
			// For now, we'll include it in the string token value
			// The parser will handle the interpolation parsing
			l.advance() // Skip '{'
		} else if c == '\n' {
			// Unterminated string (newline before closing quote)
			return nil, &LexerError{
				Message:  "unterminated string literal",
				Line:     line,
				Column:   column,
				Filename: l.filename,
			}
		}
	}

	// EOF reached without closing quote
	return nil, &LexerError{
		Message:  "unterminated string literal",
		Line:     line,
		Column:   column,
		Filename: l.filename,
	}
}

// readChar reads a character literal (single quoted character)
func (l *Lexer) readChar() (*Token, error) {
	start := l.position
	line := l.line
	column := l.column

	// Skip opening quote
	l.advance()

	if l.position >= len(l.buffer) {
		return nil, &LexerError{
			Message:  "unterminated character literal",
			Line:     line,
			Column:   column,
			Filename: l.filename,
		}
	}

	c := l.advance()

	// Handle escape sequences
	if c == '\\' && l.position < len(l.buffer) {
		c = l.advance()
		// Common escape sequences: \n, \t, \r, \\, \', \"
		// The actual value interpretation will be done during compilation
	}

	// Look for closing quote
	if l.position >= len(l.buffer) || l.peek(0) != '\'' {
		return nil, &LexerError{
			Message:  "unterminated character literal",
			Line:     line,
			Column:   column,
			Filename: l.filename,
		}
	}

	l.advance() // Skip closing quote

	value := l.buffer[start:l.position]
	return NewToken(TOKEN_CHAR, value, line, column, l.filename), nil
}

