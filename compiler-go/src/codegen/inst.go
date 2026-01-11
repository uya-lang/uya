package codegen

import (
	"github.com/uya/compiler-go/src/ir"
)

// GenerateInst generates C code for an IR instruction
func (g *Generator) GenerateInst(inst ir.Inst) error {
	if inst == nil {
		return nil
	}

	switch inst.Type() {
	case ir.InstFuncDef:
		return g.genFuncDef(inst.(*ir.FuncDefInst))

	case ir.InstVarDecl:
		return g.genVarDecl(inst.(*ir.VarDeclInst))

	case ir.InstAssign:
		return g.genAssign(inst.(*ir.AssignInst))

	case ir.InstReturn:
		return g.genReturn(inst.(*ir.ReturnInst))

	case ir.InstIf:
		return g.genIf(inst.(*ir.IfInst))

	case ir.InstWhile:
		return g.genWhile(inst.(*ir.WhileInst))

	case ir.InstFor:
		return g.genFor(inst.(*ir.ForInst))

	case ir.InstBlock:
		return g.genBlock(inst.(*ir.BlockInst))

	case ir.InstCall:
		return g.genCall(inst.(*ir.CallInst))

	case ir.InstDefer:
		return g.genDefer(inst.(*ir.DeferInst))

	case ir.InstErrDefer:
		return g.genErrDefer(inst.(*ir.ErrDeferInst))

	case ir.InstMemberAccess:
		return g.genMemberAccess(inst.(*ir.MemberAccessInst))

	case ir.InstSubscript:
		return g.genSubscript(inst.(*ir.SubscriptInst))

	case ir.InstStructInit:
		return g.genStructInit(inst.(*ir.StructInitInst))

	case ir.InstErrorValue:
		return g.genErrorValue(inst.(*ir.ErrorValueInst))

	case ir.InstGoto:
		return g.genGoto(inst.(*ir.GotoInst))

	case ir.InstLabel:
		return g.genLabel(inst.(*ir.LabelInst))

	case ir.InstStringInterpolation:
		return g.genStringInterpolation(inst.(*ir.StringInterpolationInst))

	case ir.InstTryCatch:
		return g.genTryCatch(inst.(*ir.TryCatchInst))

	default:
		// For unsupported instruction types, write a comment
		return g.Writef("/* TODO: unsupported instruction type %v */\n", inst.Type())
	}
}

// genVarDecl generates a variable declaration
func (g *Generator) genVarDecl(inst *ir.VarDeclInst) error {
	// Write type
	cType := GetCTypeForVarDecl(inst.Typ, inst.OriginalTypeName, inst.IsAtomic)
	if err := g.Write(cType); err != nil {
		return err
	}

	// Write variable name
	if err := g.Writef(" %s", inst.Name); err != nil {
		return err
	}

	// Write initialization if present
	if inst.Init != nil {
		if err := g.Write(" = "); err != nil {
			return err
		}
		if err := g.WriteValue(inst.Init); err != nil {
			return err
		}
	}

	return g.Write(";")
}

// genAssign generates an assignment statement
func (g *Generator) genAssign(inst *ir.AssignInst) error {
	// Write destination
	if inst.DestExpr != nil {
		// Expression assignment: arr[0] = value
		if err := g.WriteValue(inst.DestExpr); err != nil {
			return err
		}
	} else if inst.Dest != "" {
		// Simple variable assignment: var = value
		if err := g.Write(inst.Dest); err != nil {
			return err
		}
	} else {
		return g.Write("/* unknown dest */")
	}

	// Write assignment operator
	if err := g.Write(" = "); err != nil {
		return err
	}

	// Write source value
	if inst.Src != nil {
		if err := g.WriteValue(inst.Src); err != nil {
			return err
		}
	} else {
		if err := g.Write("0"); err != nil {
			return err
		}
	}

	return nil
}

// genReturn generates a return statement
func (g *Generator) genReturn(inst *ir.ReturnInst) error {
	if err := g.Write("return"); err != nil {
		return err
	}

	if inst.Value != nil {
		if err := g.Write(" "); err != nil {
			return err
		}
		if err := g.WriteValue(inst.Value); err != nil {
			return err
		}
	}

	return nil
}

// genCall generates a function call statement
func (g *Generator) genCall(inst *ir.CallInst) error {
	return g.writeCall(inst)
}

