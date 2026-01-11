package checker

import (
	"github.com/uya/compiler-go/src/lexer"
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
	rightType, ok := tc.typecheckExpression(expr.Right)
	if !ok {
		return TypeVoid, false
	}

	op := lexer.TokenType(expr.Op)

	// Check error type comparison: err == error.ErrorName or err != error.ErrorName
	isLeftErrorVar := false
	isRightErrorValue := isErrorValueExpr(expr.Right)
	isLeftErrorValue := isErrorValueExpr(expr.Left)
	isRightErrorVar := false

	if ident, ok := expr.Left.(*parser.Identifier); ok {
		isLeftErrorVar = true
		// Check if left is an error union type variable
		if sym := tc.LookupSymbol(ident.Name); sym != nil && sym.Type == TypeErrorUnion {
			isLeftErrorVar = true
		}
	}
	if ident, ok := expr.Right.(*parser.Identifier); ok {
		isRightErrorVar = true
		// Check if right is an error union type variable
		if sym := tc.LookupSymbol(ident.Name); sym != nil && sym.Type == TypeErrorUnion {
			isRightErrorVar = true
		}
	}

	// Error type comparison: only allow ==, not !=
	if (isLeftErrorVar && isRightErrorValue) || (isLeftErrorValue && isRightErrorVar) {
		if op == lexer.TOKEN_NOT_EQUAL {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("错误类型不支持不等性比较，仅支持相等性比较（使用 == 而不是 !=）(%s:%d:%d)",
					filename, expr.Line, expr.Column)
			} else {
				tc.AddError("错误类型不支持不等性比较，仅支持相等性比较（使用 == 而不是 !=）(行 %d:%d)",
					expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		// Allow == operator for error comparison (both are uint32_t)
		return TypeBool, true
	}

	// Check division by zero for / and %
	if op == lexer.TOKEN_SLASH || op == lexer.TOKEN_PERCENT {
		// Check if right operand is a constant zero
		rightVal := GetIntValue(expr.Right)
		if rightVal == 0 {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("除零错误 (%s:%d:%d)", filename, expr.Line, expr.Column)
			} else {
				tc.AddError("除零错误 (行 %d:%d)", expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
	}

	// Type checking based on operator
	switch op {
	case lexer.TOKEN_PLUS, lexer.TOKEN_MINUS, lexer.TOKEN_ASTERISK, lexer.TOKEN_SLASH,
		lexer.TOKEN_PLUS_PIPE, lexer.TOKEN_MINUS_PIPE, lexer.TOKEN_ASTERISK_PIPE,
		lexer.TOKEN_PLUS_PERCENT, lexer.TOKEN_MINUS_PERCENT, lexer.TOKEN_ASTERISK_PERCENT:
		// Arithmetic operators: both operands must be numeric
		if !isNumericType(leftType) || !isNumericType(rightType) {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			opStr := "算术运算符"
			if filename != "" {
				tc.AddError("%s要求两个操作数都是数值类型，但得到 %s 和 %s (%s:%d:%d)",
					opStr, getTypeName(leftType), getTypeName(rightType), filename, expr.Line, expr.Column)
			} else {
				tc.AddError("%s要求两个操作数都是数值类型，但得到 %s 和 %s (行 %d:%d)",
					opStr, getTypeName(leftType), getTypeName(rightType), expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		// Result type: if either operand is float, result is float; otherwise same as left
		if isFloatType(leftType) || isFloatType(rightType) {
			// Promote to float (use the larger float type)
			if leftType == TypeF64 || rightType == TypeF64 {
				return TypeF64, true
			}
			return TypeF32, true
		}
		// Both are integers, result type is same as left (type promotion would happen in codegen)
		return leftType, true

	case lexer.TOKEN_PERCENT:
		// Modulo operator: both operands must be integers
		if !isIntegerType(leftType) || !isIntegerType(rightType) {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("取模运算符%%要求两个操作数都是整数类型，但得到 %s 和 %s (%s:%d:%d)",
					getTypeName(leftType), getTypeName(rightType), filename, expr.Line, expr.Column)
			} else {
				tc.AddError("取模运算符%%要求两个操作数都是整数类型，但得到 %s 和 %s (行 %d:%d)",
					getTypeName(leftType), getTypeName(rightType), expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		return leftType, true

	case lexer.TOKEN_EQUAL, lexer.TOKEN_NOT_EQUAL, lexer.TOKEN_LESS, lexer.TOKEN_LESS_EQUAL,
		lexer.TOKEN_GREATER, lexer.TOKEN_GREATER_EQUAL:
		// Comparison operators: operands must be compatible, result is bool
		// Allow numeric types to compare with each other
		// Allow same types to compare
		if !typeMatch(leftType, rightType) && !(isNumericType(leftType) && isNumericType(rightType)) {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("比较运算符要求操作数类型兼容，但得到 %s 和 %s (%s:%d:%d)",
					getTypeName(leftType), getTypeName(rightType), filename, expr.Line, expr.Column)
			} else {
				tc.AddError("比较运算符要求操作数类型兼容，但得到 %s 和 %s (行 %d:%d)",
					getTypeName(leftType), getTypeName(rightType), expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		return TypeBool, true

	case lexer.TOKEN_LOGICAL_AND, lexer.TOKEN_LOGICAL_OR:
		// Logical operators: both operands must be bool, result is bool
		if !isBoolType(leftType) || !isBoolType(rightType) {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("逻辑运算符要求两个操作数都是bool类型，但得到 %s 和 %s (%s:%d:%d)",
					getTypeName(leftType), getTypeName(rightType), filename, expr.Line, expr.Column)
			} else {
				tc.AddError("逻辑运算符要求两个操作数都是bool类型，但得到 %s 和 %s (行 %d:%d)",
					getTypeName(leftType), getTypeName(rightType), expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		return TypeBool, true

	case lexer.TOKEN_AMPERSAND, lexer.TOKEN_PIPE, lexer.TOKEN_CARET,
		lexer.TOKEN_LEFT_SHIFT, lexer.TOKEN_RIGHT_SHIFT:
		// Bitwise operators: both operands must be integers
		if !isIntegerType(leftType) || !isIntegerType(rightType) {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("位运算符要求两个操作数都是整数类型，但得到 %s 和 %s (%s:%d:%d)",
					getTypeName(leftType), getTypeName(rightType), filename, expr.Line, expr.Column)
			} else {
				tc.AddError("位运算符要求两个操作数都是整数类型，但得到 %s 和 %s (行 %d:%d)",
					getTypeName(leftType), getTypeName(rightType), expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		return leftType, true

	default:
		// Unknown operator
		filename := expr.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("未知的二元运算符 (%s:%d:%d)", filename, expr.Line, expr.Column)
		} else {
			tc.AddError("未知的二元运算符 (行 %d:%d)", expr.Line, expr.Column)
		}
		return TypeVoid, false
	}
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

	op := lexer.TokenType(expr.Op)

	switch op {
	case lexer.TOKEN_MINUS:
		// Negation: operand must be numeric, result is same type
		if !isNumericType(operandType) {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("取负运算符-要求操作数是数值类型，但得到 %s (%s:%d:%d)",
					getTypeName(operandType), filename, expr.Line, expr.Column)
			} else {
				tc.AddError("取负运算符-要求操作数是数值类型，但得到 %s (行 %d:%d)",
					getTypeName(operandType), expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		return operandType, true

	case lexer.TOKEN_EXCLAMATION:
		// Logical NOT: operand must be bool, result is bool
		if !isBoolType(operandType) {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("逻辑非运算符!要求操作数是bool类型，但得到 %s (%s:%d:%d)",
					getTypeName(operandType), filename, expr.Line, expr.Column)
			} else {
				tc.AddError("逻辑非运算符!要求操作数是bool类型，但得到 %s (行 %d:%d)",
					getTypeName(operandType), expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		return TypeBool, true

	case lexer.TOKEN_ASTERISK:
		// Dereference: operand must be pointer, result is the pointed-to type
		// Note: For now, we return TypeVoid as we don't track the pointed-to type
		// In a full implementation, we would need to track pointer element types
		if !isPointerType(operandType) {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("解引用运算符*要求操作数是指针类型，但得到 %s (%s:%d:%d)",
					getTypeName(operandType), filename, expr.Line, expr.Column)
			} else {
				tc.AddError("解引用运算符*要求操作数是指针类型，但得到 %s (行 %d:%d)",
					getTypeName(operandType), expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		// TODO: Return the actual pointed-to type when we track pointer element types
		return TypeVoid, true

	case lexer.TOKEN_AMPERSAND:
		// Address-of: result is pointer type
		// Note: We don't check if operand is addressable here (lvalue check)
		// This is a simplification - full implementation would check lvalues
		return TypePtr, true

	case lexer.TOKEN_TILDE:
		// Bitwise NOT: operand must be integer, result is same type
		if !isIntegerType(operandType) {
			filename := expr.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("按位取反运算符~要求操作数是整数类型，但得到 %s (%s:%d:%d)",
					getTypeName(operandType), filename, expr.Line, expr.Column)
			} else {
				tc.AddError("按位取反运算符~要求操作数是整数类型，但得到 %s (行 %d:%d)",
					getTypeName(operandType), expr.Line, expr.Column)
			}
			return TypeVoid, false
		}
		return operandType, true

	case lexer.TOKEN_TRY:
		// Try expression: operand type is preserved, but error handling is added
		// The result type is the same as the operand (error union types are handled separately)
		return operandType, true

	default:
		// Unknown operator
		filename := expr.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("未知的一元运算符 (%s:%d:%d)", filename, expr.Line, expr.Column)
		} else {
			tc.AddError("未知的一元运算符 (行 %d:%d)", expr.Line, expr.Column)
		}
		return TypeVoid, false
	}
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

