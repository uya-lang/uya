package parser

import (
	"fmt"

	"github.com/uya/compiler-go/src/lexer"
)

// Parser represents a syntax analyzer for Uya source code
type Parser struct {
	lexer        *lexer.Lexer
	currentToken *lexer.Token
}

// NewParser creates a new parser for the given lexer
func NewParser(l *lexer.Lexer) *Parser {
	if l == nil {
		return nil
	}

	token, err := l.NextToken()
	if err != nil {
		// If there's an error getting the first token, return nil
		// or create a parser with EOF token
		// For now, we'll create an EOF token manually
		return &Parser{
			lexer:        l,
			currentToken: &lexer.Token{Type: lexer.TOKEN_EOF, Filename: ""},
		}
	}

	return &Parser{
		lexer:        l,
		currentToken: token,
	}
}

// peek returns the current token without advancing
func (p *Parser) peek() *lexer.Token {
	return p.currentToken
}

// consume consumes the current token and advances to the next one
func (p *Parser) consume() *lexer.Token {
	if p.currentToken == nil {
		return nil
	}

	current := p.currentToken
	token, err := p.lexer.NextToken()
	if err != nil {
		// On error, set to EOF token
		p.currentToken = &lexer.Token{Type: lexer.TOKEN_EOF, Filename: current.Filename}
	} else {
		p.currentToken = token
	}

	return current
}

// match checks if the current token matches the given type
func (p *Parser) match(tokenType lexer.TokenType) bool {
	return p.currentToken != nil && p.currentToken.Type == tokenType
}

// expect expects the current token to be of the given type, consumes it and returns it
// Returns an error if the token type doesn't match
func (p *Parser) expect(tokenType lexer.TokenType) (*lexer.Token, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF")
	}

	if p.currentToken.Type != tokenType {
		return nil, fmt.Errorf(
			"syntax error: expected %v, but found %v at %s:%d:%d",
			tokenType, p.currentToken.Type,
			p.currentToken.Filename, p.currentToken.Line, p.currentToken.Column,
		)
	}

	return p.consume(), nil
}

// Parse parses the source code and returns the AST
func (p *Parser) Parse() (*Program, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("parser has no current token")
	}

	// Create program node with position from first token
	program := &Program{
		NodeBase: NodeBase{
			Line:     p.currentToken.Line,
			Column:   p.currentToken.Column,
			Filename: p.currentToken.Filename,
		},
		Decls: []Node{},
	}

	// Parse all top-level declarations
	for p.currentToken != nil && !p.match(lexer.TOKEN_EOF) {
		// TODO: Implement parseDeclaration
		// For now, just skip tokens until EOF or declaration keywords
		decl, err := p.parseDeclaration()
		if err != nil {
			// If parsing fails, skip to next possible declaration start
			for p.currentToken != nil &&
				!p.match(lexer.TOKEN_EOF) &&
				!p.match(lexer.TOKEN_FN) &&
				!p.match(lexer.TOKEN_STRUCT) &&
				!p.match(lexer.TOKEN_ENUM) &&
				!p.match(lexer.TOKEN_EXTERN) &&
				!p.match(lexer.TOKEN_IDENTIFIER) {
				p.consume()
			}
			continue
		}

		if decl != nil {
			program.Decls = append(program.Decls, decl)
		}
	}

	return program, nil
}

// parseDeclaration parses a top-level declaration
// This is a placeholder that will be implemented in parser_decl.go
func (p *Parser) parseDeclaration() (Node, error) {
	// TODO: Implement in parser_decl.go
	return nil, fmt.Errorf("parseDeclaration not yet implemented")
}

