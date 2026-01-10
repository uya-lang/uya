package codegen

import (
	"github.com/uya/compiler-go/src/ir"
)

// GenerateMain generates the main function and completes code generation
// This includes generating error union type definitions, struct/enum declarations,
// forward declarations, and function definitions
func (g *Generator) GenerateMain() error {
	// Generate error union type definitions
	if err := g.generateErrorUnionTypes(); err != nil {
		return err
	}

	// Generate slice and interface type definitions
	if err := g.generateSliceAndInterfaceTypes(); err != nil {
		return err
	}

	// First pass: Generate struct and enum declarations (must come before function declarations)
	if err := g.generateStructAndEnumDecls(); err != nil {
		return err
	}

	// Second pass: Generate forward declarations
	if err := g.generateForwardDeclarations(); err != nil {
		return err
	}

	// Third pass: Generate function definitions (skip struct/enum declarations already generated)
	if err := g.generateFunctionDefinitions(); err != nil {
		return err
	}

	return nil
}

// generateErrorUnionTypes generates error union type definitions for all used types
func (g *Generator) generateErrorUnionTypes() error {
	if g.irGen == nil {
		return nil
	}

	if err := g.Write("// Error union type definitions\n"); err != nil {
		return err
	}

	// Collect all error union return types from functions
	usedTypes := make(map[ir.Type]bool)
	instructions := g.irGen.Instructions()
	
	for _, inst := range instructions {
		if funcInst, ok := inst.(*ir.FuncDefInst); ok {
			if funcInst.ReturnTypeIsErrorUnion {
				baseType := funcInst.ReturnType
				// Skip struct types for now (need struct name which is not stored)
				if baseType != ir.TypeStruct {
					usedTypes[baseType] = true
				}
			}
		}
	}

	// Generate error union type definitions
	for baseType := range usedTypes {
		if err := g.WriteErrorUnionTypeDef(baseType); err != nil {
			return err
		}
	}

	return nil
}

// generateSliceAndInterfaceTypes generates slice and interface type definitions
func (g *Generator) generateSliceAndInterfaceTypes() error {
	// Generate slice type definition
	// According to uya.md: &[T] is represented as struct slice_T { void* ptr; size_t len; }
	if err := g.Write(`// Slice type definition
// Generic slice structure for all slice types
struct slice {
    void* ptr;    // 8 bytes (64-bit) or 4 bytes (32-bit)
    size_t len;   // 8 bytes (64-bit) or 4 bytes (32-bit)
};

`); err != nil {
		return err
	}

	// Generate interface type definition
	// According to uya.md: InterfaceName is represented as struct interface { void* vtable; void* data; }
	if err := g.Write(`// Interface type definition
// Generic interface structure for all interface types
struct interface {
    void* vtable;  // Virtual function table pointer
    void* data;    // Data pointer
};

`); err != nil {
		return err
	}

	return nil
}

// generateStructAndEnumDecls generates struct and enum declarations (first pass)
func (g *Generator) generateStructAndEnumDecls() error {
	if g.irGen == nil {
		return nil
	}

	instructions := g.irGen.Instructions()
	
	for _, inst := range instructions {
		switch inst.Type() {
		case ir.InstStructDecl, ir.InstEnumDecl:
			if err := g.GenerateInst(inst); err != nil {
				return err
			}
		}
	}

	return nil
}

// generateForwardDeclarations generates forward declarations for all functions
func (g *Generator) generateForwardDeclarations() error {
	if g.irGen == nil {
		return nil
	}

	if err := g.Write("// Forward declarations\n"); err != nil {
		return err
	}

	instructions := g.irGen.Instructions()
	
	for _, inst := range instructions {
		if funcInst, ok := inst.(*ir.FuncDefInst); ok {
			// Skip test functions
			if len(funcInst.Name) >= 6 && funcInst.Name[0:6] == "@test$" {
				continue
			}

			// Generate forward declaration
			if funcInst.ReturnTypeIsErrorUnion {
				if err := g.WriteErrorUnionTypeName(funcInst.ReturnType); err != nil {
					return err
				}
			} else if funcInst.ReturnType == ir.TypeStruct {
				cType := GetCTypeWithName(funcInst.ReturnType, funcInst.ReturnTypeOriginalName)
				if err := g.Write(cType); err != nil {
					return err
				}
			} else {
				cType := GetCType(funcInst.ReturnType)
				if err := g.Write(cType); err != nil {
					return err
				}
			}

			// Write function name and parameters
			if err := g.Writef(" %s(", funcInst.Name); err != nil {
				return err
			}

			// Write parameters
			for i, param := range funcInst.Params {
				if i > 0 {
					if err := g.Write(", "); err != nil {
						return err
					}
				}
				// Type assert to VarDeclInst to access fields
				if paramVarDecl, ok := param.(*ir.VarDeclInst); ok {
					cType := GetCTypeForVarDecl(paramVarDecl.Typ, paramVarDecl.OriginalTypeName, paramVarDecl.IsAtomic)
					if err := g.Write(cType); err != nil {
						return err
					}
					if err := g.Writef(" %s", paramVarDecl.Name); err != nil {
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

			if err := g.Write(");\n"); err != nil {
				return err
			}
		}
	}

	return g.Write("\n")
}

// generateFunctionDefinitions generates function definitions (third pass)
func (g *Generator) generateFunctionDefinitions() error {
	if g.irGen == nil {
		return nil
	}

	instructions := g.irGen.Instructions()
	
	for _, inst := range instructions {
		// Skip struct and enum declarations (already generated in first pass)
		if inst.Type() == ir.InstStructDecl || inst.Type() == ir.InstEnumDecl {
			continue
		}

		if err := g.GenerateInst(inst); err != nil {
			return err
		}
	}

	return nil
}

