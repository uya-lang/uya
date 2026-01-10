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
func tokenToIROp(tokenType int) Op {
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
func tokenToUnaryIROp(tokenType int) Op {
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
	op := tokenToIROp(expr.Op)

	// 生成临时变量名
	dest := fmt.Sprintf("temp_%d", g.NextID())

	// 创建二元运算指令
	binaryOp := NewBinaryOpInst(dest, op, left, right)
	return binaryOp
}

// generateUnaryExpr 生成一元表达式的IR
func (g *Generator) generateUnaryExpr(expr *parser.UnaryExpr) Inst {
	// 处理try表达式（特殊情况）
	if expr.Op == lexer.TOKEN_TRY {
		return g.generateTryExpr(expr)
	}

	// 生成操作数
	operand := g.GenerateExpr(expr.Operand)
	if operand == nil {
		return nil
	}

	// 转换操作符
	op := tokenToUnaryIROp(expr.Op)

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
		// TODO: 实现错误值指令（IR_ERROR_VALUE）
		// 目前返回nil（占位符）
		return nil
	}

	// TODO: 实现常规成员访问的IR生成
	// 目前返回nil（占位符）
	return nil
}

// generateSubscriptExpr 生成数组下标访问的IR
func (g *Generator) generateSubscriptExpr(expr *parser.SubscriptExpr) Inst {
	// TODO: 实现数组下标访问的IR生成
	// 目前返回nil（占位符）
	return nil
}

// generateStructInit 生成结构体初始化的IR
func (g *Generator) generateStructInit(expr *parser.StructInit) Inst {
	// TODO: 实现结构体初始化的IR生成
	// 目前返回nil（占位符）
	return nil
}

// generateTupleLiteral 生成元组字面量的IR
func (g *Generator) generateTupleLiteral(expr *parser.TupleLiteral) Inst {
	// TODO: 实现元组字面量的IR生成
	// 目前返回nil（占位符）
	return nil
}

// generateCatchExpr 生成catch表达式的IR
func (g *Generator) generateCatchExpr(expr *parser.CatchExpr) Inst {
	// TODO: 实现catch表达式的IR生成
	// 目前返回nil（占位符）
	return nil
}

// generateMatchExpr 生成match表达式的IR
func (g *Generator) generateMatchExpr(expr *parser.MatchExpr) Inst {
	// TODO: 实现match表达式的IR生成
	// 目前返回nil（占位符）
	return nil
}

// generateStringInterpolation 生成字符串插值的IR
func (g *Generator) generateStringInterpolation(expr *parser.StringInterpolation) Inst {
	// TODO: 实现字符串插值的IR生成
	// 目前返回nil（占位符）
	return nil
}

// generateNullLiteral 生成null字面量的IR
func (g *Generator) generateNullLiteral(expr *parser.NullLiteral) Inst {
	// TODO: 实现null字面量的IR生成
	// 目前返回nil（占位符）
	return nil
}

// generateErrorExpr 生成错误表达式的IR
func (g *Generator) generateErrorExpr(expr *parser.ErrorExpr) Inst {
	// TODO: 实现错误表达式的IR生成
	// 目前返回nil（占位符）
	return nil
}

