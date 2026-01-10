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

	// Try to parse test block first (test is an identifier, not a keyword)
	if p.match(lexer.TOKEN_IDENTIFIER) && p.currentToken.Value == "test" {
		testBlock, err := p.parseTestBlock()
		if err == nil {
			return testBlock, nil
		}
		// If parsing fails, continue to try other declarations
	}

	if p.match(lexer.TOKEN_FN) {
		return p.parseFuncDecl()
	} else if p.match(lexer.TOKEN_STRUCT) {
		return p.parseStructDecl()
	} else if p.match(lexer.TOKEN_ERROR) {
		return p.parseErrorDecl()
	} else if p.match(lexer.TOKEN_ENUM) {
		return p.parseEnumDecl()
	} else if p.match(lexer.TOKEN_EXTERN) {
		return p.parseExternDecl()
	} else if p.match(lexer.TOKEN_INTERFACE) {
		return p.parseInterfaceDecl()
	}
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

// parseErrorDecl parses an error declaration: error ErrorName;
func (p *Parser) parseErrorDecl() (*ErrorDecl, error) {
	if !p.match(lexer.TOKEN_ERROR) {
		return nil, fmt.Errorf("expected 'error' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'error'

	// Expect error name
	if !p.match(lexer.TOKEN_IDENTIFIER) {
		return nil, fmt.Errorf("expected error name at %s:%d:%d", filename, line, col)
	}

	name := p.currentToken.Value
	p.consume() // consume error name

	// Expect ';'
	if _, err := p.expect(lexer.TOKEN_SEMICOLON); err != nil {
		return nil, fmt.Errorf("expected ';' after error declaration: %w", err)
	}

	return &ErrorDecl{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name: name,
	}, nil
}

// parseStructDecl parses a struct declaration: struct Name { fields... }
func (p *Parser) parseStructDecl() (*StructDecl, error) {
	if !p.match(lexer.TOKEN_STRUCT) {
		return nil, fmt.Errorf("expected 'struct' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'struct'

	// Expect struct name
	if !p.match(lexer.TOKEN_IDENTIFIER) {
		return nil, fmt.Errorf("expected struct name at %s:%d:%d", filename, line, col)
	}

	name := p.currentToken.Value
	p.consume() // consume struct name

	// Expect '{'
	if _, err := p.expect(lexer.TOKEN_LEFT_BRACE); err != nil {
		return nil, fmt.Errorf("expected '{' after struct name: %w", err)
	}

	// Parse field list
	fields := []*Field{}
	for p.currentToken != nil && !p.match(lexer.TOKEN_RIGHT_BRACE) {
		// Expect field name
		if !p.match(lexer.TOKEN_IDENTIFIER) {
			return nil, fmt.Errorf("expected field name at %s:%d:%d",
				p.currentToken.Filename, p.currentToken.Line, p.currentToken.Column)
		}

		fieldLine := p.currentToken.Line
		fieldCol := p.currentToken.Column
		fieldName := p.currentToken.Value
		p.consume() // consume field name

		// Expect ':'
		if _, err := p.expect(lexer.TOKEN_COLON); err != nil {
			return nil, fmt.Errorf("expected ':' after field name: %w", err)
		}

		// Parse field type
		fieldType, err := p.parseType()
		if err != nil {
			return nil, fmt.Errorf("failed to parse field type: %w", err)
		}

		fields = append(fields, &Field{
			NodeBase: NodeBase{
				Line:     fieldLine,
				Column:   fieldCol,
				Filename: filename,
			},
			Name: fieldName,
			Type: fieldType,
		})

		// Check for comma (optional)
		if p.match(lexer.TOKEN_COMMA) {
			p.consume() // consume ','
		}
	}

	// Expect '}'
	if _, err := p.expect(lexer.TOKEN_RIGHT_BRACE); err != nil {
		return nil, fmt.Errorf("expected '}' to close struct: %w", err)
	}

	return &StructDecl{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name:   name,
		Fields: fields,
	}, nil
}

// parseEnumDecl parses an enum declaration: enum Name [: UnderlyingType] { Variant1 [= value1], ... }
// Note: Go version currently doesn't support UnderlyingType, so it's ignored
func (p *Parser) parseEnumDecl() (*EnumDecl, error) {
	if !p.match(lexer.TOKEN_ENUM) {
		return nil, fmt.Errorf("expected 'enum' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'enum'

	// Expect enum name
	if !p.match(lexer.TOKEN_IDENTIFIER) {
		return nil, fmt.Errorf("expected enum name at %s:%d:%d", filename, line, col)
	}

	name := p.currentToken.Value
	p.consume() // consume enum name

	// TODO: Parse optional underlying type (: UnderlyingType)
	// Go version AST doesn't have UnderlyingType field yet
	if p.match(lexer.TOKEN_COLON) {
		p.consume() // consume ':'
		// Skip the type for now
		if _, err := p.parseType(); err != nil {
			return nil, fmt.Errorf("failed to parse underlying type: %w", err)
		}
	}

	// Expect '{'
	if _, err := p.expect(lexer.TOKEN_LEFT_BRACE); err != nil {
		return nil, fmt.Errorf("expected '{' after enum name: %w", err)
	}

	// Parse variant list
	variants := []EnumVariant{}
	for p.currentToken != nil && !p.match(lexer.TOKEN_RIGHT_BRACE) {
		// Expect variant name
		if !p.match(lexer.TOKEN_IDENTIFIER) {
			return nil, fmt.Errorf("expected variant name at %s:%d:%d",
				p.currentToken.Filename, p.currentToken.Line, p.currentToken.Column)
		}

		variantName := p.currentToken.Value
		variantValue := "" // Default: no explicit value
		p.consume() // consume variant name

		// Parse optional explicit value (= NUM)
		if p.match(lexer.TOKEN_ASSIGN) {
			p.consume() // consume '='
			if !p.match(lexer.TOKEN_NUMBER) {
				return nil, fmt.Errorf("expected number value after '=' at %s:%d:%d",
					p.currentToken.Filename, p.currentToken.Line, p.currentToken.Column)
			}
			variantValue = p.currentToken.Value
			p.consume() // consume number value
		}

		variants = append(variants, EnumVariant{
			Name:  variantName,
			Value: variantValue,
		})

		// Check for comma (optional)
		if p.match(lexer.TOKEN_COMMA) {
			p.consume() // consume ','
		} else if !p.match(lexer.TOKEN_RIGHT_BRACE) {
			return nil, fmt.Errorf("expected ',' or '}' after variant at %s:%d:%d",
				p.currentToken.Filename, p.currentToken.Line, p.currentToken.Column)
		}
	}

	// Expect '}'
	if _, err := p.expect(lexer.TOKEN_RIGHT_BRACE); err != nil {
		return nil, fmt.Errorf("expected '}' to close enum: %w", err)
	}

	return &EnumDecl{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name:     name,
		Variants: variants,
	}, nil
}

// parseExternDecl parses an extern declaration: extern fn name(params) -> return_type { body } or extern fn name(params) -> return_type;
// Note: extern declarations may have a body (exported function) or just a semicolon (external function declaration)
func (p *Parser) parseExternDecl() (*ExternDecl, error) {
	if !p.match(lexer.TOKEN_EXTERN) {
		return nil, fmt.Errorf("expected 'extern' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'extern'

	// Expect 'fn' keyword (extern fn name(...) type)
	if !p.match(lexer.TOKEN_FN) {
		return nil, fmt.Errorf("expected 'fn' keyword after 'extern' at %s:%d:%d", filename, line, col)
	}
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
		// Try to parse as a type
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

	// Parse function body (optional for extern)
	var body *Block
	if p.match(lexer.TOKEN_LEFT_BRACE) {
		// Has function body (exported function)
		var err error
		body, err = p.parseBlock()
		if err != nil {
			return nil, fmt.Errorf("failed to parse extern function body: %w", err)
		}
	} else if p.match(lexer.TOKEN_SEMICOLON) {
		// No function body, just declaration
		p.consume() // consume ';'
		body = nil
	} else {
		return nil, fmt.Errorf("expected '{' or ';' after extern function declaration at %s:%d:%d",
			filename, line, col)
	}

	fnDecl := &FuncDecl{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name:       name,
		Params:     params,
		ReturnType: returnType,
		Body:       body,
		IsExtern:   true,
	}

	return &ExternDecl{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name: name,
		Decl: fnDecl,
	}, nil
}

// parseInterfaceDecl parses an interface declaration: interface Name { fn method(params) return_type; ... }
func (p *Parser) parseInterfaceDecl() (*InterfaceDecl, error) {
	if !p.match(lexer.TOKEN_INTERFACE) {
		return nil, fmt.Errorf("expected 'interface' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'interface'

	// Expect interface name
	if !p.match(lexer.TOKEN_IDENTIFIER) {
		return nil, fmt.Errorf("expected interface name at %s:%d:%d", filename, line, col)
	}

	name := p.currentToken.Value
	p.consume() // consume interface name

	// Expect '{'
	if _, err := p.expect(lexer.TOKEN_LEFT_BRACE); err != nil {
		return nil, fmt.Errorf("expected '{' after interface name: %w", err)
	}

	// Parse method signatures and interface compositions
	methods := []*FuncDecl{}
	for p.currentToken != nil && !p.match(lexer.TOKEN_RIGHT_BRACE) {
		if p.match(lexer.TOKEN_FN) {
			// Parse method signature: fn method(params) return_type;
			method, err := p.parseInterfaceMethodSig()
			if err != nil {
				return nil, fmt.Errorf("failed to parse interface method signature: %w", err)
			}
			methods = append(methods, method)
		} else if p.match(lexer.TOKEN_IDENTIFIER) {
			// Parse interface composition: InterfaceName;
			// Interface composition is not fully supported in AST yet,
			// so we'll skip it for now (this is a TODO for the AST structure)
			_ = p.currentToken.Value // interface name (unused for now)
			p.consume()               // consume interface name

			// Expect ';'
			if _, err := p.expect(lexer.TOKEN_SEMICOLON); err != nil {
				return nil, fmt.Errorf("expected ';' after interface composition name: %w", err)
			}

			// Continue parsing (interface composition is skipped for now)
		} else {
			return nil, fmt.Errorf("expected method signature or interface composition at %s:%d:%d",
				p.currentToken.Filename, p.currentToken.Line, p.currentToken.Column)
		}
	}

	// Expect '}'
	if _, err := p.expect(lexer.TOKEN_RIGHT_BRACE); err != nil {
		return nil, fmt.Errorf("expected '}' to close interface: %w", err)
	}

	if len(methods) == 0 {
		return nil, fmt.Errorf("interface must have at least one method signature or interface composition at %s:%d:%d",
			filename, line, col)
	}

	return &InterfaceDecl{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name:    name,
		Methods: methods,
	}, nil
}

// parseInterfaceMethodSig parses an interface method signature: fn method(params) return_type;
// This is similar to parseFuncDecl but ends with semicolon instead of function body
func (p *Parser) parseInterfaceMethodSig() (*FuncDecl, error) {
	if !p.match(lexer.TOKEN_FN) {
		return nil, fmt.Errorf("expected 'fn' keyword")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'fn'

	// Expect method name
	if !p.match(lexer.TOKEN_IDENTIFIER) {
		return nil, fmt.Errorf("expected method name at %s:%d:%d", filename, line, col)
	}

	name := p.currentToken.Value
	p.consume() // consume method name

	// Expect '('
	if _, err := p.expect(lexer.TOKEN_LEFT_PAREN); err != nil {
		return nil, fmt.Errorf("expected '(' after method name: %w", err)
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
		// Try to parse as a type
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

	// Expect ';' (interface methods have no body, just a semicolon)
	if _, err := p.expect(lexer.TOKEN_SEMICOLON); err != nil {
		return nil, fmt.Errorf("expected ';' after method signature: %w", err)
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
		Body:       nil, // Interface methods have no body
		IsExtern:   false,
	}, nil
}

// parseTestBlock parses a test block: test "description" { ... }
func (p *Parser) parseTestBlock() (*TestBlock, error) {
	// Check if current token is identifier "test"
	if p.currentToken == nil || !p.match(lexer.TOKEN_IDENTIFIER) || p.currentToken.Value != "test" {
		return nil, fmt.Errorf("expected 'test' identifier")
	}

	line := p.currentToken.Line
	col := p.currentToken.Column
	filename := p.currentToken.Filename
	p.consume() // consume 'test'

	// Expect string literal (test description)
	if !p.match(lexer.TOKEN_STRING) {
		return nil, fmt.Errorf("expected string literal (test description) at %s:%d:%d", filename, line, col)
	}

	name := p.currentToken.Value
	p.consume() // consume string literal

	// Parse test body (code block)
	body, err := p.parseBlock()
	if err != nil {
		return nil, fmt.Errorf("failed to parse test block body: %w", err)
	}

	return &TestBlock{
		NodeBase: NodeBase{
			Line:     line,
			Column:   col,
			Filename: filename,
		},
		Name: name,
		Body: body,
	}, nil
}

