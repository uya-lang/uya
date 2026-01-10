package checker

import (
	"github.com/uya/compiler-go/src/parser"
)

// typecheckVarDecl checks a variable declaration
func (tc *TypeChecker) typecheckVarDecl(decl *parser.VarDecl) bool {
	if decl == nil {
		return false
	}

	// Get variable type
	var varType Type = TypeVoid
	if decl.VarType != nil {
		if typeNode, ok := decl.VarType.(parser.Type); ok {
			varType = getTypeFromAST(typeNode)
		} else {
			tc.AddError("无效的类型节点 (行 %d:%d)", decl.Line, decl.Column)
			return false
		}
	}
	scopeLevel := tc.CurrentScope()

	// Create symbol
	symbol := &Symbol{
		Name:       decl.Name,
		Type:       varType,
		IsMut:      decl.IsMut,
		IsConst:    decl.IsConst,
		ScopeLevel: scopeLevel,
		Line:       decl.Line,
		Column:     decl.Column,
		Filename:   decl.Filename,
	}

	// Extract array information
	if varType == TypeArray && decl.VarType != nil {
		if typeNode, ok := decl.VarType.(parser.Type); ok {
			symbol.ArraySize = getArraySizeFromAST(typeNode)
			symbol.ArrayElementType = getArrayElementTypeFromAST(typeNode)
		}
	}

	// Extract tuple information
	if decl.VarType != nil {
		if tupleType, ok := decl.VarType.(*parser.TupleType); ok {
			symbol.TupleElementCount = len(tupleType.ElementTypes)
		}
	}

	// Store original type name for user-defined types
	if namedType, ok := decl.VarType.(*parser.NamedType); ok {
		symbol.OriginalTypeName = namedType.Name
	}

	// Check initialization expression
	if decl.Init != nil {
		// Check the initialization expression
		initType, ok := tc.typecheckExpression(decl.Init)
		if !ok {
			return false
		}

		// Type matching check (simplified version)
		if initType != TypeVoid && !typeMatch(varType, initType) {
			// For number literals, allow type inference (all numeric types)
			if _, isNumber := decl.Init.(*parser.NumberLiteral); isNumber {
				if isNumericType(varType) {
					// Number literal type inference, allowed
				} else {
					tc.AddError("变量 '%s' 的类型与初始化表达式类型不匹配 (行 %d:%d)",
						decl.Name, decl.Line, decl.Column)
					return false
				}
			} else {
				// Type mismatch
				tc.AddError("变量 '%s' 的类型与初始化表达式类型不匹配 (行 %d:%d)",
					decl.Name, decl.Line, decl.Column)
				return false
			}
		}

		symbol.IsInitialized = true
	} else {
		// Uninitialized variable
		symbol.IsInitialized = false
	}

	// Add symbol to symbol table (with duplicate checking)
	if !tc.AddSymbol(symbol) {
		return false
	}

	return true
}

// typecheckFuncDecl checks a function declaration
func (tc *TypeChecker) typecheckFuncDecl(decl *parser.FuncDecl) bool {
	if decl == nil {
		return false
	}

	// During first pass (collect signatures), only collect function signature
	if tc.scanPass == ScanPassCollectSignatures {
		// Extract parameter types
		paramTypes := make([]Type, 0, len(decl.Params))
		for _, param := range decl.Params {
			if param.Type != nil {
				if typeNode, ok := param.Type.(parser.Type); ok {
					paramType := getTypeFromAST(typeNode)
					paramTypes = append(paramTypes, paramType)
				} else {
					tc.AddError("参数 '%s' 的类型无效 (行 %d:%d)", param.Name, param.Line, param.Column)
					return false
				}
			} else {
				tc.AddError("参数 '%s' 缺少类型 (行 %d:%d)", param.Name, param.Line, param.Column)
				return false
			}
		}

		// Extract return type
		var returnType Type = TypeVoid
		if decl.ReturnType != nil {
			if typeNode, ok := decl.ReturnType.(parser.Type); ok {
				returnType = getTypeFromAST(typeNode)
			}
		}

		// Create function signature
		sig := &FunctionSignature{
			Name:       decl.Name,
			ParamTypes: paramTypes,
			ReturnType: returnType,
			IsExtern:   decl.IsExtern,
			HasVarargs: false, // TODO: Support varargs
			Line:       decl.Line,
			Column:     decl.Column,
			Filename:   decl.Filename,
		}

		// Add to function table
		tc.AddFunction(sig)

		// For extern functions, we're done (no body to check)
		if decl.IsExtern || decl.Body == nil {
			return true
		}

		// For regular functions, we'll check the body in the second pass
		return true
	}

	// Second pass: check function body
	if tc.scanPass == ScanPassCheckBodies {
		// Enter function scope
		tc.functionScopeCounter++
		funcScopeLevel := tc.functionScopeCounter
		tc.EnterScope()

		// Add parameters as symbols
		for _, param := range decl.Params {
			var paramType Type = TypeVoid
			if param.Type != nil {
				if typeNode, ok := param.Type.(parser.Type); ok {
					paramType = getTypeFromAST(typeNode)
				}
			}

			paramSymbol := &Symbol{
				Name:          param.Name,
				Type:          paramType,
				IsMut:         false, // Parameters are immutable by default
				IsConst:       false,
				IsInitialized: true,  // Parameters are considered initialized
				ScopeLevel:    funcScopeLevel,
				Line:          param.Line,
				Column:        param.Column,
				Filename:      param.Filename,
			}

			// Store original type name
			if namedType, ok := param.Type.(*parser.NamedType); ok {
				paramSymbol.OriginalTypeName = namedType.Name
			}

			if !tc.AddSymbol(paramSymbol) {
				tc.ExitScope()
				return false
			}
		}

		// Check function body
		if decl.Body != nil {
			if !tc.typecheckBlock(decl.Body) {
				tc.ExitScope()
				return false
			}
		}

		// Exit function scope
		tc.ExitScope()

		return true
	}

	return true
}

// typecheckExternDecl checks an extern declaration
func (tc *TypeChecker) typecheckExternDecl(decl *parser.ExternDecl) bool {
	if decl == nil {
		return false
	}

	// Extern declarations wrap function or variable declarations
	// Check the inner declaration
	return tc.typecheckNode(decl.Decl)
}

