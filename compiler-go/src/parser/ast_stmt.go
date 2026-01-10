package parser

// Stmt is the interface for statement nodes
type Stmt interface {
	Node
	isStmt()
}

// IfStmt represents an if statement
type IfStmt struct {
	NodeBase
	Condition Expr
	ThenBranch Stmt
	ElseBranch Stmt // May be nil
}

func (n *IfStmt) Type() NodeType { return AST_IF_STMT }
func (n *IfStmt) Base() *NodeBase { return &n.NodeBase }
func (n *IfStmt) isStmt() {}

// WhileStmt represents a while statement
type WhileStmt struct {
	NodeBase
	Condition Expr
	Body      *Block
}

func (n *WhileStmt) Type() NodeType { return AST_WHILE_STMT }
func (n *WhileStmt) Base() *NodeBase { return &n.NodeBase }
func (n *WhileStmt) isStmt() {}

// ForStmt represents a for statement
type ForStmt struct {
	NodeBase
	Iterable  Expr
	IndexRange Expr // May be nil for basic form
	ItemVar   string
	IndexVar  string // May be empty for basic form
	Body      *Block
}

func (n *ForStmt) Type() NodeType { return AST_FOR_STMT }
func (n *ForStmt) Base() *NodeBase { return &n.NodeBase }
func (n *ForStmt) isStmt() {}

// ReturnStmt represents a return statement
type ReturnStmt struct {
	NodeBase
	Expr Expr // May be nil for void return
}

func (n *ReturnStmt) Type() NodeType { return AST_RETURN_STMT }
func (n *ReturnStmt) Base() *NodeBase { return &n.NodeBase }
func (n *ReturnStmt) isStmt() {}

// AssignStmt represents an assignment statement
type AssignStmt struct {
	NodeBase
	Dest     string // Simple variable name (for backward compatibility)
	DestExpr Expr   // Destination expression (supports arr[0] etc.)
	Src      Expr
}

func (n *AssignStmt) Type() NodeType { return AST_ASSIGN }
func (n *AssignStmt) Base() *NodeBase { return &n.NodeBase }
func (n *AssignStmt) isStmt() {}

// Block represents a code block
type Block struct {
	NodeBase
	Stmts []Stmt
}

func (n *Block) Type() NodeType { return AST_BLOCK }
func (n *Block) Base() *NodeBase { return &n.NodeBase }
func (n *Block) isStmt() {}

// BreakStmt represents a break statement
type BreakStmt struct {
	NodeBase
}

func (n *BreakStmt) Type() NodeType { return AST_BREAK_STMT }
func (n *BreakStmt) Base() *NodeBase { return &n.NodeBase }
func (n *BreakStmt) isStmt() {}

// ContinueStmt represents a continue statement
type ContinueStmt struct {
	NodeBase
}

func (n *ContinueStmt) Type() NodeType { return AST_CONTINUE_STMT }
func (n *ContinueStmt) Base() *NodeBase { return &n.NodeBase }
func (n *ContinueStmt) isStmt() {}

// DeferStmt represents a defer statement
type DeferStmt struct {
	NodeBase
	Body *Block
}

func (n *DeferStmt) Type() NodeType { return AST_DEFER_STMT }
func (n *DeferStmt) Base() *NodeBase { return &n.NodeBase }
func (n *DeferStmt) isStmt() {}

// ErrDeferStmt represents an errdefer statement
type ErrDeferStmt struct {
	NodeBase
	Body *Block
}

func (n *ErrDeferStmt) Type() NodeType { return AST_ERRDEFER_STMT }
func (n *ErrDeferStmt) Base() *NodeBase { return &n.NodeBase }
func (n *ErrDeferStmt) isStmt() {}

// ExprStmt represents an expression statement
type ExprStmt struct {
	NodeBase
	Expr Expr
}

func (n *ExprStmt) Type() NodeType { return AST_EXPR_STMT }
func (n *ExprStmt) Base() *NodeBase { return &n.NodeBase }
func (n *ExprStmt) isStmt() {}

// TestBlock represents a test block
type TestBlock struct {
	NodeBase
	Name string
	Body *Block
}

func (n *TestBlock) Type() NodeType { return AST_TEST_BLOCK }
func (n *TestBlock) Base() *NodeBase { return &n.NodeBase }
func (n *TestBlock) isStmt() {}

