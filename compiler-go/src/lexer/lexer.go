package lexer

import (
	"os"
	"unicode"
)

// Lexer represents a lexical analyzer for Uya source code
type Lexer struct {
	buffer   string
	position int
	line     int
	column   int
	filename string
}

// NewLexer creates a new lexer for the given file
func NewLexer(filename string) (*Lexer, error) {
	data, err := os.ReadFile(filename)
	if err != nil {
		return nil, err
	}

	return &Lexer{
		buffer:   string(data),
		filename: filename,
		line:     1,
		column:   1,
	}, nil
}

// peek returns the character at the current position + offset without advancing
func (l *Lexer) peek(offset int) byte {
	pos := l.position + offset
	if pos >= len(l.buffer) {
		return 0
	}
	return l.buffer[pos]
}

// advance moves to the next character and returns it
func (l *Lexer) advance() byte {
	if l.position >= len(l.buffer) {
		return 0
	}

	c := l.buffer[l.position]
	l.position++

	if c == '\n' {
		l.line++
		l.column = 1
	} else {
		l.column++
	}

	return c
}

// skipWhitespace skips whitespace, tabs, newlines, and comments
func (l *Lexer) skipWhitespace() {
	for l.position < len(l.buffer) {
		c := l.peek(0)
		if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
			l.advance()
		} else if c == '/' && l.peek(1) == '/' {
			// Single-line comment
			for l.position < len(l.buffer) && l.peek(0) != '\n' {
				l.advance()
			}
		} else if c == '/' && l.peek(1) == '*' {
			// Multi-line comment
			l.advance() // '/'
			l.advance() // '*'
			for l.position < len(l.buffer) {
				if l.peek(0) == '*' && l.peek(1) == '/' {
					l.advance() // '*'
					l.advance() // '/'
					break
				}
				l.advance()
			}
		} else {
			break
		}
	}
}

// readIdentifierOrKeyword reads an identifier or keyword
func (l *Lexer) readIdentifierOrKeyword() (*Token, error) {
	start := l.position
	line := l.line
	column := l.column

	// Read identifier characters
	for l.position < len(l.buffer) {
		c := l.peek(0)
		if unicode.IsLetter(rune(c)) || unicode.IsDigit(rune(c)) || c == '_' {
			l.advance()
		} else {
			break
		}
	}

	value := l.buffer[start:l.position]

	// Check if it's a keyword
	if keywordType := isKeyword(value); keywordType != 0 {
		return NewToken(keywordType, value, line, column, l.filename), nil
	}

	return NewToken(TOKEN_IDENTIFIER, value, line, column, l.filename), nil
}

