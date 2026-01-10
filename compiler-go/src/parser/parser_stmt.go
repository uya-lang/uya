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

// Placeholder functions for statements that require expression parsing
// These will be implemented when expression parsing is ready

// parseReturnStmt parses a return statement: return [expr];
func (p *Parser) parseReturnStmt() (*ReturnStmt, error) {
	return nil, fmt.Errorf("parseReturnStmt not yet implemented (requires expression parsing)")
}

// parseVarDecl parses a variable declaration: var/const name: type = expr;
func (p *Parser) parseVarDecl() (*VarDecl, error) {
	return nil, fmt.Errorf("parseVarDecl not yet implemented (requires expression parsing)")
}

// parseIfStmt parses an if statement: if expr { ... } [ else { ... } ]
func (p *Parser) parseIfStmt() (*IfStmt, error) {
	return nil, fmt.Errorf("parseIfStmt not yet implemented (requires expression parsing)")
}

// parseWhileStmt parses a while statement: while expr { ... }
func (p *Parser) parseWhileStmt() (*WhileStmt, error) {
	return nil, fmt.Errorf("parseWhileStmt not yet implemented (requires expression parsing)")
}

// parseForStmt parses a for statement: for expr |var| { ... }
func (p *Parser) parseForStmt() (*ForStmt, error) {
	return nil, fmt.Errorf("parseForStmt not yet implemented (requires expression parsing)")
}

