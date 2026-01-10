package parser

import (
	"fmt"
	"strings"

	"github.com/uya/compiler-go/src/lexer"
)

// parseExpression parses an expression
// This is a basic implementation that will be expanded incrementally
func (p *Parser) parseExpression() (Expr, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF")
	}

	// Check for match expressions first: match expr { pattern => body, ... }
	if p.match(lexer.TOKEN_MATCH) {
		return p.parseMatchExpr()
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
	expr, err = p.parsePostfix(expr)
	if err != nil {
		return nil, err
	}

	// Handle binary operators (logical operators have lowest precedence)
	expr, err = p.parseBinaryExpr(expr)
	if err != nil {
		return nil, err
	}

	// Handle catch expression: expr catch |err| { ... } or expr catch { ... }
	if p.currentToken != nil && p.match(lexer.TOKEN_CATCH) {
		return p.parseCatchExpr(expr)
	}

	return expr, nil
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

// parseBinaryExpr handles binary operators (logical operators have lowest precedence)
// This function processes logical operators (&&, ||) and delegates other operators to parseComparisonOrHigher
func (p *Parser) parseBinaryExpr(left Expr) (Expr, error) {
	// Handle logical operators (&&, ||) - lowest precedence
	for p.currentToken != nil {
		if !p.match(lexer.TOKEN_LOGICAL_AND) && !p.match(lexer.TOKEN_LOGICAL_OR) {
			break
		}

		op := p.currentToken.Type
		line := p.currentToken.Line
		col := p.currentToken.Column
		filename := p.currentToken.Filename
		p.consume() // consume operator

		// Parse right operand (comparison or higher precedence)
		right, err := p.parseComparisonOrHigher()
		if err != nil {
			return nil, fmt.Errorf("failed to parse right operand of logical operator: %w", err)
		}

		// Create binary expression
		left = &BinaryExpr{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Left:  left,
			Op:    int(op),
			Right: right,
		}
	}

	return left, nil
}

// parseComparisonOrHigher parses expressions with comparison operators or higher precedence
// This includes arithmetic, comparison, and bitwise operators, but NOT logical operators
func (p *Parser) parseComparisonOrHigher() (Expr, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF")
	}

	// Check for unary operators first (&, -, !, try)
	if p.match(lexer.TOKEN_AMPERSAND) || p.match(lexer.TOKEN_MINUS) ||
		p.match(lexer.TOKEN_EXCLAMATION) || p.match(lexer.TOKEN_TRY) {
		return p.parseUnaryExpr()
	}

	// Parse primary expression
	expr, err := p.parsePrimary()
	if err != nil {
		return nil, err
	}

	// Handle postfix operators
	expr, err = p.parsePostfix(expr)
	if err != nil {
		return nil, err
	}

	// Handle binary operators (arithmetic, comparison, bitwise)
	return p.parseComparisonBinaryExpr(expr)
}

// parseComparisonBinaryExpr handles binary operators except logical operators
func (p *Parser) parseComparisonBinaryExpr(left Expr) (Expr, error) {
	// Loop to handle chained operators (left-associative)
	for p.currentToken != nil {
		opType := p.currentToken.Type

		// Check if it's a binary operator (excluding logical operators)
		if !p.isComparisonOrArithmeticOperator(opType) {
			break
		}

		op := opType
		line := p.currentToken.Line
		col := p.currentToken.Column
		filename := p.currentToken.Filename
		p.consume() // consume operator

		// Parse right operand (recursively call parseComparisonOrHigher)
		right, err := p.parseComparisonOrHigher()
		if err != nil {
			return nil, fmt.Errorf("failed to parse right operand: %w", err)
		}

		// Create binary expression
		left = &BinaryExpr{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Left:  left,
			Op:    int(op),
			Right: right,
		}
	}

	return left, nil
}

// isComparisonOrArithmeticOperator checks if the token is a comparison or arithmetic operator
func (p *Parser) isComparisonOrArithmeticOperator(tokenType lexer.TokenType) bool {
	switch tokenType {
	case lexer.TOKEN_PLUS, lexer.TOKEN_MINUS, lexer.TOKEN_ASTERISK, lexer.TOKEN_SLASH,
		lexer.TOKEN_PERCENT,
		lexer.TOKEN_EQUAL, lexer.TOKEN_NOT_EQUAL,
		lexer.TOKEN_LESS, lexer.TOKEN_LESS_EQUAL,
		lexer.TOKEN_GREATER, lexer.TOKEN_GREATER_EQUAL,
		lexer.TOKEN_PLUS_PIPE, lexer.TOKEN_MINUS_PIPE, lexer.TOKEN_ASTERISK_PIPE,
		lexer.TOKEN_PLUS_PERCENT, lexer.TOKEN_MINUS_PERCENT, lexer.TOKEN_ASTERISK_PERCENT,
		lexer.TOKEN_LEFT_SHIFT, lexer.TOKEN_RIGHT_SHIFT,
		lexer.TOKEN_AMPERSAND, lexer.TOKEN_PIPE, lexer.TOKEN_CARET:
		return true
	default:
		return false
	}
}

