package codegen

import (
	"github.com/uya/compiler-go/src/ir"
)

// genMemberAccess generates code for member access (obj.field)
func (g *Generator) genMemberAccess(inst *ir.MemberAccessInst) error {
	// Generate object expression
	if err := g.WriteValue(inst.Object); err != nil {
		return err
	}
	
	// Write member access operator
	if err := g.Write("."); err != nil {
		return err
	}
	
	// Write field name
	return g.Write(inst.FieldName)
}

// genSubscript generates code for array subscript access (arr[index])
func (g *Generator) genSubscript(inst *ir.SubscriptInst) error {
	// Generate array expression
	if err := g.WriteValue(inst.Array); err != nil {
		return err
	}
	
	// Write opening bracket
	if err := g.Write("["); err != nil {
		return err
	}
	
	// Generate index expression
	if err := g.WriteValue(inst.Index); err != nil {
		return err
	}
	
	// Write closing bracket
	return g.Write("]")
}

// genStructInit generates code for struct initialization
func (g *Generator) genStructInit(inst *ir.StructInitInst) error {
	// Write struct name or empty for tuple
	if inst.StructName != "" {
		if err := g.Write(inst.StructName); err != nil {
			return err
		}
	}
	
	// Write opening brace
	if err := g.Write("{"); err != nil {
		return err
	}
	
	// Write field initializations
	for i, fieldInit := range inst.FieldInits {
		if i > 0 {
			if err := g.Write(", "); err != nil {
				return err
			}
		}
		
		// Write field name if present (for struct initialization)
		if len(inst.FieldNames) > i && inst.FieldNames[i] != "" {
			if err := g.Writef(".%s = ", inst.FieldNames[i]); err != nil {
				return err
			}
		}
		
		// Generate field initialization expression
		if err := g.WriteValue(fieldInit); err != nil {
			return err
		}
	}
	
	// Write closing brace
	return g.Write("}")
}

// genErrorValue generates code for error value (error.ErrorName)
func (g *Generator) genErrorValue(inst *ir.ErrorValueInst) error {
	// Error values are represented as constants in C
	// Use the error code hash function to generate the error code
	if err := g.Write("error_code_"); err != nil {
		return err
	}
	
	// Write error name (will be hashed by codegen)
	return g.Write(inst.ErrorName)
}

// genGoto generates code for goto statement
func (g *Generator) genGoto(inst *ir.GotoInst) error {
	if err := g.Write("goto "); err != nil {
		return err
	}
	
	return g.Write(inst.Label)
}

// genLabel generates code for label statement
func (g *Generator) genLabel(inst *ir.LabelInst) error {
	if err := g.Write(inst.Label); err != nil {
		return err
	}
	
	return g.Write(":")
}

// genStringInterpolation generates code for string interpolation
func (g *Generator) genStringInterpolation(inst *ir.StringInterpolationInst) error {
	// String interpolation is converted to a series of string concatenations
	// Format: "text1" + expr1 + "text2" + expr2 + ...
	
	if len(inst.TextSegments) == 0 && len(inst.InterpExprs) == 0 {
		// Empty string
		return g.Write(`""`)
	}
	
	// Start with first text segment (if exists)
	textIdx := 0
	exprIdx := 0
	
	// Write first text segment
	if textIdx < len(inst.TextSegments) {
		if err := g.Writef(`"%s"`, inst.TextSegments[textIdx]); err != nil {
			return err
		}
		textIdx++
	}
	
	// Write interpolation expressions and text segments
	for exprIdx < len(inst.InterpExprs) {
		// Write concatenation operator
		if err := g.Write(" + "); err != nil {
			return err
		}
		
		// Write interpolation expression
		if err := g.WriteValue(inst.InterpExprs[exprIdx]); err != nil {
			return err
		}
		exprIdx++
		
		// Write next text segment if exists
		if textIdx < len(inst.TextSegments) {
			if err := g.Write(" + "); err != nil {
				return err
			}
			if err := g.Writef(`"%s"`, inst.TextSegments[textIdx]); err != nil {
				return err
			}
			textIdx++
		}
	}
	
	return nil
}

// genTryCatch generates code for try-catch expression
func (g *Generator) genTryCatch(inst *ir.TryCatchInst) error {
	// Try-catch in Uya is used for error handling
	// For now, use a simplified implementation: just evaluate the try expression
	// TODO: Full implementation needs error union type handling and error propagation
	
	if err := g.WriteValue(inst.TryExpr); err != nil {
		return err
	}
	
	// TODO: Generate catch block handling
	// This requires error union type support in codegen
	
	return nil
}

