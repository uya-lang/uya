package ir

import (
	"fmt"

	"github.com/uya/compiler-go/src/parser"
)

// GenerateStmt 从语句生成 IR
func (g *Generator) GenerateStmt(stmt parser.Stmt) Inst {
	if stmt == nil {
		return nil
	}

	switch s := stmt.(type) {
	case *parser.Block:
		return g.generateBlock(s)
	case *parser.VarDecl:
		return g.generateVarDecl(s)
	case *parser.ReturnStmt:
		return g.generateReturnStmt(s)
	case *parser.IfStmt:
		return g.generateIfStmt(s)
	case *parser.WhileStmt:
		return g.generateWhileStmt(s)
	case *parser.ForStmt:
		return g.generateForStmt(s)
	case *parser.AssignStmt:
		return g.generateAssignStmt(s)
	case *parser.DeferStmt:
		return g.generateDeferStmt(s)
	case *parser.ErrDeferStmt:
		return g.generateErrDeferStmt(s)
	case *parser.BreakStmt:
		return g.generateBreakStmt(s)
	case *parser.ContinueStmt:
		return g.generateContinueStmt(s)
	case *parser.ExprStmt:
		return g.generateExprStmt(s)
	default:
		// 对于表达式语句（如函数调用），将其转换为表达式生成
		if expr, ok := stmt.(parser.Expr); ok {
			return g.GenerateExpr(expr)
		}
		return nil
	}
}

// generateBlock 生成代码块的IR
func (g *Generator) generateBlock(block *parser.Block) Inst {
	insts := make([]Inst, 0, len(block.Stmts))
	for _, stmt := range block.Stmts {
		inst := g.GenerateStmt(stmt)
		if inst != nil {
			insts = append(insts, inst)
		}
	}
	return NewBlockInst(insts)
}

// generateVarDecl 生成变量声明的IR
func (g *Generator) generateVarDecl(stmt *parser.VarDecl) Inst {
	// 获取变量类型
	var varType Type
	if stmt.VarType != nil {
		if typeNode, ok := stmt.VarType.(parser.Type); ok {
			varType = GetIRType(typeNode)
		} else {
			varType = TypeI32
		}
	} else {
		varType = TypeI32
	}
	
	// 获取原始类型名称（用于用户定义类型）
	originalTypeName := ""
	if stmt.VarType != nil {
		if namedType, ok := stmt.VarType.(*parser.NamedType); ok {
			// 检查是否是内置类型
			builtinTypes := map[string]bool{
				"i8": true, "i16": true, "i32": true, "i64": true,
				"u8": true, "u16": true, "u32": true, "u64": true,
				"f32": true, "f64": true,
				"bool": true, "void": true, "byte": true,
			}
			if !builtinTypes[namedType.Name] {
				originalTypeName = namedType.Name
			}
		}
	}

	// 生成初始化表达式
	var initInst Inst
	if stmt.Init != nil {
		initInst = g.GenerateExpr(stmt.Init)
	}

	// 检查是否是原子类型
	isAtomic := false
	if stmt.VarType != nil {
		if _, ok := stmt.VarType.(*parser.AtomicType); ok {
			isAtomic = true
		}
	}

	varInst := NewVarDeclInst(stmt.Name, varType, originalTypeName, initInst, stmt.IsMut, isAtomic)
	return varInst
}

// generateReturnStmt 生成返回语句的IR
func (g *Generator) generateReturnStmt(stmt *parser.ReturnStmt) Inst {
	var valueInst Inst
	if stmt.Expr != nil {
		valueInst = g.GenerateExpr(stmt.Expr)
	}
	return NewReturnInst(valueInst)
}

// generateIfStmt 生成if语句的IR
func (g *Generator) generateIfStmt(stmt *parser.IfStmt) Inst {
	// 生成条件表达式
	condition := g.GenerateExpr(stmt.Condition)
	if condition == nil {
		return nil
	}

	// 生成then分支
	var thenBody []Inst
	if stmt.ThenBranch != nil {
		if block, ok := stmt.ThenBranch.(*parser.Block); ok {
			thenBody = make([]Inst, 0, len(block.Stmts))
			for _, s := range block.Stmts {
				inst := g.GenerateStmt(s)
				if inst != nil {
					thenBody = append(thenBody, inst)
				}
			}
		} else {
			inst := g.GenerateStmt(stmt.ThenBranch)
			if inst != nil {
				thenBody = []Inst{inst}
			}
		}
	}

	// 生成else分支
	var elseBody []Inst
	if stmt.ElseBranch != nil {
		if block, ok := stmt.ElseBranch.(*parser.Block); ok {
			elseBody = make([]Inst, 0, len(block.Stmts))
			for _, s := range block.Stmts {
				inst := g.GenerateStmt(s)
				if inst != nil {
					elseBody = append(elseBody, inst)
				}
			}
		} else if ifStmt, ok := stmt.ElseBranch.(*parser.IfStmt); ok {
			// else-if链：递归生成
			elseInst := g.generateIfStmt(ifStmt)
			if elseInst != nil {
				elseBody = []Inst{elseInst}
			}
		} else {
			inst := g.GenerateStmt(stmt.ElseBranch)
			if inst != nil {
				elseBody = []Inst{inst}
			}
		}
	}

	return NewIfInst(condition, thenBody, elseBody)
}

