package parser

// NodeType represents the type of an AST node
type NodeType int

// AST node type constants - matching C ast.h
const (
	AST_PROGRAM NodeType = iota
	AST_STRUCT_DECL
	AST_FN_DECL
	AST_EXTERN_DECL
	AST_VAR_DECL
	AST_IF_STMT
	AST_WHILE_STMT
	AST_RETURN_STMT
	AST_ASSIGN
	AST_EXPR_STMT
	AST_BLOCK
	AST_BREAK_STMT
	AST_CONTINUE_STMT
	AST_DEFER_STMT
	AST_ERRDEFER_STMT
	AST_FOR_STMT
	AST_STRUCT_INIT

	// Expression types
	AST_BINARY_EXPR
	AST_UNARY_EXPR
	AST_CALL_EXPR
	AST_MEMBER_ACCESS
	AST_SUBSCRIPT_EXPR
	AST_IDENTIFIER
	AST_NUMBER
	AST_STRING
	AST_STRING_INTERPOLATION
	AST_BOOL
	AST_NULL
	AST_ERROR_EXPR
	AST_CATCH_EXPR

	// Type related
	AST_TYPE_NAMED
	AST_TYPE_POINTER
	AST_TYPE_ARRAY
	AST_TYPE_FN
	AST_TYPE_ERROR_UNION
	AST_TYPE_BOOL
	AST_TYPE_ATOMIC

	// Interface related
	AST_INTERFACE_DECL
	AST_IMPL_DECL

	// Enum related
	AST_ENUM_DECL

	// Error declaration related
	AST_ERROR_DECL

	// Macro related
	AST_MACRO_DECL

	// Tuple related
	AST_TYPE_TUPLE
	AST_TUPLE_LITERAL

	// Match expression related
	AST_MATCH_EXPR
	AST_PATTERN

	// Test related
	AST_TEST_BLOCK
)

// NodeBase contains common fields for all AST nodes
type NodeBase struct {
	Line     int
	Column   int
	Filename string
}

// Node is the interface that all AST nodes must implement
type Node interface {
	Type() NodeType
	Base() *NodeBase
}

// FormatSpec represents a format specifier for string interpolation
type FormatSpec struct {
	Flags     string // Format flags (e.g., "#", "0", "-", "+", " ")
	Width     int    // Field width (-1 means not specified)
	Precision int    // Precision (-1 means not specified)
	Type      byte   // Format type character ('d', 'u', 'x', 'X', 'f', 'e', 'g', 'c', 'p', etc.)
}

// EnumVariant represents an enum variant
type EnumVariant struct {
	Name  string // Variant name
	Value string // Explicit value (as string, if = NUM is specified, otherwise empty)
}

// Helper function to create a NodeBase
func newNodeBase(line, column int, filename string) NodeBase {
	return NodeBase{
		Line:     line,
		Column:   column,
		Filename: filename,
	}
}

