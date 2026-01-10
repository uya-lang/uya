package lexer

import (
	"unicode"
)

// readNumber reads a number literal (integer or floating point)
// Returns the token and any error encountered
func (l *Lexer) readNumber() (*Token, error) {
	start := l.position
	line := l.line
	column := l.column

	// Check for negative sign (part of the number)
	if l.position < len(l.buffer) && l.buffer[l.position] == '-' {
		l.advance()
	}

	// Check for hex prefix
	hasHexPrefix := false
	if l.position < len(l.buffer)-1 && l.buffer[l.position] == '0' {
		next := l.buffer[l.position+1]
		if next == 'x' || next == 'X' {
			hasHexPrefix = true
			l.advance() // '0'
			l.advance() // 'x' or 'X'
		}
	}

	// Read digits
	hasDigit := false
	for l.position < len(l.buffer) {
		c := l.peek(0)
		if hasHexPrefix {
			// Hex digits
			if (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F') {
				l.advance()
				hasDigit = true
			} else {
				break
			}
		} else {
			// Decimal digits
			if unicode.IsDigit(rune(c)) {
				l.advance()
				hasDigit = true
			} else if c == '.' && l.position+1 < len(l.buffer) && unicode.IsDigit(rune(l.buffer[l.position+1])) {
				// Floating point
				l.advance() // '.'
				hasDigit = true
				// Read fractional part
				for l.position < len(l.buffer) && unicode.IsDigit(rune(l.peek(0))) {
					l.advance()
				}
				break
			} else {
				break
			}
		}
	}

	if !hasDigit {
		// Not a valid number, this shouldn't happen in normal operation
		return nil, &LexerError{
			Message:  "invalid number",
			Line:     line,
			Column:   column,
			Filename: l.filename,
		}
	}

	value := l.buffer[start:l.position]
	return NewToken(TOKEN_NUMBER, value, line, column, l.filename), nil
}

