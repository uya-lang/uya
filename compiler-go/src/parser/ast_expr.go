package parser

// Expr is the interface for expression nodes
type Expr interface {
	Node
	isExpr()
}

// BinaryExpr represents a binary expression
type BinaryExpr struct {
	NodeBase
	Left  Expr
	Op    int // Token type
	Right Expr
}

func (n *BinaryExpr) Type() NodeType { return AST_BINARY_EXPR }
func (n *BinaryExpr) Base() *NodeBase { return &n.NodeBase }
func (n *BinaryExpr) isExpr() {}

// UnaryExpr represents a unary expression
type UnaryExpr struct {
	NodeBase
	Op      int // Token type
	Operand Expr
}

func (n *UnaryExpr) Type() NodeType { return AST_UNARY_EXPR }
func (n *UnaryExpr) Base() *NodeBase { return &n.NodeBase }
func (n *UnaryExpr) isExpr() {}

// CallExpr represents a function call expression
type CallExpr struct {
	NodeBase
	Callee Expr
	Args   []Expr
}

func (n *CallExpr) Type() NodeType { return AST_CALL_EXPR }
func (n *CallExpr) Base() *NodeBase { return &n.NodeBase }
func (n *CallExpr) isExpr() {}

// Identifier represents an identifier expression
type Identifier struct {
	NodeBase
	Name string
}

func (n *Identifier) Type() NodeType { return AST_IDENTIFIER }
func (n *Identifier) Base() *NodeBase { return &n.NodeBase }
func (n *Identifier) isExpr() {}

// NumberLiteral represents a number literal
type NumberLiteral struct {
	NodeBase
	Value string
}

func (n *NumberLiteral) Type() NodeType { return AST_NUMBER }
func (n *NumberLiteral) Base() *NodeBase { return &n.NodeBase }
func (n *NumberLiteral) isExpr() {}

// StringLiteral represents a string literal
type StringLiteral struct {
	NodeBase
	Value string
}

func (n *StringLiteral) Type() NodeType { return AST_STRING }
func (n *StringLiteral) Base() *NodeBase { return &n.NodeBase }
func (n *StringLiteral) isExpr() {}

// StringInterpolation represents a string interpolation expression
type StringInterpolation struct {
	NodeBase
	TextSegments []string        // Text segments
	InterpExprs  []Expr          // Interpolation expressions
	FormatSpecs  []FormatSpec    // Format specifiers (corresponding to interp_exprs, may be empty)
	SegmentCount int             // Total count of text and interp segments (alternating: text, interp, text, interp, ...)
	TextCount    int             // Number of text segments
	InterpCount  int             // Number of interpolation segments
}

func (n *StringInterpolation) Type() NodeType { return AST_STRING_INTERPOLATION }
func (n *StringInterpolation) Base() *NodeBase { return &n.NodeBase }
func (n *StringInterpolation) isExpr() {}

// BoolLiteral represents a boolean literal
type BoolLiteral struct {
	NodeBase
	Value bool
}

func (n *BoolLiteral) Type() NodeType { return AST_BOOL }
func (n *BoolLiteral) Base() *NodeBase { return &n.NodeBase }
func (n *BoolLiteral) isExpr() {}

// NullLiteral represents a null literal
type NullLiteral struct {
	NodeBase
}

func (n *NullLiteral) Type() NodeType { return AST_NULL }
func (n *NullLiteral) Base() *NodeBase { return &n.NodeBase }
func (n *NullLiteral) isExpr() {}

// ErrorExpr represents an error expression
type ErrorExpr struct {
	NodeBase
	ErrorName string
}

func (n *ErrorExpr) Type() NodeType { return AST_ERROR_EXPR }
func (n *ErrorExpr) Base() *NodeBase { return &n.NodeBase }
func (n *ErrorExpr) isExpr() {}

// CatchExpr represents a catch expression: expr catch |err| { ... } or expr catch { ... }
type CatchExpr struct {
	NodeBase
	Expr      Expr  // Expression being caught (returns !T type)
	ErrorVar  string // Error variable name (empty if no |err|)
	CatchBody *Block // Catch block
}

func (n *CatchExpr) Type() NodeType { return AST_CATCH_EXPR }
func (n *CatchExpr) Base() *NodeBase { return &n.NodeBase }
func (n *CatchExpr) isExpr() {}

// MemberAccess represents a member access expression (obj.field)
type MemberAccess struct {
	NodeBase
	Object    Expr
	FieldName string
}

func (n *MemberAccess) Type() NodeType { return AST_MEMBER_ACCESS }
func (n *MemberAccess) Base() *NodeBase { return &n.NodeBase }
func (n *MemberAccess) isExpr() {}

// SubscriptExpr represents an array subscript expression (arr[index])
type SubscriptExpr struct {
	NodeBase
	Array Expr
	Index Expr
}

func (n *SubscriptExpr) Type() NodeType { return AST_SUBSCRIPT_EXPR }
func (n *SubscriptExpr) Base() *NodeBase { return &n.NodeBase }
func (n *SubscriptExpr) isExpr() {}

// StructInit represents a struct initialization expression
type StructInit struct {
	NodeBase
	StructName string
	FieldInits []Expr
	FieldNames []string
	FieldCount int
}

func (n *StructInit) Type() NodeType { return AST_STRUCT_INIT }
func (n *StructInit) Base() *NodeBase { return &n.NodeBase }
func (n *StructInit) isExpr() {}

// TupleLiteral represents a tuple literal
type TupleLiteral struct {
	NodeBase
	Elements []Expr
}

func (n *TupleLiteral) Type() NodeType { return AST_TUPLE_LITERAL }
func (n *TupleLiteral) Base() *NodeBase { return &n.NodeBase }
func (n *TupleLiteral) isExpr() {}

// MatchExpr represents a match expression: match expr { pattern => body, ... }
type MatchExpr struct {
	NodeBase
	Expr     Expr     // Expression to match
	Patterns []*Pattern // Pattern array
}

func (n *MatchExpr) Type() NodeType { return AST_MATCH_EXPR }
func (n *MatchExpr) Base() *NodeBase { return &n.NodeBase }
func (n *MatchExpr) isExpr() {}

// Pattern represents a pattern in a match expression
type Pattern struct {
	NodeBase
	PatternType int // Pattern type (literal, identifier, tuple, etc.)
	Value       Expr // Pattern value
	Body        *Block // Pattern body
}

func (n *Pattern) Type() NodeType { return AST_PATTERN }
func (n *Pattern) Base() *NodeBase { return &n.NodeBase }
func (n *Pattern) isExpr() {}