// parseCatchExpr parses a catch expression: expr catch |err| { ... } or expr catch { ... }
func (p *Parser) parseCatchExpr(expr Expr) (Expr, error) {
	if !p.match(lexer.TOKEN_CATCH) {
		return nil, fmt.Errorf("expected 'catch' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'catch'

	// Parse optional error variable: |err|
	var errorVar string
	if p.match(lexer.TOKEN_PIPE) {
		p.consume() // consume '|'
		if p.match(lexer.TOKEN_IDENTIFIER) {
			errorVar = p.currentToken.Value
			p.consume() // consume identifier
		}
		if _, err := p.expect(lexer.TOKEN_PIPE); err != nil {
			return nil, fmt.Errorf("expected '|' after error variable in catch expression: %w", err)
		}
	}

	// Parse catch body (block)
	catchBody, err := p.parseBlock()
	if err != nil {
		return nil, fmt.Errorf("failed to parse catch block: %w", err)
	}

	return &CatchExpr{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Expr:      expr,
		ErrorVar:  errorVar,
		CatchBody: catchBody,
	}, nil
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

// parseMatchExpr parses a match expression: match expr { pattern => body, ... }
func (p *Parser) parseMatchExpr() (*MatchExpr, error) {
	if !p.match(lexer.TOKEN_MATCH) {
		return nil, fmt.Errorf("expected 'match' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'match'

	// Parse the expression to match
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF in match expression")
	}

	// Special handling: if current token is identifier, parse it directly
	// to avoid struct initialization ambiguity
	var expr Expr
	var err error
	if p.match(lexer.TOKEN_IDENTIFIER) || p.match(lexer.TOKEN_ERROR) {
		name := p.currentToken.Value
		if p.match(lexer.TOKEN_ERROR) {
			name = "error"
		}
		expr = &Identifier{
			NodeBase: NodeBase{
				Line:     p.currentToken.Line,
				Column:   p.currentToken.Column,
				Filename: filename,
			},
			Name: name,
		}
		p.consume() // consume identifier
	} else {
		// For non-identifier expressions, use the full expression parser
		expr, err = p.parseExpression()
		if err != nil {
			return nil, fmt.Errorf("failed to parse match expression: %w", err)
		}
	}

	// Expect '{'
	if _, err := p.expect(lexer.TOKEN_LEFT_BRACE); err != nil {
		return nil, fmt.Errorf("expected '{' after match expression: %w", err)
	}

	// Create match expression node
	matchExpr := &MatchExpr{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Expr:     expr,
		Patterns: []*Pattern{},
	}

	// Parse pattern => body pairs
	for p.currentToken != nil && !p.match(lexer.TOKEN_RIGHT_BRACE) {
		pattern, err := p.parsePattern()
		if err != nil {
			return nil, fmt.Errorf("failed to parse pattern: %w", err)
		}

		matchExpr.Patterns = append(matchExpr.Patterns, pattern)

		// Check for comma between patterns (optional)
		if p.match(lexer.TOKEN_COMMA) {
			p.consume()
		}
	}

	// Expect '}'
	if _, err := p.expect(lexer.TOKEN_RIGHT_BRACE); err != nil {
		return nil, fmt.Errorf("expected '}' after match patterns: %w", err)
	}

	return matchExpr, nil
}

// parsePattern parses a pattern: pattern_expr => body
func (p *Parser) parsePattern() (*Pattern, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF in pattern")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename

	// Parse pattern expression
	var patternExpr Expr
	var err error

	// Handle 'else' keyword as a pattern
	if p.match(lexer.TOKEN_ELSE) {
		patternExpr = &Identifier{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Name: "else",
		}
		p.consume() // consume 'else'
	} else if p.match(lexer.TOKEN_IDENTIFIER) || p.match(lexer.TOKEN_ERROR) {
		// For identifier patterns, use full expression parser to support member access (e.g., Color.Red)
		patternExpr, err = p.parseExpression()
		if err != nil {
			return nil, fmt.Errorf("failed to parse identifier pattern: %w", err)
		}
	} else if p.match(lexer.TOKEN_NUMBER) {
		value := p.currentToken.Value
		p.consume() // consume number
		patternExpr = &NumberLiteral{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Value: value,
		}
	} else if p.match(lexer.TOKEN_STRING) {
		value := p.currentToken.Value
		p.consume() // consume string
		patternExpr = &StringLiteral{
			NodeBase: NodeBase{
				Line:     line,
				Column:   col,
				Filename: filename,
			},
			Value: value,
		}
	} else if p.match(lexer.TOKEN_LEFT_PAREN) {
		// Parse tuple pattern: (pattern1, pattern2, ...)
		// In patterns, parentheses always mean tuple pattern
		patternExpr, err = p.parseTupleLiteral()
		if err != nil {
			return nil, fmt.Errorf("failed to parse tuple pattern: %w", err)
		}
	} else {
		// For other cases, use the full expression parser
		patternExpr, err = p.parseExpression()
		if err != nil {
			return nil, fmt.Errorf("failed to parse pattern expression: %w", err)
		}
	}

	// Expect '=>'
	if _, err := p.expect(lexer.TOKEN_ARROW); err != nil {
		return nil, fmt.Errorf("expected '=>' after pattern: %w", err)
	}

	// Parse body expression (pattern body is an expression, not a block)
	bodyExpr, err := p.parseExpression()
	if err != nil {
		return nil, fmt.Errorf("failed to parse pattern body: %w", err)
	}

	return &Pattern{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		PatternType: 0, // TODO: Set pattern type based on pattern expression
		Value:       patternExpr,
		Body:        bodyExpr,
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

	// Handle string literals (check for string interpolation)
	if p.match(lexer.TOKEN_STRING) {
		stringToken := p.currentToken
		value := stringToken.Value

		// Check if string contains interpolation syntax ${}
		if strings.Contains(value, "${") {
			// Parse as string interpolation
			interp, err := p.parseStringInterpolation(stringToken)
			p.consume() // consume string token
			if err != nil {
				// On error, fall back to regular string literal
				return &StringLiteral{
					NodeBase: NodeBase{
						Line:     line,
						Column:   col,
						Filename: filename,
					},
					Value: value,
				}, nil
			}
			return interp, nil
		}

		// Regular string literal
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

	// Handle parenthesized expressions: (expr) or tuple literals: (expr1, expr2, ...)
	if p.match(lexer.TOKEN_LEFT_PAREN) {
		tupleLine := p.currentToken.Line
		tupleCol := p.currentToken.Column
		p.consume() // consume '('

		// Check for empty tuple: ()
		if p.match(lexer.TOKEN_RIGHT_PAREN) {
			p.consume() // consume ')'
			return &TupleLiteral{
				NodeBase: NodeBase{
					Line:     tupleLine,
					Column:   tupleCol,
					Filename: filename,
				},
				Elements: []Expr{},
			}, nil
		}

		// Parse first expression
		firstExpr, err := p.parseExpression()
		if err != nil {
			return nil, fmt.Errorf("failed to parse expression in parentheses or tuple: %w", err)
		}

		// Check if there's a comma - if yes, it's a tuple literal
		if p.match(lexer.TOKEN_COMMA) {
			// Parse tuple literal: (expr1, expr2, ...)
			elements := []Expr{firstExpr}
			p.consume() // consume ','

			// Parse remaining elements
			for !p.match(lexer.TOKEN_RIGHT_PAREN) {
				elem, err := p.parseExpression()
				if err != nil {
					return nil, fmt.Errorf("failed to parse tuple element: %w", err)
				}
				elements = append(elements, elem)

				if p.match(lexer.TOKEN_COMMA) {
					p.consume() // consume ','
				} else {
					break
				}
			}

			// Expect ')'
			if _, err := p.expect(lexer.TOKEN_RIGHT_PAREN); err != nil {
				return nil, fmt.Errorf("expected ')' after tuple elements: %w", err)
			}

			return &TupleLiteral{
				NodeBase: NodeBase{
					Line:     tupleLine,
					Column:   tupleCol,
					Filename: filename,
				},
				Elements: elements,
			}, nil
		}

		// No comma after first expression - it's a parenthesized expression: (expr)
		if _, err := p.expect(lexer.TOKEN_RIGHT_PAREN); err != nil {
			return nil, fmt.Errorf("expected ')' after expression: %w", err)
		}

		return firstExpr, nil
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

// parseTupleLiteral parses a tuple literal: (expr1, expr2, ...)
// This function always parses as a tuple literal (even with single element or empty)
// Caller should use parsePrimary for expressions that need to distinguish between
// parenthesized expressions and tuple literals.
func (p *Parser) parseTupleLiteral() (*TupleLiteral, error) {
	if !p.match(lexer.TOKEN_LEFT_PAREN) {
		return nil, fmt.Errorf("expected '(' for tuple literal")
	}

	tupleLine := p.currentToken.Line
	tupleCol := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume '('

	elements := []Expr{}

	// Parse elements if not empty tuple
	if !p.match(lexer.TOKEN_RIGHT_PAREN) {
		for {
			elem, err := p.parseExpression()
			if err != nil {
				return nil, fmt.Errorf("failed to parse tuple element: %w", err)
			}
			elements = append(elements, elem)

			if p.match(lexer.TOKEN_COMMA) {
				p.consume() // consume ','
			} else {
				break
			}
		}
	}

	// Expect ')'
	if _, err := p.expect(lexer.TOKEN_RIGHT_PAREN); err != nil {
		return nil, fmt.Errorf("expected ')' after tuple elements: %w", err)
	}

	return &TupleLiteral{
		NodeBase: NodeBase{
			Line:     tupleLine,
			Column:   tupleCol,
			Filename: filename,
		},
		Elements: elements,
	}, nil
}

