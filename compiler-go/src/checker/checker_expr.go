package checker

import (
	"github.com/uya/compiler-go/src/parser"
)

// typecheckExpression checks an expression and returns its type and success status
func (tc *TypeChecker) typecheckExpression(expr parser.Expr) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	base := expr.Base()
	tc.currentLine = base.Line
	tc.currentColumn = base.Column
	tc.currentFile = base.Filename

	switch e := expr.(type) {
	case *parser.Identifier:
		return tc.typecheckIdentifier(e)

	case *parser.NumberLiteral:
		// Number literals can be inferred to any numeric type
		return TypeI32, true // Default to i32, actual type will be inferred from context

	case *parser.StringLiteral:
		// String literals are pointer types (char*)
		return TypePtr, true

	case *parser.BoolLiteral:
		return TypeBool, true

	case *parser.NullLiteral:
		return TypePtr, true // null is a pointer type

	case *parser.BinaryExpr:
		return tc.typecheckBinaryExpr(e)

	case *parser.UnaryExpr:
		return tc.typecheckUnaryExpr(e)

	case *parser.CallExpr:
		return tc.typecheckCallExpr(e)

	case *parser.MemberAccess:
		return tc.typecheckMemberAccess(e)

	case *parser.SubscriptExpr:
		return tc.typecheckSubscriptExpr(e)

	case *parser.CatchExpr:
		return tc.typecheckCatchExpr(e)

	case *parser.MatchExpr:
		return tc.typecheckMatchExpr(e)

	case *parser.StringInterpolation:
		return tc.typecheckStringInterpolation(e)

	case *parser.TupleLiteral:
		return tc.typecheckTupleLiteral(e)

	default:
		tc.AddError("未知的表达式类型 at %s:%d:%d",
			tc.currentFile, tc.currentLine, tc.currentColumn)
		return TypeVoid, false
	}
}

// typecheckIdentifier checks an identifier expression
func (tc *TypeChecker) typecheckIdentifier(ident *parser.Identifier) (Type, bool) {
	if ident == nil {
		return TypeVoid, false
	}

	// Look up the symbol
	symbol := tc.LookupSymbol(ident.Name)
	if symbol == nil {
		filename := ident.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("未定义的变量 '%s' (%s:%d:%d)",
				ident.Name, filename, ident.Line, ident.Column)
		} else {
			tc.AddError("未定义的变量 '%s' (行 %d:%d)",
				ident.Name, ident.Line, ident.Column)
		}
		return TypeVoid, false
	}

	// Check if the variable is initialized
	// Arrays can be initialized by element assignment, so skip check for arrays
	if !symbol.IsInitialized && !symbol.IsConst && symbol.Type != TypeArray {
		filename := ident.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("使用未初始化的变量 '%s' (%s:%d:%d)\n  提示: 变量必须在首次使用前被赋值",
				ident.Name, filename, ident.Line, ident.Column)
		} else {
			tc.AddError("使用未初始化的变量 '%s' (行 %d:%d)\n  提示: 变量必须在首次使用前被赋值",
				ident.Name, ident.Line, ident.Column)
		}
		return TypeVoid, false
	}

	return symbol.Type, true
}

// typecheckBinaryExpr checks a binary expression
func (tc *TypeChecker) typecheckBinaryExpr(expr *parser.BinaryExpr) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	// Check left operand
	leftType, ok := tc.typecheckExpression(expr.Left)
	if !ok {
		return TypeVoid, false
	}

	// Check right operand
	_, ok = tc.typecheckExpression(expr.Right)
	if !ok {
		return TypeVoid, false
	}

	// Type checking depends on the operator
	// For arithmetic operators, both operands should be numeric
	// For comparison operators, result is bool
	// For logical operators, operands should be bool, result is bool
	// This is a simplified version - full implementation would be more complex

	// TODO: Implement proper type checking based on operator
	// For now, just check that expressions are valid
	return leftType, true
}

// typecheckUnaryExpr checks a unary expression
func (tc *TypeChecker) typecheckUnaryExpr(expr *parser.UnaryExpr) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	// Check operand
	operandType, ok := tc.typecheckExpression(expr.Operand)
	if !ok {
		return TypeVoid, false
	}

	// Type checking depends on the operator
	// For negation (-), operand should be numeric
	// For logical NOT (!), operand should be bool
	// For dereference (*), operand should be pointer
	// For address-of (&), result is pointer

	// TODO: Implement proper type checking based on operator
	return operandType, true
}

