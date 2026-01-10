package parser

import (
	"fmt"

	"github.com/uya/compiler-go/src/lexer"
)

// parseDeclaration parses a top-level declaration
func (p *Parser) parseDeclaration() (Node, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF")
	}

	// TODO: Parse test blocks
	// TODO: Parse interface implementations

	if p.match(lexer.TOKEN_FN) {
		return p.parseFuncDecl()
	}
	// TODO: Add other declaration types (struct, enum, error, extern, etc.)
	// For now, return error for unsupported declarations
	return nil, fmt.Errorf("unsupported declaration type at %s:%d:%d",
		p.currentToken.Filename, p.currentToken.Line, p.currentToken.Column)
}

// parseParam parses a function parameter: name : type
func (p *Parser) parseParam() (*Param, error) {
	if p.currentToken == nil || !p.match(lexer.TOKEN_IDENTIFIER) {
		return nil, fmt.Errorf("expected parameter name")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	name := p.currentToken.Value
	p.consume() // consume parameter name

	param := &Param{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name: name,
		Type: nil, // Will be set if type annotation is present
	}

	// Parse optional type annotation ':'
	if p.match(lexer.TOKEN_COLON) {
		p.consume() // consume ':'
		paramType, err := p.parseType()
		if err != nil {
			return nil, fmt.Errorf("failed to parse parameter type: %w", err)
		}
		param.Type = paramType
	}

	return param, nil
}

// parseFuncDecl parses a function declaration: fn name(params) -> return_type { body }
func (p *Parser) parseFuncDecl() (*FuncDecl, error) {
	if !p.match(lexer.TOKEN_FN) {
		return nil, fmt.Errorf("expected 'fn' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'fn'

	// Expect function name
	if !p.match(lexer.TOKEN_IDENTIFIER) {
		return nil, fmt.Errorf("expected function name at %s:%d:%d", filename, line, col)
	}

	name := p.currentToken.Value
	p.consume() // consume function name

	// Expect '('
	if _, err := p.expect(lexer.TOKEN_LEFT_PAREN); err != nil {
		return nil, fmt.Errorf("expected '(' after function name: %w", err)
	}

	// Parse parameter list
	params := []*Param{}
	if !p.match(lexer.TOKEN_RIGHT_PAREN) {
		for {
			param, err := p.parseParam()
			if err != nil {
				return nil, fmt.Errorf("failed to parse parameter: %w", err)
			}
			params = append(params, param)

			if p.match(lexer.TOKEN_COMMA) {
				p.consume() // consume ','
			} else {
				break
			}
		}
	}

	// Expect ')'
	if _, err := p.expect(lexer.TOKEN_RIGHT_PAREN); err != nil {
		return nil, fmt.Errorf("expected ')' after parameter list: %w", err)
	}

	// Parse optional return type
	var returnType Type
	if p.match(lexer.TOKEN_ARROW) {
		p.consume() // consume '->'
		rt, err := p.parseType()
		if err != nil {
			return nil, fmt.Errorf("failed to parse return type: %w", err)
		}
		returnType = rt
	} else if p.currentToken != nil &&
		(p.match(lexer.TOKEN_IDENTIFIER) ||
			p.match(lexer.TOKEN_EXCLAMATION) ||
			p.match(lexer.TOKEN_ATOMIC) ||
			p.match(lexer.TOKEN_ASTERISK)) {
		// Try to parse as a type (supports !i32, *T, atomic T, or simple types)
		rt, err := p.parseType()
		if err == nil {
			returnType = rt
		}
	}

	// Default to void if no return type specified
	if returnType == nil {
		returnType = &NamedType{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Name: "void",
		}
	}

	// Parse function body (code block)
	body, err := p.parseBlock()
	if err != nil {
		return nil, fmt.Errorf("failed to parse function body: %w", err)
	}

	return &FuncDecl{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name:       name,
		Params:     params,
		ReturnType: returnType,
		Body:       body,
		IsExtern:   false,
	}, nil
}

