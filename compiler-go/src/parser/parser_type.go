package parser

import (
	"fmt"

	"github.com/uya/compiler-go/src/lexer"
)

// parseType parses a type expression
// This is a simplified version that supports named types, pointers, error unions, and arrays
// More complex types (function types, tuples, etc.) will be added later
func (p *Parser) parseType() (Type, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF while parsing type")
	}

	// Check if it's an error union type: !T
	if p.match(lexer.TOKEN_EXCLAMATION) {
		line := p.currentToken.Line
		col := p.currentToken.Column
		filename := p.currentToken.Filename
		p.consume() // consume '!'

		baseType, err := p.parseType()
		if err != nil {
			return nil, err
		}

		return &ErrorUnionType{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			BaseType: baseType,
		}, nil
	}

	// Check if it's an atomic type: atomic T
	if p.match(lexer.TOKEN_ATOMIC) {
		line := p.currentToken.Line
		col := p.currentToken.Column
		filename := p.currentToken.Filename
		p.consume() // consume 'atomic'

		baseType, err := p.parseType()
		if err != nil {
			return nil, err
		}

		return &AtomicType{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			BaseType: baseType,
		}, nil
	}

	// Check if it's a pointer type: *T
	if p.match(lexer.TOKEN_ASTERISK) {
		line := p.currentToken.Line
		col := p.currentToken.Column
		filename := p.currentToken.Filename
		p.consume() // consume '*'

		pointeeType, err := p.parseType()
		if err != nil {
			return nil, err
		}

		return &PointerType{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			PointeeType: pointeeType,
		}, nil
	}

	// Check if it's an array type: [element_type : size] or [element_type]
	if p.match(lexer.TOKEN_LEFT_BRACKET) {
		line := p.currentToken.Line
		col := p.currentToken.Column
		filename := p.currentToken.Filename
		p.consume() // consume '['

		elementType, err := p.parseType()
		if err != nil {
			return nil, fmt.Errorf("failed to parse array element type: %w", err)
		}

		size := -1 // -1 means unsized array
		if p.match(lexer.TOKEN_COLON) {
			p.consume() // consume ':'
			// TODO: Parse size expression (for now, just support numeric literals)
			// This is a simplification - full implementation would parse expressions
			return nil, fmt.Errorf("array size parsing not yet implemented")
		}

		if _, err := p.expect(lexer.TOKEN_RIGHT_BRACKET); err != nil {
			return nil, fmt.Errorf("expected ']' after array type: %w", err)
		}

		return &ArrayType{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			ElementType: elementType,
			Size:        size,
		}, nil
	}

	// Handle simple named type (identifier)
	if !p.match(lexer.TOKEN_IDENTIFIER) {
		return nil, fmt.Errorf("expected type identifier, got %v", p.currentToken.Type)
	}

	typeName := p.currentToken.Value
	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume identifier

	return &NamedType{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name: typeName,
	}, nil
}

