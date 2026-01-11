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
	// Try-catch in Uya: expr catch |err| { body } or expr catch { body }
	// Semantics: Evaluate expr (returns !T), check error_id
	//   - If error_id == 0: use value (success case)
	//   - If error_id != 0: execute catch block with error_id assigned to err (if present)
	// Returns: The value type (not error union type)
	//
	// Use GNU statement expression: ({ ... }) to return a value
	// Pattern: ({ struct error_union_T _temp = expr;
	//            if (_temp.error_id != 0) { uint32_t err = _temp.error_id; body } else { _temp.value } })
	
	// Generate temporary variable name
	tempVar := g.NextTemp()
	
	// Determine base type from TryExpr (for now, use i32 as default)
	// In a full implementation, we would extract the base type from TryExpr's type information
	baseTypeName := "int32_t" // Default to i32, could be improved with type information
	
	// Generate statement expression: ({ ... })
	if err := g.Write("({ struct error_union_"); err != nil {
		return err
	}
	if err := g.Write(baseTypeName); err != nil {
		return err
	}
	if err := g.Writef(" %s = ", tempVar); err != nil {
		return err
	}
	if err := g.WriteValue(inst.TryExpr); err != nil {
		return err
	}
	if err := g.Write("; "); err != nil {
		return err
	}
	
	// Error check: if (error_id != 0) { catch block } else { value }
	// Use ternary operator: condition ? catch_value : try_value
	if err := g.Writef("%s.error_id != 0 ? ", tempVar); err != nil {
		return err
	}
	
	// Error case: execute catch body (statement expression)
	if err := g.Write("({ "); err != nil {
		return err
	}
	
	// Assign error_id to error variable if present
	if inst.ErrorVar != "" {
		if err := g.Writef("uint32_t %s = %s.error_id; ", inst.ErrorVar, tempVar); err != nil {
			return err
		}
	}
	
	// Generate catch body
	// Catch body statements are generated as statements, and the last expression is used as return value
	if len(inst.CatchBody) > 0 {
		for i, stmt := range inst.CatchBody {
			// Check if this is the last statement (should be an expression)
			if i == len(inst.CatchBody)-1 {
				// Last statement: check if it's a BlockInst or regular statement
				if blockInst, ok := stmt.(*ir.BlockInst); ok {
					// BlockInst: generate block statements, last one is return value
					if len(blockInst.Insts) > 0 {
						for j, blockStmt := range blockInst.Insts {
							if j < len(blockInst.Insts)-1 {
								// Not last statement in block: generate as statement
								if err := g.GenerateInst(blockStmt); err != nil {
									return err
								}
								if err := g.Write("; "); err != nil {
									return err
								}
							} else {
								// Last statement in block: use as return value
								if err := g.WriteValue(blockStmt); err != nil {
									return err
								}
							}
						}
					} else {
						// Empty block: return 0
						if err := g.Write("0"); err != nil {
							return err
						}
					}
				} else {
					// Last statement is not a block: use as return value
					if err := g.WriteValue(stmt); err != nil {
						return err
					}
				}
			} else {
				// Not last statement: generate as statement
				if blockInst, ok := stmt.(*ir.BlockInst); ok {
					// BlockInst: generate all statements
					for _, blockStmt := range blockInst.Insts {
						if err := g.GenerateInst(blockStmt); err != nil {
							return err
						}
						if err := g.Write("; "); err != nil {
							return err
						}
					}
				} else {
					if err := g.GenerateInst(stmt); err != nil {
						return err
					}
					if err := g.Write("; "); err != nil {
						return err
					}
				}
			}
		}
	} else {
		// Empty catch body: return default value (0 for numeric types)
		if err := g.Write("0"); err != nil {
			return err
		}
	}
	
	if err := g.Write(" }) : "); err != nil {
		return err
	}
	
	// Success case: return value from error union
	if err := g.Writef("%s.value", tempVar); err != nil {
		return err
	}
	
	if err := g.Write("; })"); err != nil {
		return err
	}
	
	return nil
}

