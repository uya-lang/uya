package parser

import (
	"fmt"

	"github.com/uya/compiler-go/src/lexer"
)

// parseBlock parses a code block: { statements... }
// This is a simplified version that supports empty blocks
// Full statement parsing will be implemented in a later phase
func (p *Parser) parseBlock() (*Block, error) {
	if !p.match(lexer.TOKEN_LEFT_BRACE) {
		return nil, fmt.Errorf("expected '{' to start block")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume '{'

	block := &Block{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Stmts: []Stmt{},
	}

	// Parse statements until we encounter '}'
	// TODO: Implement full statement parsing (parseStatement)
	// For now, support empty blocks only (full statement parsing will be implemented later)
	// If the block is not empty, this will fail - but that's expected until statement parsing is implemented

	if !p.match(lexer.TOKEN_RIGHT_BRACE) {
		return nil, fmt.Errorf("expected '}' to close block at %s:%d:%d", filename, line, col)
	}

	p.consume() // consume '}'

	return block, nil
}

