package parser

import (
	"fmt"

	"github.com/uya/compiler-go/src/lexer"
)

// parseStatement parses a statement
// This is the entry point for all statement parsing
func (p *Parser) parseStatement() (Stmt, error) {
	if p.currentToken == nil {
		return nil, fmt.Errorf("unexpected EOF")
	}

	// Route to different statement parsers based on token type
	if p.match(lexer.TOKEN_VAR) || p.match(lexer.TOKEN_CONST) {
		return p.parseVarDecl()
	} else if p.match(lexer.TOKEN_RETURN) {
		return p.parseReturnStmt()
	} else if p.match(lexer.TOKEN_IF) {
		return p.parseIfStmt()
	} else if p.match(lexer.TOKEN_WHILE) {
		return p.parseWhileStmt()
	} else if p.match(lexer.TOKEN_FOR) {
		return p.parseForStmt()
	} else if p.match(lexer.TOKEN_DEFER) {
		return p.parseDeferStmt()
	} else if p.match(lexer.TOKEN_ERRDEFER) {
		return p.parseErrDeferStmt()
	} else if p.match(lexer.TOKEN_BREAK) {
		return p.parseBreakStmt()
	} else if p.match(lexer.TOKEN_CONTINUE) {
		return p.parseContinueStmt()
	} else if p.match(lexer.TOKEN_LEFT_BRACE) {
		// Parse standalone block statement: { ... }
		return p.parseBlock()
	} else {
		// Parse as expression statement (which may include assignments)
		expr, err := p.parseExpression()
		if err != nil {
			return nil, fmt.Errorf("failed to parse expression: %w", err)
		}

		// Expect semicolon for expression statements
		if _, err := p.expect(lexer.TOKEN_SEMICOLON); err != nil {
			return nil, fmt.Errorf("expected ';' after expression: %w", err)
		}

		return &ExprStmt{
			NodeBase: *expr.Base(),
			Expr:     expr,
		}, nil
	}
}

