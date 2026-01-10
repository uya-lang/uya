package checker

import (
	"github.com/uya/compiler-go/src/parser"
)

// typecheckNode checks a single AST node and returns true if successful
// This is the main dispatch function that routes to specific type checking functions
func (tc *TypeChecker) typecheckNode(node parser.Node) bool {
	if node == nil {
		return true // Empty node is considered valid
	}

	// Update current context from node
	base := node.Base()
	tc.currentLine = base.Line
	tc.currentColumn = base.Column
	tc.currentFile = base.Filename

	// Dispatch based on node type
	switch node.Type() {
	case parser.AST_PROGRAM:
		return tc.typecheckProgram(node.(*parser.Program))

	case parser.AST_VAR_DECL:
		return tc.typecheckVarDecl(node.(*parser.VarDecl))

	case parser.AST_FN_DECL:
		return tc.typecheckFuncDecl(node.(*parser.FuncDecl))

	case parser.AST_STRUCT_DECL:
		// Struct declarations are mostly checked during use
		return true

	case parser.AST_ENUM_DECL:
		// Enum declarations are mostly checked during use
		return true

	case parser.AST_ERROR_DECL:
		// Error declarations are mostly checked during use
		return true

	case parser.AST_EXTERN_DECL:
		return tc.typecheckExternDecl(node.(*parser.ExternDecl))

	case parser.AST_INTERFACE_DECL:
		// Interface declarations are mostly checked during use
		return true

	case parser.AST_TEST_BLOCK:
		// Test blocks are checked like regular blocks
		return true // TODO: Implement test block checking

	case parser.AST_BLOCK:
		return tc.typecheckBlock(node.(*parser.Block))

	case parser.AST_IF_STMT:
		return tc.typecheckIfStmt(node.(*parser.IfStmt))

	case parser.AST_WHILE_STMT:
		return tc.typecheckWhileStmt(node.(*parser.WhileStmt))

	case parser.AST_FOR_STMT:
		return tc.typecheckForStmt(node.(*parser.ForStmt))

	case parser.AST_RETURN_STMT:
		return tc.typecheckReturnStmt(node.(*parser.ReturnStmt))

	case parser.AST_EXPR_STMT:
		exprStmt := node.(*parser.ExprStmt)
		// Check the expression
		_, ok := tc.typecheckExpression(exprStmt.Expr)
		return ok

	case parser.AST_BREAK_STMT, parser.AST_CONTINUE_STMT:
		// Break and continue statements are valid in loops
		return true

	case parser.AST_DEFER_STMT:
		return tc.typecheckDeferStmt(node.(*parser.DeferStmt))

	case parser.AST_ERRDEFER_STMT:
		return tc.typecheckErrDeferStmt(node.(*parser.ErrDeferStmt))

	case parser.AST_ASSIGN:
		return tc.typecheckAssign(node.(*parser.AssignStmt))

	// Expression types - these will be handled by typecheckExpression
	case parser.AST_BINARY_EXPR:
		expr := node.(*parser.BinaryExpr)
		_, ok := tc.typecheckExpression(expr)
		return ok

	case parser.AST_UNARY_EXPR:
		expr := node.(*parser.UnaryExpr)
		_, ok := tc.typecheckExpression(expr)
		return ok

	case parser.AST_CALL_EXPR:
		expr := node.(*parser.CallExpr)
		_, ok := tc.typecheckExpression(expr)
		return ok

	case parser.AST_IDENTIFIER:
		expr := node.(*parser.Identifier)
		_, ok := tc.typecheckExpression(expr)
		return ok

	case parser.AST_NUMBER, parser.AST_STRING, parser.AST_BOOL, parser.AST_NULL:
		// Literals are always valid
		return true

	case parser.AST_MEMBER_ACCESS:
		expr := node.(*parser.MemberAccess)
		_, ok := tc.typecheckExpression(expr)
		return ok

	case parser.AST_SUBSCRIPT_EXPR:
		expr := node.(*parser.SubscriptExpr)
		_, ok := tc.typecheckExpression(expr)
		return ok

	case parser.AST_CATCH_EXPR:
		expr := node.(*parser.CatchExpr)
		_, ok := tc.typecheckExpression(expr)
		return ok

	case parser.AST_MATCH_EXPR:
		expr := node.(*parser.MatchExpr)
		_, ok := tc.typecheckExpression(expr)
		return ok

	case parser.AST_STRING_INTERPOLATION:
		// String interpolation is checked during expression checking
		return true

	case parser.AST_TUPLE_LITERAL:
		// Tuple literals are checked during expression checking
		return true

	default:
		// Unknown node type - log warning but don't fail
		tc.AddError("未知的节点类型 %d at %s:%d:%d",
			node.Type(), tc.currentFile, tc.currentLine, tc.currentColumn)
		return false
	}
}

// typecheckProgram checks a program node
func (tc *TypeChecker) typecheckProgram(program *parser.Program) bool {
	// Check all declarations
	for _, decl := range program.Decls {
		if !tc.typecheckNode(decl) {
			return false
		}
	}
	return true
}

// Declaration checking functions are implemented in checker_decl.go

// Statement checking functions are implemented in checker_stmt.go

// Expression checking function is implemented in checker_expr.go