// genIf generates an if statement
func (g *Generator) genIf(inst *ir.IfInst) error {
	// Write if condition
	if err := g.Write("if ("); err != nil {
		return err
	}
	if inst.Condition != nil {
		if err := g.WriteValue(inst.Condition); err != nil {
			return err
		}
	}
	if err := g.Write(") {\n"); err != nil {
		return err
	}

	// Write then branch
	if len(inst.ThenBody) > 0 {
		if err := g.Write("  "); err != nil {
			return err
		}
		for _, stmt := range inst.ThenBody {
			if err := g.GenerateInst(stmt); err != nil {
				return err
			}
			if err := g.Write("\n"); err != nil {
				return err
			}
		}
	}

	// Write else branch if present
	if len(inst.ElseBody) > 0 {
		if err := g.Write("} else {\n"); err != nil {
			return err
		}
		if err := g.Write("  "); err != nil {
			return err
		}
		for _, stmt := range inst.ElseBody {
			if err := g.GenerateInst(stmt); err != nil {
				return err
			}
			if err := g.Write("\n"); err != nil {
				return err
			}
		}
	}

	return g.Write("}")
}

// genWhile generates a while loop
func (g *Generator) genWhile(inst *ir.WhileInst) error {
	// Write while condition
	if err := g.Write("while ("); err != nil {
		return err
	}
	if inst.Condition != nil {
		if err := g.WriteValue(inst.Condition); err != nil {
			return err
		}
	}
	if err := g.Write(") {\n"); err != nil {
		return err
	}

	// Write loop body
	if len(inst.Body) > 0 {
		if err := g.Write("  "); err != nil {
			return err
		}
		for _, stmt := range inst.Body {
			if err := g.GenerateInst(stmt); err != nil {
				return err
			}
			if err := g.Write("\n"); err != nil {
				return err
			}
		}
	}

	return g.Write("}")
}

// genFor generates a for loop
func (g *Generator) genFor(inst *ir.ForInst) error {
	// For loop in Uya: for item in iterable { body }
	// According to uya.md, for loops are expanded to while loops at compile time
	// For code generation, we generate C for loops directly
	//
	// Implementation notes:
	// - Full implementation requires type information (array size, range bounds, iterator interface)
	// - Current implementation generates a basic structure with TODO comments for missing parts
	// - This allows the generated code to compile (with manual completion) while we work on full implementation
	
	// Generate for loop header
	if inst.ItemVar != "" {
		// For loop with item variable: for item in iterable { body }
		if err := g.Writef("for (int %s = 0; %s < /* TODO: iterable length or range end */; %s++) {\n",
			inst.ItemVar, inst.ItemVar, inst.ItemVar); err != nil {
			return err
		}
		
		// Add item assignment comment if iterable is present
		if inst.Iterable != nil {
			if err := g.Writef("  /* TODO: %s = iterable[%s] - need to generate iterable access */\n", inst.ItemVar, inst.ItemVar); err != nil {
				return err
			}
		}
	} else {
		// For loop without item variable: for iterable { body } or for start..end { body }
		if err := g.Write("for (int _loop_idx = 0; _loop_idx < /* TODO: iterable length or range end */; _loop_idx++) {\n"); err != nil {
			return err
		}
	}
	
	// Generate loop body
	if len(inst.Body) > 0 {
		for _, stmt := range inst.Body {
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
	
	return g.Write("}")
}

// genBlock generates a code block
func (g *Generator) genBlock(inst *ir.BlockInst) error {
	if err := g.Write("{\n"); err != nil {
		return err
	}

	for _, stmt := range inst.Insts {
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

	return g.Write("}")
}

// genFuncDef generates a function definition
// Implementation moved to inst_func.go for defer/errdefer support
func (g *Generator) genFuncDef(inst *ir.FuncDefInst) error {
	// This function is now implemented in inst_func.go
	// to support full defer/errdefer LIFO stack management
	return g.genFuncDefWithDefer(inst)
}

// genDefer generates a defer statement
func (g *Generator) genDefer(inst *ir.DeferInst) error {
	// Defer in Uya: defer { block }
	// In C, defer is typically implemented using goto labels and cleanup blocks
	// For now, generate the deferred block directly (simplified implementation)
	// TODO: Full implementation needs to stack defer blocks and execute them in reverse order
	
	if len(inst.Body) > 0 {
		// Generate deferred block
		for _, stmt := range inst.Body {
			if err := g.GenerateInst(stmt); err != nil {
				return err
			}
			if err := g.Write("\n"); err != nil {
				return err
			}
		}
	}
	
	return nil
}

// genErrDefer generates an errdefer statement
func (g *Generator) genErrDefer(inst *ir.ErrDeferInst) error {
	// Errdefer in Uya: errdefer { block }
	// Similar to defer, but only executes on error return
	// For now, generate the deferred block directly (simplified implementation)
	// TODO: Full implementation needs error-aware defer stacking
	
	if len(inst.Body) > 0 {
		// Generate deferred block
		for _, stmt := range inst.Body {
			if err := g.GenerateInst(stmt); err != nil {
				return err
			}
			if err := g.Write("\n"); err != nil {
				return err
			}
		}
	}
	
	return nil
}