// parseDeferStmt parses a defer statement: defer { ... }
func (p *Parser) parseDeferStmt() (*DeferStmt, error) {
	if !p.match(lexer.TOKEN_DEFER) {
		return nil, fmt.Errorf("expected 'defer' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'defer'

	// Parse defer block
	body, err := p.parseBlock()
	if err != nil {
		return nil, fmt.Errorf("failed to parse defer block: %w", err)
	}

	return &DeferStmt{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Body: body,
	}, nil
}

// parseErrDeferStmt parses an errdefer statement: errdefer { ... }
func (p *Parser) parseErrDeferStmt() (*ErrDeferStmt, error) {
	if !p.match(lexer.TOKEN_ERRDEFER) {
		return nil, fmt.Errorf("expected 'errdefer' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'errdefer'

	// Parse errdefer block
	body, err := p.parseBlock()
	if err != nil {
		return nil, fmt.Errorf("failed to parse errdefer block: %w", err)
	}

	return &ErrDeferStmt{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Body: body,
	}, nil
}

// parseBreakStmt parses a break statement: break;
func (p *Parser) parseBreakStmt() (*BreakStmt, error) {
	if !p.match(lexer.TOKEN_BREAK) {
		return nil, fmt.Errorf("expected 'break' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'break'

	// Expect semicolon
	if _, err := p.expect(lexer.TOKEN_SEMICOLON); err != nil {
		return nil, fmt.Errorf("expected ';' after break: %w", err)
	}

	return &BreakStmt{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
	}, nil
}

// parseContinueStmt parses a continue statement: continue;
func (p *Parser) parseContinueStmt() (*ContinueStmt, error) {
	if !p.match(lexer.TOKEN_CONTINUE) {
		return nil, fmt.Errorf("expected 'continue' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'continue'

	// Expect semicolon
	if _, err := p.expect(lexer.TOKEN_SEMICOLON); err != nil {
		return nil, fmt.Errorf("expected ';' after continue: %w", err)
	}

	return &ContinueStmt{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
	}, nil
}

// parseBlock parses a code block: { statements... }
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
	for p.currentToken != nil && !p.match(lexer.TOKEN_RIGHT_BRACE) {
		stmt, err := p.parseStatement()
		if err != nil {
			return nil, fmt.Errorf("failed to parse statement: %w", err)
		}

		block.Stmts = append(block.Stmts, stmt)

		// Consume semicolon if present (optional for some statements)
		if p.match(lexer.TOKEN_SEMICOLON) {
			p.consume()
		}
	}

	// Expect '}'
	if _, err := p.expect(lexer.TOKEN_RIGHT_BRACE); err != nil {
		return nil, fmt.Errorf("expected '}' to close block: %w", err)
	}

	return block, nil
}

// parseReturnStmt parses a return statement: return [expr];
func (p *Parser) parseReturnStmt() (*ReturnStmt, error) {
	if !p.match(lexer.TOKEN_RETURN) {
		return nil, fmt.Errorf("expected 'return' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'return'

	// Parse optional return expression
	var expr Expr
	if p.currentToken != nil && !p.match(lexer.TOKEN_SEMICOLON) {
		var err error
		expr, err = p.parseExpression()
		if err != nil {
			return nil, fmt.Errorf("failed to parse return expression: %w", err)
		}
	}

	// Expect semicolon
	if _, err := p.expect(lexer.TOKEN_SEMICOLON); err != nil {
		return nil, fmt.Errorf("expected ';' after return statement: %w", err)
	}

	return &ReturnStmt{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Expr: expr, // May be nil for void return
	}, nil
}

// parseVarDecl parses a variable declaration: var/const name: type = expr;
func (p *Parser) parseVarDecl() (*VarDecl, error) {
	isMut := false
	isConst := false

	// Support var and const
	if p.match(lexer.TOKEN_VAR) {
		p.consume() // consume 'var'
		isMut = true
	} else if p.match(lexer.TOKEN_CONST) {
		p.consume() // consume 'const'
		isConst = true
	} else {
		return nil, fmt.Errorf("expected 'var' or 'const' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename

	// Expect identifier (variable name)
	if !p.match(lexer.TOKEN_IDENTIFIER) {
		return nil, fmt.Errorf("expected variable name at %s:%d:%d", filename, line, col)
	}

	name := p.currentToken.Value
	p.consume() // consume variable name

	// Expect type annotation ':'
	var varType Type
	if p.match(lexer.TOKEN_COLON) {
		p.consume() // consume ':'
		var err error
		varType, err = p.parseType()
		if err != nil {
			return nil, fmt.Errorf("failed to parse variable type: %w", err)
		}
	}

	// Expect '=' and initialization expression
	if !p.match(lexer.TOKEN_ASSIGN) {
		return nil, fmt.Errorf("expected '=' after variable type at %s:%d:%d", filename, line, col)
	}
	p.consume() // consume '='

	initExpr, err := p.parseExpression()
	if err != nil {
		return nil, fmt.Errorf("failed to parse variable initialization expression: %w", err)
	}

	// Expect semicolon
	if _, err := p.expect(lexer.TOKEN_SEMICOLON); err != nil {
		return nil, fmt.Errorf("expected ';' after variable declaration: %w", err)
	}

	return &VarDecl{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name:    name,
		VarType: varType,
		Init:    initExpr,
		IsMut:   isMut,
		IsConst: isConst,
	}, nil
}

// parseIfStmt parses an if statement: if expr { ... } [ else { ... } ]
func (p *Parser) parseIfStmt() (*IfStmt, error) {
	if !p.match(lexer.TOKEN_IF) {
		return nil, fmt.Errorf("expected 'if' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'if'

	// Parse condition expression
	condition, err := p.parseExpression()
	if err != nil {
		return nil, fmt.Errorf("failed to parse if condition: %w", err)
	}

	// Parse then branch (code block)
	thenBranch, err := p.parseBlock()
	if err != nil {
		return nil, fmt.Errorf("failed to parse if then branch: %w", err)
	}

	// Check for else branch
	var elseBranch Stmt
	if p.match(lexer.TOKEN_ELSE) {
		p.consume() // consume 'else'

		// Check if it's an else if structure
		if p.match(lexer.TOKEN_IF) {
			// Recursively parse else if as a new if statement
			var err error
			elseBranch, err = p.parseIfStmt()
			if err != nil {
				return nil, fmt.Errorf("failed to parse else if: %w", err)
			}
		} else {
			// Regular else branch, parse code block
			var err error
			elseBranch, err = p.parseBlock()
			if err != nil {
				return nil, fmt.Errorf("failed to parse else branch: %w", err)
			}
		}
	}

	return &IfStmt{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Condition:  condition,
		ThenBranch: thenBranch,
		ElseBranch: elseBranch, // May be nil if no else branch
	}, nil
}

// parseWhileStmt parses a while statement: while expr { ... }
func (p *Parser) parseWhileStmt() (*WhileStmt, error) {
	if !p.match(lexer.TOKEN_WHILE) {
		return nil, fmt.Errorf("expected 'while' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'while'

	// Parse condition expression
	condition, err := p.parseExpression()
	if err != nil {
		return nil, fmt.Errorf("failed to parse while condition: %w", err)
	}

	// Parse loop body (code block)
	body, err := p.parseBlock()
	if err != nil {
		return nil, fmt.Errorf("failed to parse while body: %w", err)
	}

	return &WhileStmt{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Condition: condition,
		Body:      body,
	}, nil
}

// parseForStmt parses a for statement: for expr |var| { ... }
func (p *Parser) parseForStmt() (*ForStmt, error) {
	return nil, fmt.Errorf("parseForStmt not yet implemented (requires expression parsing)")
}

