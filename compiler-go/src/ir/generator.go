package ir

import (
	"github.com/uya/compiler-go/src/parser"
)

// GenerateProgram 从程序节点生成 IR
func (g *Generator) GenerateProgram(program *parser.Program) {
	if program == nil {
		return
	}

	// 生成所有声明
		for _, decl := range program.Decls {
		switch d := decl.(type) {
		case *parser.FuncDecl:
			g.GenerateFunction(d)
		case *parser.TestBlock:
			// TODO: 实现测试块生成
			// generateTestBlock(g, d)
		case *parser.ImplDecl:
			// TODO: 实现 impl 声明生成
			// 对于 impl 声明，将每个方法转换为常规函数
		default:
			// 其他声明类型暂时跳过
		}
	}
}

// GenerateFunction 从函数声明生成 IR
// 实现在 generator_func.go 中

// GenerateExpr 从表达式生成 IR
// 实现在 generator_expr.go 中

// GenerateStmt 从语句生成 IR
// 实现在 generator_stmt.go 中

