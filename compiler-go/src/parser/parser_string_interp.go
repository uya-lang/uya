package parser

import (
	"fmt"
	"strings"
	"unicode"

	"github.com/uya/compiler-go/src/lexer"
)

// parseFormatSpec parses a format specifier string (e.g., ":d", ":.2f", ":#06x")
func parseFormatSpec(specStr string) FormatSpec {
	spec := FormatSpec{
		Width:     -1,
		Precision: -1,
		Type:      0,
	}

	if specStr == "" {
		return spec
	}

	// Skip leading ':'
	p := specStr
	if len(p) > 0 && p[0] == ':' {
		p = p[1:]
	}

	var flags strings.Builder
	flagsLen := 0

	// Parse flags (#, 0, -, +, space)
	for len(p) > 0 {
		c := p[0]
		if strings.ContainsRune("#0-+ ", rune(c)) && flagsLen < 15 {
			flags.WriteByte(c)
			flagsLen++
			p = p[1:]
		} else {
			break
		}
	}
	if flagsLen > 0 {
		spec.Flags = flags.String()
	}

	// Parse width (digits)
	width := 0
	for len(p) > 0 && unicode.IsDigit(rune(p[0])) {
		width = width*10 + int(p[0]-'0')
		p = p[1:]
	}
	if width > 0 {
		spec.Width = width
	}

	// Parse precision (.digits)
	if len(p) > 0 && p[0] == '.' {
		p = p[1:]
		precision := 0
		for len(p) > 0 && unicode.IsDigit(rune(p[0])) {
			precision = precision*10 + int(p[0]-'0')
			p = p[1:]
		}
		if precision > 0 {
			spec.Precision = precision
		}
	}

	// Parse type (last character)
	if len(p) > 0 {
		spec.Type = p[0]
	}

	return spec
}

// parseStringInterpolation parses a string interpolation expression
// Token value format: full string with quotes, e.g., "text${expr}text"
func (p *Parser) parseStringInterpolation(stringToken *lexer.Token) (*StringInterpolation, error) {
	value := stringToken.Value
	if value == "" {
		return nil, fmt.Errorf("empty string token value")
	}

	// Extract string content (remove quotes)
	// Token value format: includes quotes, e.g., "text${expr}text"
	// We need to remove the leading and trailing quotes
	valueLen := len(value)
	if valueLen < 2 || value[0] != '"' || value[valueLen-1] != '"' {
		return nil, fmt.Errorf("invalid string format: missing quotes")
	}

	content := value[1 : valueLen-1] // Remove quotes

	// Create string interpolation node
	interpNode := &StringInterpolation{
		NodeBase: NodeBase{
			Line:     stringToken.Line,
			Column:   stringToken.Column,
			Filename: stringToken.Filename,
		},
		TextSegments: []string{},
		InterpExprs:  []Expr{},
		FormatSpecs:  []FormatSpec{},
		SegmentCount: 0,
		TextCount:    0,
		InterpCount:  0,
	}

	// Temporary arrays for text segments and interpolation expressions
	textSegments := []string{}
	interpExprs := []Expr{}
	formatSpecs := []FormatSpec{}

	pPos := 0
	textStart := 0

	for pPos < len(content) {
		// Check for interpolation start ${}
		if pPos+1 < len(content) && content[pPos] == '$' && content[pPos+1] == '{' {
			// Save current text segment
			textLen := pPos - textStart
			if textLen > 0 {
				textSegments = append(textSegments, content[textStart:pPos])
			}

			// Skip "${"
			pPos += 2
			if pPos >= len(content) {
				return nil, fmt.Errorf("unexpected end of string in interpolation")
			}

			exprStart := pPos

			// Find matching '}' (handle nested braces)
			braceDepth := 1
			exprEnd := -1
			formatStart := -1

			for pPos < len(content) && braceDepth > 0 {
				if content[pPos] == '{' {
					braceDepth++
				} else if content[pPos] == '}' {
					braceDepth--
					if braceDepth == 0 {
						exprEnd = pPos
						break
					}
				} else if content[pPos] == ':' && braceDepth == 1 && formatStart == -1 {
					// Found format specifier start (only record first colon)
					formatStart = pPos
				}
				pPos++
			}

			if exprEnd == -1 {
				return nil, fmt.Errorf("unmatched brace in interpolation")
			}

			// Extract expression string
			actualExprEnd := exprEnd
			if formatStart != -1 {
				actualExprEnd = formatStart
			}
			exprStr := content[exprStart:actualExprEnd]

			// Create temporary lexer to parse expression
			// Calculate column: original column + 1 (skip quote) + (exprStart)
			exprColumn := stringToken.Column + 1 + exprStart
			tempLexer := &lexer.Lexer{
				buffer:   exprStr,
				position: 0,
				line:     stringToken.Line,
				column:   exprColumn,
				filename: stringToken.Filename,
			}

			tempParser := NewParser(tempLexer)
			if tempParser == nil {
				return nil, fmt.Errorf("failed to create temporary parser")
			}

			expr, err := tempParser.parseExpression()
			if err != nil {
				return nil, fmt.Errorf("failed to parse interpolation expression: %w", err)
			}

			interpExprs = append(interpExprs, expr)

			// Parse format specifier
			var formatSpec FormatSpec
			if formatStart != -1 {
				formatStr := content[formatStart+1 : exprEnd] // Skip ':'
				formatSpec = parseFormatSpec(formatStr)
			}
			formatSpecs = append(formatSpecs, formatSpec)

			// Skip '}'
			pPos = exprEnd + 1
			textStart = pPos
		} else if pPos+1 < len(content) && content[pPos] == '\\' {
			// Skip escape sequence
			pPos += 2
			if pPos > len(content) {
				pPos = len(content)
			}
		} else {
			pPos++
		}
	}

	// Save final text segment
	textLen := len(content) - textStart
	if textLen > 0 {
		textSegments = append(textSegments, content[textStart:])
	}

	// Set node fields
	interpNode.TextSegments = textSegments
	interpNode.InterpExprs = interpExprs
	interpNode.FormatSpecs = formatSpecs
	interpNode.TextCount = len(textSegments)
	interpNode.InterpCount = len(interpExprs)
	interpNode.SegmentCount = len(textSegments) + len(interpExprs)

	return interpNode, nil
}