// NextToken returns the next token from the input
func (l *Lexer) NextToken() (*Token, error) {
	l.skipWhitespace()

	if l.position >= len(l.buffer) {
		return NewToken(TOKEN_EOF, "", l.line, l.column, l.filename), nil
	}

	c := l.peek(0)
	line := l.line
	column := l.column

	switch c {
	case '+':
		l.advance()
		if l.peek(0) == '|' {
			l.advance()
			return NewToken(TOKEN_PLUS_PIPE, "+|", line, column, l.filename), nil
		} else if l.peek(0) == '%' {
			l.advance()
			return NewToken(TOKEN_PLUS_PERCENT, "+%", line, column, l.filename), nil
		}
		return NewToken(TOKEN_PLUS, "+", line, column, l.filename), nil

	case '-':
		l.advance()
		if l.peek(0) == '|' {
			l.advance()
			return NewToken(TOKEN_MINUS_PIPE, "-|", line, column, l.filename), nil
		} else if l.peek(0) == '%' {
			l.advance()
			return NewToken(TOKEN_MINUS_PERCENT, "-%", line, column, l.filename), nil
		}
		return NewToken(TOKEN_MINUS, "-", line, column, l.filename), nil

	case '*':
		l.advance()
		if l.peek(0) == '|' {
			l.advance()
			return NewToken(TOKEN_ASTERISK_PIPE, "*|", line, column, l.filename), nil
		} else if l.peek(0) == '%' {
			l.advance()
			return NewToken(TOKEN_ASTERISK_PERCENT, "*%", line, column, l.filename), nil
		}
		return NewToken(TOKEN_ASTERISK, "*", line, column, l.filename), nil

	case '/':
		l.advance()
		return NewToken(TOKEN_SLASH, "/", line, column, l.filename), nil

	case '%':
		l.advance()
		return NewToken(TOKEN_PERCENT, "%", line, column, l.filename), nil

	case '=':
		l.advance()
		if l.peek(0) == '=' {
			l.advance()
			return NewToken(TOKEN_EQUAL, "==", line, column, l.filename), nil
		} else if l.peek(0) == '>' {
			l.advance()
			return NewToken(TOKEN_ARROW, "=>", line, column, l.filename), nil
		}
		return NewToken(TOKEN_ASSIGN, "=", line, column, l.filename), nil

	case '!':
		l.advance()
		if l.peek(0) == '=' {
			l.advance()
			return NewToken(TOKEN_NOT_EQUAL, "!=", line, column, l.filename), nil
		}
		return NewToken(TOKEN_EXCLAMATION, "!", line, column, l.filename), nil

	case '<':
		l.advance()
		if l.peek(0) == '=' {
			l.advance()
			return NewToken(TOKEN_LESS_EQUAL, "<=", line, column, l.filename), nil
		} else if l.peek(0) == '<' {
			l.advance()
			return NewToken(TOKEN_LEFT_SHIFT, "<<", line, column, l.filename), nil
		}
		return NewToken(TOKEN_LESS, "<", line, column, l.filename), nil

	case '>':
		l.advance()
		if l.peek(0) == '=' {
			l.advance()
			return NewToken(TOKEN_GREATER_EQUAL, ">=", line, column, l.filename), nil
		} else if l.peek(0) == '>' {
			l.advance()
			return NewToken(TOKEN_RIGHT_SHIFT, ">>", line, column, l.filename), nil
		}
		return NewToken(TOKEN_GREATER, ">", line, column, l.filename), nil

	case '&':
		l.advance()
		if l.peek(0) == '&' {
			l.advance()
			return NewToken(TOKEN_LOGICAL_AND, "&&", line, column, l.filename), nil
		}
		return NewToken(TOKEN_AMPERSAND, "&", line, column, l.filename), nil

	case '|':
		l.advance()
		if l.peek(0) == '|' {
			l.advance()
			return NewToken(TOKEN_LOGICAL_OR, "||", line, column, l.filename), nil
		}
		return NewToken(TOKEN_PIPE, "|", line, column, l.filename), nil

	case '^':
		l.advance()
		return NewToken(TOKEN_CARET, "^", line, column, l.filename), nil

	case '~':
		l.advance()
		return NewToken(TOKEN_TILDE, "~", line, column, l.filename), nil

	case '(':
		l.advance()
		return NewToken(TOKEN_LEFT_PAREN, "(", line, column, l.filename), nil

	case ')':
		l.advance()
		return NewToken(TOKEN_RIGHT_PAREN, ")", line, column, l.filename), nil

	case '{':
		l.advance()
		return NewToken(TOKEN_LEFT_BRACE, "{", line, column, l.filename), nil

	case '}':
		l.advance()
		return NewToken(TOKEN_RIGHT_BRACE, "}", line, column, l.filename), nil

	case '[':
		l.advance()
		return NewToken(TOKEN_LEFT_BRACKET, "[", line, column, l.filename), nil

	case ']':
		l.advance()
		return NewToken(TOKEN_RIGHT_BRACKET, "]", line, column, l.filename), nil

	case ';':
		l.advance()
		return NewToken(TOKEN_SEMICOLON, ";", line, column, l.filename), nil

	case ',':
		l.advance()
		return NewToken(TOKEN_COMMA, ",", line, column, l.filename), nil

	case '.':
		l.advance()
		if l.peek(0) == '.' {
			l.advance()
			if l.peek(0) == '.' {
				l.advance()
				return NewToken(TOKEN_ELLIPSIS, "...", line, column, l.filename), nil
			}
			return NewToken(TOKEN_RANGE, "..", line, column, l.filename), nil
		}
		return NewToken(TOKEN_DOT, ".", line, column, l.filename), nil

	case ':':
		l.advance()
		return NewToken(TOKEN_COLON, ":", line, column, l.filename), nil

	case '"':
		return l.readString()

	case '\'':
		return l.readChar()

	default:
		if unicode.IsLetter(rune(c)) || c == '_' {
			return l.readIdentifierOrKeyword()
		} else if unicode.IsDigit(rune(c)) {
			return l.readNumber()
		} else {
			// Unknown character - advance and return error token
			l.advance()
			return nil, &LexerError{
				Message:  "unexpected character: " + string(c),
				Line:     line,
				Column:   column,
				Filename: l.filename,
			}
		}
	}
}

