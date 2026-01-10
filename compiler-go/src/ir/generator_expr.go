package ir

import (
	"fmt"

	"github.com/uya/compiler-go/src/lexer"
	"github.com/uya/compiler-go/src/parser"
)

// GenerateExpr 从表达式生成 IR
func (g *Generator) GenerateExpr(expr parser.Expr) Inst {
	if expr == nil {
		return nil
	}

	switch e := expr.(type) {
	case *parser.NumberLiteral:
		return g.generateNumberLiteral(e)
	case *parser.StringLiteral:
		return g.generateStringLiteral(e)
	case *parser.BoolLiteral:
		return g.generateBoolLiteral(e)
	case *parser.Identifier:
		return g.generateIdentifier(e)
	case *parser.BinaryExpr:
		return g.generateBinaryExpr(e)
	case *parser.UnaryExpr:
		return g.generateUnaryExpr(e)
	case *parser.CallExpr:
		return g.generateCallExpr(e)
	case *parser.MemberAccess:
		return g.generateMemberAccess(e)
	case *parser.SubscriptExpr:
		return g.generateSubscriptExpr(e)
	case *parser.StructInit:
		return g.generateStructInit(e)
	case *parser.TupleLiteral:
		return g.generateTupleLiteral(e)
	case *parser.CatchExpr:
		return g.generateCatchExpr(e)
	case *parser.MatchExpr:
		return g.generateMatchExpr(e)
	case *parser.StringInterpolation:
		return g.generateStringInterpolation(e)
	case *parser.NullLiteral:
		return g.generateNullLiteral(e)
	case *parser.ErrorExpr:
		return g.generateErrorExpr(e)
	default:
		// 未支持的表达式类型，返回nil
		return nil
	}
}

// generateNumberLiteral 生成数字字面量的IR
func (g *Generator) generateNumberLiteral(expr *parser.NumberLiteral) Inst {
	// 创建常量指令
	constInst := NewConstantInst(expr.Value, TypeI32) // 数字默认为i32类型
	return constInst
}

// generateStringLiteral 生成字符串字面量的IR
func (g *Generator) generateStringLiteral(expr *parser.StringLiteral) Inst {
	// 字符串字面量作为指针类型
	constInst := NewConstantInst(expr.Value, TypePtr)
	return constInst
}

// generateBoolLiteral 生成布尔字面量的IR
func (g *Generator) generateBoolLiteral(expr *parser.BoolLiteral) Inst {
	value := "false"
	if expr.Value {
		value = "true"
	}
	constInst := NewConstantInst(value, TypeBool)
	return constInst
}

// generateIdentifier 生成标识符的IR
func (g *Generator) generateIdentifier(expr *parser.Identifier) Inst {
	// 标识符引用现有变量，创建变量声明指令（不使用初始化）
	varInst := NewVarDeclInst(expr.Name, TypeI32, "", nil, false, false)
	return varInst
}

// tokenToIROp 将token类型转换为IR操作符
func tokenToIROp(tokenType lexer.TokenType) Op {
	switch tokenType {
	case lexer.TOKEN_PLUS:
		return OpAdd
	case lexer.TOKEN_MINUS:
		return OpSub
	case lexer.TOKEN_ASTERISK:
		return OpMul
	case lexer.TOKEN_SLASH:
		return OpDiv
	case lexer.TOKEN_PERCENT:
		return OpMod
	case lexer.TOKEN_EQUAL:
		return OpEq
	case lexer.TOKEN_NOT_EQUAL:
		return OpNe
	case lexer.TOKEN_LESS:
		return OpLt
	case lexer.TOKEN_LESS_EQUAL:
		return OpLe
	case lexer.TOKEN_GREATER:
		return OpGt
	case lexer.TOKEN_GREATER_EQUAL:
		return OpGe
	case lexer.TOKEN_AMPERSAND:
		return OpBitAnd
	case lexer.TOKEN_PIPE:
		return OpBitOr
	case lexer.TOKEN_CARET:
		return OpBitXor
	case lexer.TOKEN_LEFT_SHIFT:
		return OpLeftShift
	case lexer.TOKEN_RIGHT_SHIFT:
		return OpRightShift
	case lexer.TOKEN_LOGICAL_AND:
		return OpLogicAnd
	case lexer.TOKEN_LOGICAL_OR:
		return OpLogicOr
	default:
		return OpAdd // 默认值
	}
}

