package checker

import (
	"github.com/uya/compiler-go/src/lexer"
	"github.com/uya/compiler-go/src/parser"
)

// typecheckBlock checks a block statement
func (tc *TypeChecker) typecheckBlock(block *parser.Block) bool {
	if block == nil {
		return true
	}

	// Enter block scope
	tc.EnterScope()

	// Check all statements in the block
	for _, stmt := range block.Stmts {
		if !tc.typecheckNode(stmt) {
			tc.ExitScope()
			return false
		}
	}

	// Exit block scope
	tc.ExitScope()

	return true
}

// typecheckIfStmt checks an if statement
func (tc *TypeChecker) typecheckIfStmt(stmt *parser.IfStmt) bool {
	if stmt == nil {
		return false
	}

	// Check condition expression
	condType, ok := tc.typecheckExpression(stmt.Condition)
	if !ok {
		return false
	}

	// Condition should be boolean type (simplified - full implementation would handle type coercion)
	if condType != TypeBool {
		tc.AddError("if语句的条件表达式必须是bool类型 (行 %d:%d)",
			stmt.Line, stmt.Column)
		return false
	}

	// Check then branch
	if stmt.ThenBranch != nil {
		if !tc.typecheckNode(stmt.ThenBranch) {
			return false
		}
	}

	// Check else branch
	if stmt.ElseBranch != nil {
		if !tc.typecheckNode(stmt.ElseBranch) {
			return false
		}
	}

	return true
}

// typecheckWhileStmt checks a while statement
func (tc *TypeChecker) typecheckWhileStmt(stmt *parser.WhileStmt) bool {
	if stmt == nil {
		return false
	}

	// Check condition expression
	condType, ok := tc.typecheckExpression(stmt.Condition)
	if !ok {
		return false
	}

	// Condition should be boolean type
	if condType != TypeBool {
		tc.AddError("while语句的条件表达式必须是bool类型 (行 %d:%d)",
			stmt.Line, stmt.Column)
		return false
	}

	// Check body
	// Note: Loop body should not enter a new scope, so variables modified in the loop
	// can be recognized outside the loop
	if stmt.Body != nil {
		// Check body statements directly (typecheckBlock will handle scope)
		if !tc.typecheckBlock(stmt.Body) {
			return false
		}
	}

	return true
}

// typecheckForStmt checks a for statement
func (tc *TypeChecker) typecheckForStmt(stmt *parser.ForStmt) bool {
	if stmt == nil {
		return false
	}

	// Enter loop scope
	tc.EnterScope()

	// Check iterable expression
	if stmt.Iterable != nil {
		_, ok := tc.typecheckExpression(stmt.Iterable)
		if !ok {
			tc.ExitScope()
			return false
		}
	}

	// Check index range expression (if present)
	if stmt.IndexRange != nil {
		_, ok := tc.typecheckExpression(stmt.IndexRange)
		if !ok {
			tc.ExitScope()
			return false
		}
	}

	// Add loop variables to scope (if present)
	if stmt.ItemVar != "" {
		// TODO: Determine the item type from iterable
		itemSymbol := &Symbol{
			Name:          stmt.ItemVar,
			Type:          TypeVoid, // TODO: Infer from iterable type
			IsMut:         false,
			IsConst:       false,
			IsInitialized: true,
			ScopeLevel:    tc.CurrentScope(),
			Line:          stmt.Line,
			Column:        stmt.Column,
			Filename:      stmt.Filename,
		}
		if !tc.AddSymbol(itemSymbol) {
			tc.ExitScope()
			return false
		}
	}

	if stmt.IndexVar != "" {
		indexSymbol := &Symbol{
			Name:          stmt.IndexVar,
			Type:          TypeI32, // Index is typically i32
			IsMut:         false,
			IsConst:       false,
			IsInitialized: true,
			ScopeLevel:    tc.CurrentScope(),
			Line:          stmt.Line,
			Column:        stmt.Column,
			Filename:      stmt.Filename,
		}
		if !tc.AddSymbol(indexSymbol) {
			tc.ExitScope()
			return false
		}
	}

	// Check body
	if stmt.Body != nil {
		if !tc.typecheckBlock(stmt.Body) {
			tc.ExitScope()
			return false
		}
	}

	// Exit loop scope
	tc.ExitScope()

	return true
}

// typecheckReturnStmt checks a return statement
func (tc *TypeChecker) typecheckReturnStmt(stmt *parser.ReturnStmt) bool {
	if stmt == nil {
		return false
	}

	// TODO: Check return type matches function's return type
	// This requires tracking the current function context

	if stmt.Expr != nil {
		// Check return expression
		_, ok := tc.typecheckExpression(stmt.Expr)
		if !ok {
			return false
		}
	}

	return true
}

// typecheckAssign checks an assignment statement
func (tc *TypeChecker) typecheckAssign(assign *parser.AssignStmt) bool {
	if assign == nil {
		return false
	}

	// Check source expression
	srcType, ok := tc.typecheckExpression(assign.Src)
	if !ok {
		return false
	}

	// Check destination
	if assign.DestExpr != nil {
		// Destination is an expression (e.g., arr[0])
		// Check the destination expression
		destType, ok := tc.typecheckExpression(assign.DestExpr)
		if !ok {
			return false
		}

		// Type matching (simplified)
		if !typeMatch(destType, srcType) {
			tc.AddError("赋值类型不匹配 (行 %d:%d)",
				assign.Line, assign.Column)
			return false
		}
	} else if assign.Dest != "" {
		// Destination is a simple variable name
		symbol := tc.LookupSymbol(assign.Dest)
		if symbol == nil {
			filename := assign.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("未定义的变量 '%s' (%s:%d:%d)",
					assign.Dest, filename, assign.Line, assign.Column)
			} else {
				tc.AddError("未定义的变量 '%s' (行 %d:%d)",
					assign.Dest, assign.Line, assign.Column)
			}
			return false
		}

		// Check if variable is const
		if symbol.IsConst {
			filename := assign.Filename
			if filename == "" {
				filename = tc.currentFile
			}
			if filename != "" {
				tc.AddError("不能对const变量 '%s' 赋值 (%s:%d:%d)",
					assign.Dest, filename, assign.Line, assign.Column)
			} else {
				tc.AddError("不能对const变量 '%s' 赋值 (行 %d:%d)",
					assign.Dest, assign.Line, assign.Column)
			}
			return false
		}

		// Type matching
		if !typeMatch(symbol.Type, srcType) {
			tc.AddError("变量 '%s' 的赋值类型不匹配 (行 %d:%d)",
				assign.Dest, assign.Line, assign.Column)
			return false
		}

		// Mark variable as initialized and modified
		symbol.IsInitialized = true
		symbol.IsModified = true
	}

	return true
}

// typecheckDeferStmt checks a defer statement
func (tc *TypeChecker) typecheckDeferStmt(stmt *parser.DeferStmt) bool {
	if stmt == nil {
		return false
	}

	// Check the defer body
	if stmt.Body != nil {
		if !tc.typecheckBlock(stmt.Body) {
			return false
		}
	}

	return true
}

// typecheckErrDeferStmt checks an errdefer statement
func (tc *TypeChecker) typecheckErrDeferStmt(stmt *parser.ErrDeferStmt) bool {
	if stmt == nil {
		return false
	}

	// Check the errdefer body
	if stmt.Body != nil {
		if !tc.typecheckBlock(stmt.Body) {
			return false
		}
	}

	return true
}