// generateWhileStmt 生成while语句的IR
func (g *Generator) generateWhileStmt(stmt *parser.WhileStmt) Inst {
	// 生成条件表达式
	condition := g.GenerateExpr(stmt.Condition)
	if condition == nil {
		return nil
	}

	// 生成循环体
	var body []Inst
	if stmt.Body != nil {
		body = make([]Inst, 0, len(stmt.Body.Stmts))
		for _, s := range stmt.Body.Stmts {
			inst := g.GenerateStmt(s)
			if inst != nil {
				body = append(body, inst)
			}
		}
	}

	return NewWhileInst(condition, body)
}

// generateForStmt 生成for语句的IR
func (g *Generator) generateForStmt(stmt *parser.ForStmt) Inst {
	// 生成可迭代对象表达式
	iterable := g.GenerateExpr(stmt.Iterable)
	if iterable == nil {
		return nil
	}

	// 生成索引范围表达式（如果有）
	var indexRange Inst
	if stmt.IndexRange != nil {
		indexRange = g.GenerateExpr(stmt.IndexRange)
	}

	// 生成循环体
	var body []Inst
	if stmt.Body != nil {
		body = make([]Inst, 0, len(stmt.Body.Stmts))
		for _, s := range stmt.Body.Stmts {
			inst := g.GenerateStmt(s)
			if inst != nil {
				body = append(body, inst)
			}
		}
	}

	return NewForInst(iterable, indexRange, stmt.ItemVar, stmt.IndexVar, body)
}

// generateAssignStmt 生成赋值语句的IR
func (g *Generator) generateAssignStmt(stmt *parser.AssignStmt) Inst {
	// 生成源表达式
	src := g.GenerateExpr(stmt.Src)
	if src == nil {
		return nil
	}

	// 检查目标是否是表达式（如arr[0]）还是简单变量
	var destExpr Inst
	dest := stmt.Dest
	if stmt.DestExpr != nil {
		destExpr = g.GenerateExpr(stmt.DestExpr)
		dest = "" // 使用表达式时，dest为空
	}

	return NewAssignInst(dest, destExpr, src)
}

// generateDeferStmt 生成defer语句的IR
func (g *Generator) generateDeferStmt(stmt *parser.DeferStmt) Inst {
	var body []Inst
	if stmt.Body != nil {
		body = make([]Inst, 0, len(stmt.Body.Stmts))
		for _, s := range stmt.Body.Stmts {
			inst := g.GenerateStmt(s)
			if inst != nil {
				body = append(body, inst)
			}
		}
	}
	return NewDeferInst(body)
}

// generateErrDeferStmt 生成errdefer语句的IR
func (g *Generator) generateErrDeferStmt(stmt *parser.ErrDeferStmt) Inst {
	var body []Inst
	if stmt.Body != nil {
		body = make([]Inst, 0, len(stmt.Body.Stmts))
		for _, s := range stmt.Body.Stmts {
			inst := g.GenerateStmt(s)
			if inst != nil {
				body = append(body, inst)
			}
		}
	}
	return NewErrDeferInst(body)
}

// generateBreakStmt 生成break语句的IR
func (g *Generator) generateBreakStmt(stmt *parser.BreakStmt) Inst {
	// break语句使用goto跳转到循环结束标签
	// 这里使用简化实现：生成goto指令，标签名由codegen模块处理
	// TODO: 完整实现需要跟踪当前循环的break标签
	breakLabel := fmt.Sprintf("break_label_%d", g.NextID())
	gotoInst := NewGotoInst(breakLabel)
	return gotoInst
}

// generateContinueStmt 生成continue语句的IR
func (g *Generator) generateContinueStmt(stmt *parser.ContinueStmt) Inst {
	// continue语句使用goto跳转到循环开始标签
	// 这里使用简化实现：生成goto指令，标签名由codegen模块处理
	// TODO: 完整实现需要跟踪当前循环的continue标签
	continueLabel := fmt.Sprintf("continue_label_%d", g.NextID())
	gotoInst := NewGotoInst(continueLabel)
	return gotoInst
}

// generateExprStmt 生成表达式语句的IR
func (g *Generator) generateExprStmt(stmt *parser.ExprStmt) Inst {
	// 表达式语句直接转换为表达式IR
	return g.GenerateExpr(stmt.Expr)
}