// tokenToUnaryIROp 将token类型转换为一元IR操作符
func tokenToUnaryIROp(tokenType lexer.TokenType) Op {
	switch tokenType {
	case lexer.TOKEN_AMPERSAND:
		return OpAddrOf
	case lexer.TOKEN_MINUS:
		return OpNeg
	case lexer.TOKEN_EXCLAMATION:
		return OpNot
	default:
		return OpAddrOf // 默认值
	}
}

// generateBinaryExpr 生成二元表达式的IR
func (g *Generator) generateBinaryExpr(expr *parser.BinaryExpr) Inst {
	// 生成左操作数和右操作数
	left := g.GenerateExpr(expr.Left)
	right := g.GenerateExpr(expr.Right)
	if left == nil || right == nil {
		return nil
	}

	// 转换操作符
	op := tokenToIROp(lexer.TokenType(expr.Op))

	// 生成临时变量名
	dest := fmt.Sprintf("temp_%d", g.NextID())

	// 创建二元运算指令
	binaryOp := NewBinaryOpInst(dest, op, left, right)
	return binaryOp
}

// generateUnaryExpr 生成一元表达式的IR
func (g *Generator) generateUnaryExpr(expr *parser.UnaryExpr) Inst {
	// 处理try表达式（特殊情况）
	if lexer.TokenType(expr.Op) == lexer.TOKEN_TRY {
		return g.generateTryExpr(expr)
	}

	// 生成操作数
	operand := g.GenerateExpr(expr.Operand)
	if operand == nil {
		return nil
	}

	// 转换操作符
	op := tokenToUnaryIROp(lexer.TokenType(expr.Op))

	// 生成临时变量名
	dest := fmt.Sprintf("temp_%d", g.NextID())

	// 创建一元运算指令
	unaryOp := NewUnaryOpInst(dest, op, operand)
	return unaryOp
}

// generateTryExpr 生成try表达式的IR
func (g *Generator) generateTryExpr(expr *parser.UnaryExpr) Inst {
	// TODO: 实现try表达式的IR生成
	// 目前返回操作数的IR（占位符）
	return g.GenerateExpr(expr.Operand)
}

// generateCallExpr 生成函数调用的IR
func (g *Generator) generateCallExpr(expr *parser.CallExpr) Inst {
	// 获取函数名
	funcName := "unknown"
	if ident, ok := expr.Callee.(*parser.Identifier); ok {
		funcName = ident.Name
	} else if memberAccess, ok := expr.Callee.(*parser.MemberAccess); ok {
		// 方法调用：使用字段名作为函数名
		funcName = memberAccess.FieldName
	}

	// 生成参数列表
	args := make([]Inst, 0, len(expr.Args))
	for _, arg := range expr.Args {
		argInst := g.GenerateExpr(arg)
		if argInst == nil {
			return nil
		}
		args = append(args, argInst)
	}

	// 如果是方法调用，将对象作为第一个参数
	if memberAccess, ok := expr.Callee.(*parser.MemberAccess); ok {
		objectInst := g.GenerateExpr(memberAccess.Object)
		if objectInst == nil {
			return nil
		}
		// 将对象参数插入到参数列表的开头
		args = append([]Inst{objectInst}, args...)
	}

	// 创建函数调用指令（dest为空，表示可能是void函数）
	callInst := NewCallInst("", funcName, args)
	return callInst
}

// generateMemberAccess 生成成员访问的IR
func (g *Generator) generateMemberAccess(expr *parser.MemberAccess) Inst {
	// 检查是否是error.ErrorName（错误命名空间访问）
	if ident, ok := expr.Object.(*parser.Identifier); ok && ident.Name == "error" {
		// 创建错误值指令
		dest := fmt.Sprintf("temp_%d", g.NextID())
		errorValueInst := NewErrorValueInst(dest, expr.FieldName)
		return errorValueInst
	}

	// 常规成员访问：obj.field
	objectInst := g.GenerateExpr(expr.Object)
	if objectInst == nil {
		return nil
	}

	dest := fmt.Sprintf("temp_%d", g.NextID())
	memberAccessInst := NewMemberAccessInst(dest, objectInst, expr.FieldName)
	return memberAccessInst
}

