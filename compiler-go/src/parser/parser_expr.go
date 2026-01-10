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

	// Check for unary operators first (&, -, !, try)
	if p.match(lexer.TOKEN_AMPERSAND) || p.match(lexer.TOKEN_MINUS) ||
		p.match(lexer.TOKEN_EXCLAMATION) || p.match(lexer.TOKEN_TRY) {
		return p.parseUnaryExpr()
	}

	// Parse primary expression (identifiers, literals, parentheses)
	expr, err := p.parsePrimary()
	if err != nil {
		return nil, err
	}

	// Handle postfix operators (member access, subscript, function call)
	return p.parsePostfix(expr)
}

// parseUnaryExpr parses a unary expression: &expr, -expr, !expr, try expr
func (p *Parser) parseUnaryExpr() (Expr, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename

	var op lexer.TokenType
	if p.match(lexer.TOKEN_AMPERSAND) {
		op = lexer.TOKEN_AMPERSAND
		p.consume() // consume '&'
	} else if p.match(lexer.TOKEN_MINUS) {
		op = lexer.TOKEN_MINUS
		p.consume() // consume '-'
	} else if p.match(lexer.TOKEN_EXCLAMATION) {
		op = lexer.TOKEN_EXCLAMATION
		p.consume() // consume '!'
	} else if p.match(lexer.TOKEN_TRY) {
		op = lexer.TOKEN_TRY
		p.consume() // consume 'try'
	} else {
		return nil, fmt.Errorf("expected unary operator")
	}

	// Parse operand
	operand, err := p.parseExpression()
	if err != nil {
		return nil, fmt.Errorf("failed to parse unary operand: %w", err)
	}

	return &UnaryExpr{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Op:      int(op),
		Operand: operand,
	}, nil
}

// parsePostfix handles postfix operators: member access (.), subscript ([]), function call (())
// This is called after parsing a primary expression
func (p *Parser) parsePostfix(expr Expr) (Expr, error) {
	// Loop to handle chained postfix operators (e.g., obj.field[0].method())
	for p.currentToken != nil {
		// Check for function call: expr(args)
		if p.match(lexer.TOKEN_LEFT_PAREN) {
			call, err := p.parseCallExprFromCallee(expr)
			if err != nil {
				return nil, err
			}
			expr = call
			continue
		}

		// Check for member access: obj.field
		if p.match(lexer.TOKEN_DOT) {
			p.consume() // consume '.'

			// Expect field name (identifier or number for tuple fields)
			if !p.match(lexer.TOKEN_IDENTIFIER) && !p.match(lexer.TOKEN_NUMBER) {
				return nil, fmt.Errorf("expected field name or index after '.' at %s:%d:%d",
					p.currentToken.Filename, p.currentToken.Line, p.currentToken.Column)
			}

			fieldName := p.currentToken.Value
			fieldLine := p.currentToken.Line
			fieldCol := p.currentToken.Column
			p.consume() // consume field name

			// Create member access expression
			expr = &MemberAccess{
				NodeBase: NodeBase{
					Line:     fieldLine,
					Column:   fieldCol,
					Filename: expr.Base().Filename,
				},
				Object:    expr,
				FieldName: fieldName,
			}
			continue
		}

		// Check for subscript: arr[index]
		if p.match(lexer.TOKEN_LEFT_BRACKET) {
			subLine := p.currentToken.Line
			subCol := p.currentToken.Column
			p.consume() // consume '['

			// Parse index expression
			index, err := p.parseExpression()
			if err != nil {
				return nil, fmt.Errorf("failed to parse subscript index: %w", err)
			}

			// Check for slice syntax: arr[start:len]
			if p.match(lexer.TOKEN_COLON) {
				// TODO: Implement slice syntax (convert to slice function call)
				// For now, return error
				return nil, fmt.Errorf("slice syntax not yet implemented at %s:%d:%d",
					p.currentToken.Filename, p.currentToken.Line, p.currentToken.Column)
			}

			// Expect ']'
			if _, err := p.expect(lexer.TOKEN_RIGHT_BRACKET); err != nil {
				return nil, fmt.Errorf("expected ']' after subscript index: %w", err)
			}

			// Create subscript expression
			expr = &SubscriptExpr{
				NodeBase: NodeBase{
					Line:     subLine,
					Column:   subCol,
					Filename: expr.Base().Filename,
				},
				Array: expr,
				Index: index,
			}
			continue
		}

		// No more postfix operators
		break
	}

	return expr, nil
}

// parseCallExprFromCallee parses a function call where the callee is any expression
func (p *Parser) parseCallExprFromCallee(callee Expr) (*CallExpr, error) {
	if !p.match(lexer.TOKEN_LEFT_PAREN) {
		return nil, fmt.Errorf("expected '(' for function call")
	}

	callLine := p.currentToken.Line
	callCol := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume '('

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

	// Handle identifiers
	if p.match(lexer.TOKEN_IDENTIFIER) || p.match(lexer.TOKEN_ERROR) {
		name := p.currentToken.Value
		if p.match(lexer.TOKEN_ERROR) {
			name = "error"
		}
		p.consume() // consume identifier

		// Return identifier as primary expression
		// Function calls will be handled as postfix operators
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

