package parser

import (
	"fmt"

	"github.com/uya/compiler-go/src/lexer"
)

// parseExpression parses an expression
// This is a basic implementation that will be expanded incrementally
func (p *Parser) parseExpression() (Expr, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF")
	}

	// Parse primary expression (identifiers, literals, parentheses)
	return p.parsePrimary()
}

// parsePrimary parses a primary expression:
// - Identifier
// - Number literal
// - String literal
// - Boolean literal (true/false)
// - Null literal
// - Parenthesized expression
// - Function call (identifier followed by '(')
func (p *Parser) parsePrimary() (Expr, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename

	// Handle identifiers (including function calls)
	if p.match(lexer.TOKEN_IDENTIFIER) || p.match(lexer.TOKEN_ERROR) {
		name := p.currentToken.Value
		if p.match(lexer.TOKEN_ERROR) {
			name = "error"
		}
		p.consume() // consume identifier

		// Check if this is a function call: identifier(args)
		if p.match(lexer.TOKEN_LEFT_PAREN) {
			return p.parseCallExpr(name, line, col, filename)
		}

		// Simple identifier
		return &Identifier{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Name: name,
		}, nil
	}

	// Handle number literals
	if p.match(lexer.TOKEN_NUMBER) {
		value := p.currentToken.Value
		p.consume() // consume number
		return &NumberLiteral{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Value: value,
		}, nil
	}

	// Handle string literals
	if p.match(lexer.TOKEN_STRING) {
		value := p.currentToken.Value
		p.consume() // consume string
		return &StringLiteral{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Value: value,
		}, nil
	}

	// Handle boolean literals
	if p.match(lexer.TOKEN_TRUE) {
		p.consume() // consume true
		return &BoolLiteral{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Value: true,
		}, nil
	}

	if p.match(lexer.TOKEN_FALSE) {
		p.consume() // consume false
		return &BoolLiteral{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Value: false,
		}, nil
	}

	// Handle null literal
	if p.match(lexer.TOKEN_NULL) {
		p.consume() // consume null
		return &NullLiteral{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
		}, nil
	}

	// Handle parenthesized expressions: (expr)
	if p.match(lexer.TOKEN_LEFT_PAREN) {
		p.consume() // consume '('
		expr, err := p.parseExpression()
		if err != nil {
			return nil, fmt.Errorf("failed to parse expression in parentheses: %w", err)
		}

		// Expect ')'
		if _, err := p.expect(lexer.TOKEN_RIGHT_PAREN); err != nil {
			return nil, fmt.Errorf("expected ')' after expression: %w", err)
		}

		return expr, nil
	}

	return nil, fmt.Errorf("unexpected token in expression at %s:%d:%d: %v",
		filename, line, col, p.currentToken.Type)
}

// parseCallExpr parses a function call expression: identifier(args...)
func (p *Parser) parseCallExpr(calleeName string, line, col int, filename string) (*CallExpr, error) {
	// Current token should be '('
	if !p.match(lexer.TOKEN_LEFT_PAREN) {
		return nil, fmt.Errorf("expected '(' for function call")
	}

	callLine := p.currentToken.Line
	callCol := p.currentToken.Column
	p.consume() // consume '('

	// Create callee identifier
	callee := &Identifier{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name: calleeName,
	}

	// Parse arguments
	args := []Expr{}
	if !p.match(lexer.TOKEN_RIGHT_PAREN) {
		for {
			arg, err := p.parseExpression()
			if err != nil {
				return nil, fmt.Errorf("failed to parse function argument: %w", err)
			}
			args = append(args, arg)

			if p.match(lexer.TOKEN_COMMA) {
				p.consume() // consume ','
			} else {
				break
			}
		}
	}

	// Expect ')'
	if _, err := p.expect(lexer.TOKEN_RIGHT_PAREN); err != nil {
		return nil, fmt.Errorf("expected ')' after function arguments: %w", err)
	}

	return &CallExpr{
		NodeBase: NodeBase{
			Line:     callLine,
			Column:   callCol,
			Filename: filename,
		},
		Callee: callee,
		Args:   args,
	}, nil
}