// generateSubscriptExpr 生成数组下标访问的IR
func (g *Generator) generateSubscriptExpr(expr *parser.SubscriptExpr) Inst {
	// 生成数组和索引表达式
	arrayInst := g.GenerateExpr(expr.Array)
	indexInst := g.GenerateExpr(expr.Index)
	if arrayInst == nil || indexInst == nil {
		return nil
	}

	dest := fmt.Sprintf("temp_%d", g.NextID())
	subscriptInst := NewSubscriptInst(dest, arrayInst, indexInst)
	return subscriptInst
}

// generateStructInit 生成结构体初始化的IR
func (g *Generator) generateStructInit(expr *parser.StructInit) Inst {
	// 生成字段初始化表达式列表
	fieldInits := make([]Inst, 0, len(expr.FieldInits))
	for _, fieldInit := range expr.FieldInits {
		fieldInst := g.GenerateExpr(fieldInit)
		if fieldInst == nil {
			return nil
		}
		fieldInits = append(fieldInits, fieldInst)
	}

	dest := fmt.Sprintf("temp_%d", g.NextID())
	structInitInst := NewStructInitInst(dest, expr.StructName, fieldInits, expr.FieldNames)
	return structInitInst
}

// generateTupleLiteral 生成元组字面量的IR
func (g *Generator) generateTupleLiteral(expr *parser.TupleLiteral) Inst {
	// 元组字面量可以表示为结构体初始化
	// 生成所有元素的IR
	fieldInits := make([]Inst, 0, len(expr.Elements))
	fieldNames := make([]string, 0, len(expr.Elements))
	for i, element := range expr.Elements {
		elementInst := g.GenerateExpr(element)
		if elementInst == nil {
			return nil
		}
		fieldInits = append(fieldInits, elementInst)
		fieldNames = append(fieldNames, fmt.Sprintf("%d", i)) // 使用索引作为字段名
	}

	dest := fmt.Sprintf("temp_%d", g.NextID())
	// 使用空结构体名称表示元组
	structInitInst := NewStructInitInst(dest, "", fieldInits, fieldNames)
	return structInitInst
}

// generateCatchExpr 生成catch表达式的IR
func (g *Generator) generateCatchExpr(expr *parser.CatchExpr) Inst {
	// 生成try表达式
	tryInst := g.GenerateExpr(expr.Expr)
	if tryInst == nil {
		return nil
	}

	// 生成catch块指令列表
	var catchBody []Inst
	if expr.CatchBody != nil {
		catchBody = make([]Inst, 0, len(expr.CatchBody.Stmts))
		for _, stmt := range expr.CatchBody.Stmts {
			stmtInst := g.GenerateStmt(stmt)
			if stmtInst != nil {
				catchBody = append(catchBody, stmtInst)
			}
		}
	}

	dest := fmt.Sprintf("temp_%d", g.NextID())
	tryCatchInst := NewTryCatchInst(dest, tryInst, expr.ErrorVar, catchBody)
	return tryCatchInst
}

// generateMatchExpr 生成match表达式的IR
func (g *Generator) generateMatchExpr(expr *parser.MatchExpr) Inst {
	// TODO: 实现match表达式的IR生成
	// 目前返回nil（占位符）
	return nil
}

// generateStringInterpolation 生成字符串插值的IR
func (g *Generator) generateStringInterpolation(expr *parser.StringInterpolation) Inst {
	// 生成插值表达式列表
	interpExprs := make([]Inst, 0, len(expr.InterpExprs))
	for _, interpExpr := range expr.InterpExprs {
		exprInst := g.GenerateExpr(interpExpr)
		if exprInst == nil {
			return nil
		}
		interpExprs = append(interpExprs, exprInst)
	}

	dest := fmt.Sprintf("temp_%d", g.NextID())
	stringInterpInst := NewStringInterpolationInst(dest, expr.TextSegments, interpExprs)
	return stringInterpInst
}

// generateNullLiteral 生成null字面量的IR
func (g *Generator) generateNullLiteral(expr *parser.NullLiteral) Inst {
	// null字面量作为空指针常量（0）
	constInst := NewConstantInst("0", TypePtr)
	return constInst
}

// generateErrorExpr 生成错误表达式的IR
func (g *Generator) generateErrorExpr(expr *parser.ErrorExpr) Inst {
	// 错误表达式直接创建错误值指令
	dest := fmt.Sprintf("temp_%d", g.NextID())
	errorValueInst := NewErrorValueInst(dest, expr.ErrorName)
	return errorValueInst
}

