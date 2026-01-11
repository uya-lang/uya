package checker

import (
	"strconv"

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

	// Check if this is error.ErrorName (error value expression)
	if isErrorValueExpr(expr) {
		// error.ErrorName is a valid error value expression, type is uint32_t (error code)
		// The field name should be a valid error name, but we don't validate it here
		// (error declarations are checked separately)
		return TypeU32, true
	}

	// Check the object expression
	objectType, ok := tc.typecheckExpression(expr.Object)
	if !ok {
		return TypeVoid, false
	}

	// Check if this is tuple field access (tuple.0, tuple.1, ...)
	if expr.FieldName != "" {
		// Check if field_name is a numeric string (tuple field index)
		isNumeric := true
		for _, ch := range expr.FieldName {
			if ch < '0' || ch > '9' {
				isNumeric = false
				break
			}
		}

		if isNumeric && len(expr.FieldName) > 0 {
			// This is tuple field access (e.g., tuple.0, tuple.1)
			// Parse the field index
			fieldIndex := int64(0)
			for _, ch := range expr.FieldName {
				fieldIndex = fieldIndex*10 + int64(ch-'0')
			}

			// Try to get tuple element count from symbol table
			tupleElementCount := -1
			if ident, ok := expr.Object.(*parser.Identifier); ok {
				if sym := tc.LookupSymbol(ident.Name); sym != nil {
					tupleElementCount = sym.TupleElementCount
				}
			}

			// If we have tuple element count information, check index range
			if tupleElementCount >= 0 {
				if fieldIndex < 0 || fieldIndex >= int64(tupleElementCount) {
					objName := "tuple"
					if ident, ok := expr.Object.(*parser.Identifier); ok {
						objName = ident.Name
					}
					filename := expr.Filename
					if filename == "" {
						filename = tc.currentFile
					}
					if filename != "" {
						tc.AddError("元组字段索引越界：索引 %d 超出元组大小 %d (字段 '%s.%s' 在 %s:%d:%d)",
							fieldIndex, tupleElementCount, objName, expr.FieldName, filename, expr.Line, expr.Column)
					} else {
						tc.AddError("元组字段索引越界：索引 %d 超出元组大小 %d (字段 '%s.%s' 在行 %d:%d)",
							fieldIndex, tupleElementCount, objName, expr.FieldName, expr.Line, expr.Column)
					}
					return TypeVoid, false
				}
			}

			// For tuple field access, we return TypeVoid as placeholder
			// In a full implementation, we would return the actual tuple element type
			// TODO: Return the actual tuple element type
			return TypeVoid, true
		}
	}

	// For regular member access (struct field access), check if object type is struct
	if objectType != TypeStruct {
		filename := expr.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("成员访问只能用于结构体类型，但得到 %s (%s:%d:%d)",
				getTypeName(objectType), filename, expr.Line, expr.Column)
		} else {
			tc.AddError("成员访问只能用于结构体类型，但得到 %s (行 %d:%d)",
				getTypeName(objectType), expr.Line, expr.Column)
		}
		return TypeVoid, false
	}

	// Look up the struct declaration
	structName := ""
	if ident, ok := expr.Object.(*parser.Identifier); ok {
		if sym := tc.LookupSymbol(ident.Name); sym != nil {
			structName = sym.OriginalTypeName
		}
	}

	if structName == "" {
		// Cannot determine struct name, allow the access (may be valid in some contexts)
		// TODO: Improve type inference to track struct names
		return TypeVoid, true
	}

	// Find struct declaration
	if tc.programNode == nil {
		// Program node not available, allow the access
		return TypeVoid, true
	}

	structDecl := findStructDeclFromProgram(tc.programNode, structName)
	if structDecl == nil {
		filename := expr.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("未找到结构体声明 '%s' (%s:%d:%d)",
				structName, filename, expr.Line, expr.Column)
		} else {
			tc.AddError("未找到结构体声明 '%s' (行 %d:%d)",
				structName, expr.Line, expr.Column)
		}
		return TypeVoid, false
	}

	// Check if field exists in struct
	fieldFound := false
	var fieldType parser.Type
	for _, field := range structDecl.Fields {
		if field.Name == expr.FieldName {
			fieldFound = true
			if fieldTypeNode, ok := field.Type.(parser.Type); ok {
				fieldType = fieldTypeNode
			}
			break
		}
	}

	if !fieldFound {
		filename := expr.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("结构体 '%s' 没有字段 '%s' (%s:%d:%d)",
				structName, expr.FieldName, filename, expr.Line, expr.Column)
		} else {
			tc.AddError("结构体 '%s' 没有字段 '%s' (行 %d:%d)",
				structName, expr.FieldName, expr.Line, expr.Column)
		}
		return TypeVoid, false
	}

	// Return the field type
	if fieldType != nil {
		return getTypeFromAST(fieldType), true
	}

	// Fallback: return TypeVoid if we can't determine the field type
	return TypeVoid, true
}