// typecheckCallExpr checks a function call expression
func (tc *TypeChecker) typecheckCallExpr(expr *parser.CallExpr) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	// Check all argument expressions
	for _, arg := range expr.Args {
		_, ok := tc.typecheckExpression(arg)
		if !ok {
			return TypeVoid, false
		}
	}

	// Get the callee (function name)
	calleeIdent, ok := expr.Callee.(*parser.Identifier)
	if !ok {
		// For now, only support identifier calls (not function pointers)
		return TypeVoid, true // Skip type checking for non-identifier calls
	}

	funcName := calleeIdent.Name

	// Special handling for "array" function (array literal)
	if funcName == "array" {
		return TypeArray, true
	}

	// Look up function signature
	sig := tc.LookupFunction(funcName)
	if sig == nil {
		filename := expr.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("未定义的函数 '%s' (%s:%d:%d)",
				funcName, filename, expr.Line, expr.Column)
		} else {
			tc.AddError("未定义的函数 '%s' (行 %d:%d)",
				funcName, expr.Line, expr.Column)
		}
		return TypeVoid, false
	}

	// Check argument count
	expectedParamCount := len(sig.ParamTypes)
	actualArgCount := len(expr.Args)

	if sig.HasVarargs {
		// For varargs functions, actual arguments should >= fixed parameters
		if actualArgCount < expectedParamCount {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("函数 '%s' 的参数数量不足 (期望至少 %d 个, 实际 %d 个) (%s:%d:%d)",
					funcName, expectedParamCount, actualArgCount, filename, expr.Line, expr.Column)
			} else {
				tc.AddError("函数 '%s' 的参数数量不足 (期望至少 %d 个, 实际 %d 个) (行 %d:%d)",
					funcName, expectedParamCount, actualArgCount, expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
	} else {
		// For regular functions, argument count must match exactly
		if actualArgCount != expectedParamCount {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("函数 '%s' 的参数数量不匹配 (期望 %d 个, 实际 %d 个) (%s:%d:%d)",
					funcName, expectedParamCount, actualArgCount, filename, expr.Line, expr.Column)
			} else {
				tc.AddError("函数 '%s' 的参数数量不匹配 (期望 %d 个, 实际 %d 个) (行 %d:%d)",
					funcName, expectedParamCount, actualArgCount, expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
	}

	// TODO: Check argument types match parameter types

	return sig.ReturnType, true
}

// typecheckMemberAccess checks a member access expression
func (tc *TypeChecker) typecheckMemberAccess(expr *parser.MemberAccess) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	// Check the object expression
	_, ok := tc.typecheckExpression(expr.Object)
	if !ok {
		return TypeVoid, false
	}

	// TODO: Implement member access type checking
	// This requires looking up struct/interface definitions
	return TypeVoid, true
}

// typecheckSubscriptExpr checks a subscript expression (array access)
func (tc *TypeChecker) typecheckSubscriptExpr(expr *parser.SubscriptExpr) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	// Check array expression
	arrayType, ok := tc.typecheckExpression(expr.Array)
	if !ok {
		return TypeVoid, false
	}

	// Check index expression
	_, ok = tc.typecheckExpression(expr.Index)
	if !ok {
		return TypeVoid, false
	}

	// Array access returns the element type
	if arrayType == TypeArray {
		// TODO: Get element type from symbol
		return TypeVoid, true
	}

	// TODO: Support other subscriptable types (slices, etc.)
	return TypeVoid, true
}

// typecheckCatchExpr checks a catch expression
func (tc *TypeChecker) typecheckCatchExpr(expr *parser.CatchExpr) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	// Check the expression being caught
	if expr.Expr != nil {
		_, ok := tc.typecheckExpression(expr.Expr)
		if !ok {
			return TypeVoid, false
		}
	}

	// Check the catch body
	if expr.CatchBody != nil {
		// TODO: Implement catch body checking with error variable
		// This requires special block checking
	}

	// TODO: Return the catch body's type
	return TypeVoid, true
}

// typecheckMatchExpr checks a match expression
func (tc *TypeChecker) typecheckMatchExpr(expr *parser.MatchExpr) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	// Check the expression to match
	if expr.Expr != nil {
		_, ok := tc.typecheckExpression(expr.Expr)
	if !ok {
		return TypeVoid, false
		}
	}

	// TODO: Implement match expression checking
	// This requires pattern matching type checking
	return TypeVoid, true
}

// typecheckStringInterpolation checks a string interpolation expression
func (tc *TypeChecker) typecheckStringInterpolation(expr *parser.StringInterpolation) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	// Check all interpolation expressions
	for _, interpExpr := range expr.InterpExprs {
		_, ok := tc.typecheckExpression(interpExpr)
		if !ok {
			return TypeVoid, false
		}
	}

	// String interpolation results in an array type
	return TypeArray, true
}

// typecheckTupleLiteral checks a tuple literal
func (tc *TypeChecker) typecheckTupleLiteral(expr *parser.TupleLiteral) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	// Check all element expressions
	for _, elem := range expr.Elements {
		_, ok := tc.typecheckExpression(elem)
		if !ok {
			return TypeVoid, false
		}
	}

	// Tuple literals are represented as struct type
	return TypeStruct, true
}

