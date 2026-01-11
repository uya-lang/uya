package codegen

import (
	"github.com/uya/compiler-go/src/ir"
)

// isErrorReturnValue checks if a return value is an error value
func isErrorReturnValue(inst ir.Inst) bool {
	if inst == nil {
		return false
	}
	
	// Check if it's an error value instruction
	if inst.Type() == ir.InstErrorValue {
		return true
	}
	
	// TODO: Check for other error value patterns (call to error.*, member access error.ErrorName, etc.)
	
	return false
}

// genFuncDefWithDefer generates a function definition with full defer/errdefer support
func (g *Generator) genFuncDefWithDefer(inst *ir.FuncDefInst) error {
	// Skip test functions in production mode (functions starting with @test$)
	if len(inst.Name) >= 6 && inst.Name[0:6] == "@test$" {
		return nil
	}

	// Save previous function context
	prevFunc := g.currentFunc
	g.currentFunc = inst
	defer func() {
		g.currentFunc = prevFunc
	}()

	// Write return type
	if inst.ReturnTypeIsErrorUnion {
		// Generate error union type name
		if err := g.WriteErrorUnionTypeName(inst.ReturnType); err != nil {
			return err
		}
		if err := g.Write(" "); err != nil {
			return err
		}
	} else {
		cType := GetCTypeWithName(inst.ReturnType, inst.ReturnTypeOriginalName)
		if err := g.Write(cType); err != nil {
			return err
		}
		if err := g.Write(" "); err != nil {
			return err
		}
	}

	// Write function name
	if err := g.Writef("%s(", inst.Name); err != nil {
		return err
	}

	// Write parameters
	for i, param := range inst.Params {
		if i > 0 {
			if err := g.Write(", "); err != nil {
				return err
			}
		}
		// Type assert to VarDeclInst to access fields
		if varDecl, ok := param.(*ir.VarDeclInst); ok {
			cType := GetCTypeForVarDecl(varDecl.Typ, varDecl.OriginalTypeName, varDecl.IsAtomic)
			if err := g.Write(cType); err != nil {
				return err
			}
			if err := g.Writef(" %s", varDecl.Name); err != nil {
				return err
			}
		} else {
			// Fallback for non-VarDeclInst parameters
			cType := GetCType(ir.TypeI32)
			if err := g.Writef("%s param_%d", cType, i); err != nil {
				return err
			}
		}
	}

	// Write function body opening
	if err := g.Write(") {\n"); err != nil {
		return err
	}

	// Collect defer and errdefer blocks
	var deferBlocks []*ir.DeferInst
	var errDeferBlocks []*ir.ErrDeferInst
	hasErrorReturnPath := false
	hasReturnValue := inst.ReturnType != ir.TypeVoid || inst.ReturnTypeIsErrorUnion
	returnVarName := "_return_" + inst.Name

	// Declare return variable if needed
	if hasReturnValue && inst.ReturnTypeIsErrorUnion {
		returnTypeName := GetCType(inst.ReturnType)
		if err := g.Writef("  struct error_union_%s %s;\n", returnTypeName, returnVarName); err != nil {
			return err
		}
	} else if hasReturnValue {
		cType := GetCTypeWithName(inst.ReturnType, inst.ReturnTypeOriginalName)
		if err := g.Writef("  %s %s;\n", cType, returnVarName); err != nil {
			return err
		}
	}

	// First pass: collect defer/errdefer blocks and generate normal statements
	for _, stmt := range inst.Body {
		switch stmt.Type() {
		case ir.InstDefer:
			deferBlocks = append(deferBlocks, stmt.(*ir.DeferInst))
			if err := g.Write("  // defer block (collected)\n"); err != nil {
				return err
			}
		case ir.InstErrDefer:
			errDeferBlocks = append(errDeferBlocks, stmt.(*ir.ErrDeferInst))
			if err := g.Write("  // errdefer block (collected)\n"); err != nil {
				return err
			}
		case ir.InstReturn:
			returnInst := stmt.(*ir.ReturnInst)
			// Check if this is an error return
			if inst.ReturnTypeIsErrorUnion && returnInst.Value != nil {
				if isErrorReturnValue(returnInst.Value) {
					hasErrorReturnPath = true
					// Generate error return: set error_id and goto error return label
					if err := g.Writef("  %s.error_id = ", returnVarName); err != nil {
						return err
					}
					if err := g.WriteValue(returnInst.Value); err != nil {
						return err
					}
					if err := g.Write(";\n"); err != nil {
						return err
					}
					if err := g.Writef("  goto _error_return_%s;\n", inst.Name); err != nil {
						return err
					}
					continue
				}
			}
			// Normal return
			if hasReturnValue {
				if inst.ReturnTypeIsErrorUnion {
					// Set error_id = 0 and value
					if err := g.Writef("  %s.error_id = 0;\n", returnVarName); err != nil {
						return err
					}
					if inst.ReturnType != ir.TypeVoid {
						if err := g.Writef("  %s.value = ", returnVarName); err != nil {
							return err
						}
						if returnInst.Value != nil {
							if err := g.WriteValue(returnInst.Value); err != nil {
								return err
							}
						}
						if err := g.Write(";\n"); err != nil {
							return err
						}
					}
				} else {
					// Direct assignment
					if returnInst.Value != nil {
						if err := g.Writef("  %s = ", returnVarName); err != nil {
							return err
						}
						if err := g.WriteValue(returnInst.Value); err != nil {
							return err
						}
						if err := g.Write(";\n"); err != nil {
							return err
						}
					}
				}
			}
			if err := g.Writef("  goto _normal_return_%s;\n", inst.Name); err != nil {
				return err
			}
		default:
			// Generate normal statement
			if err := g.Write("  "); err != nil {
				return err
			}
			if err := g.GenerateInst(stmt); err != nil {
				return err
			}
			if err := g.Write("\n"); err != nil {
				return err
			}
		}
	}

	// Generate error return label (if needed)
	if hasErrorReturnPath {
		if err := g.Writef("_error_return_%s:\n", inst.Name); err != nil {
			return err
		}

		// Generate errdefer blocks in LIFO order (error return)
		if len(errDeferBlocks) > 0 {
			if err := g.Write("  // Generated errdefer blocks in LIFO order (error return)\n"); err != nil {
				return err
			}
			for i := len(errDeferBlocks) - 1; i >= 0; i-- {
				errDeferInst := errDeferBlocks[i]
				if err := g.Writef("  // errdefer block %d\n", i); err != nil {
					return err
				}
				for _, stmt := range errDeferInst.Body {
					if err := g.Write("  "); err != nil {
						return err
					}
					if err := g.GenerateInst(stmt); err != nil {
						return err
					}
					if err := g.Write(";\n"); err != nil {
						return err
					}
				}
			}
		}

		// Generate defer blocks in LIFO order (error return also executes defer)
		if len(deferBlocks) > 0 {
			if err := g.Write("  // Generated defer blocks in LIFO order (error return)\n"); err != nil {
				return err
			}
			for i := len(deferBlocks) - 1; i >= 0; i-- {
				deferInst := deferBlocks[i]
				if err := g.Writef("  // defer block %d\n", i); err != nil {
					return err
				}
				for _, stmt := range deferInst.Body {
					if err := g.Write("  "); err != nil {
						return err
					}
					if err := g.GenerateInst(stmt); err != nil {
						return err
					}
					if err := g.Write(";\n"); err != nil {
						return err
					}
				}
			}
		}

		// Return error union
		if hasReturnValue {
			if err := g.Writef("  return %s;\n", returnVarName); err != nil {
				return err
			}
		} else {
			if err := g.Write("  return;\n"); err != nil {
				return err
			}
		}
	}

	// Generate normal return label
	if err := g.Writef("_normal_return_%s:\n", inst.Name); err != nil {
		return err
	}

	// Generate defer blocks in LIFO order (normal return)
	if len(deferBlocks) > 0 {
		if err := g.Write("  // Generated defer blocks in LIFO order\n"); err != nil {
			return err
		}
		for i := len(deferBlocks) - 1; i >= 0; i-- {
			deferInst := deferBlocks[i]
			if err := g.Writef("  // defer block %d\n", i); err != nil {
				return err
			}
			for _, stmt := range deferInst.Body {
				if err := g.Write("  "); err != nil {
					return err
				}
				if err := g.GenerateInst(stmt); err != nil {
					return err
				}
				if err := g.Write(";\n"); err != nil {
					return err
				}
			}
		}
	}

	// Return value
	if hasReturnValue {
		if err := g.Writef("  return %s;\n", returnVarName); err != nil {
			return err
		}
	}

	return g.Write("}\n\n")
}