// typecheckSubscriptExpr checks a subscript expression (array access)
func (tc *TypeChecker) typecheckSubscriptExpr(expr *parser.SubscriptExpr) (Type, bool) {
	if expr == nil {
		return TypeVoid, false
	}

	if expr.Array == nil || expr.Index == nil {
		filename := expr.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("数组访问表达式不完整 (%s:%d:%d)", filename, expr.Line, expr.Column)
		} else {
			tc.AddError("数组访问表达式不完整 (行 %d:%d)", expr.Line, expr.Column)
		}
		return TypeVoid, false
	}

	// Check array expression
	arrayType, ok := tc.typecheckExpression(expr.Array)
	if !ok {
		return TypeVoid, false
	}

	// Check index expression
	indexType, ok := tc.typecheckExpression(expr.Index)
	if !ok {
		return TypeVoid, false
	}

	// Check that index is an integer type
	if !isIntegerType(indexType) {
		filename := expr.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("数组索引必须是整数类型，但得到 %s (%s:%d:%d)",
				getTypeName(indexType), filename, expr.Line, expr.Column)
		} else {
			tc.AddError("数组索引必须是整数类型，但得到 %s (行 %d:%d)",
				getTypeName(indexType), expr.Line, expr.Column)
		}
		return TypeVoid, false
	}

	// Check that the array type is actually an array
	if arrayType != TypeArray {
		filename := expr.Filename
		if filename == "" {
			filename = tc.currentFile
		}
		if filename != "" {
			tc.AddError("数组访问只能用于数组类型，但得到 %s (%s:%d:%d)",
				getTypeName(arrayType), filename, expr.Line, expr.Column)
		} else {
			tc.AddError("数组访问只能用于数组类型，但得到 %s (行 %d:%d)",
				getTypeName(arrayType), expr.Line, expr.Column)
		}
		return TypeVoid, false
	}

	// Try to get array information from symbol table for bounds checking
	if ident, ok := expr.Array.(*parser.Identifier); ok {
		if sym := tc.LookupSymbol(ident.Name); sym != nil && sym.Type == TypeArray {
			// Check array bounds if we have array size information and index is a constant
			if sym.ArraySize >= 0 {
				// Check if index is a constant (NumberLiteral)
				if numberLit, isNumber := expr.Index.(*parser.NumberLiteral); isNumber {
					indexVal, err := strconv.ParseInt(numberLit.Value, 10, 64)
					if err == nil {
						if indexVal < 0 || indexVal >= int64(sym.ArraySize) {
							filename := expr.Filename
							if filename == "" {
								filename = tc.currentFile
							}
							if filename != "" {
								tc.AddError("数组索引越界：索引 %d 超出数组大小 %d (%s:%d:%d)",
									indexVal, sym.ArraySize, filename, expr.Line, expr.Column)
							} else {
								tc.AddError("数组索引越界：索引 %d 超出数组大小 %d (行 %d:%d)",
									indexVal, sym.ArraySize, expr.Line, expr.Column)
							}
							return TypeVoid, false
						}
					}
				}
			}

			// Return the array element type
			if sym.ArrayElementType != TypeVoid {
				return sym.ArrayElementType, true
			}
		}
	}

	// Fallback: return TypeVoid if we can't determine the element type
	// TODO: Improve type inference to track array element types
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

