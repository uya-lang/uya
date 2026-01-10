package parser

// Program represents the root node of an AST
type Program struct {
	NodeBase
	Decls []Node // Top-level declarations
}

func (n *Program) Type() NodeType { return AST_PROGRAM }
func (n *Program) Base() *NodeBase { return &n.NodeBase }

// FuncDecl represents a function declaration
type FuncDecl struct {
	NodeBase
	Name       string
	Params     []*Param
	ReturnType Node // Type node
	Body       *Block
	IsExtern   bool
}

func (n *FuncDecl) Type() NodeType { return AST_FN_DECL }
func (n *FuncDecl) Base() *NodeBase { return &n.NodeBase }

// Param represents a function parameter
type Param struct {
	NodeBase
	Name string
	Type Node // Type node
}

// VarDecl represents a variable declaration
type VarDecl struct {
	NodeBase
	Name    string
	VarType Node // Type node (renamed from Type to avoid conflict with Type() method)
	Init    Expr // Initial value expression
	IsMut   bool
	IsConst bool
}

func (n *VarDecl) Type() NodeType { return AST_VAR_DECL }
func (n *VarDecl) Base() *NodeBase { return &n.NodeBase }

// StructDecl represents a struct declaration
type StructDecl struct {
	NodeBase
	Name   string
	Fields []*Field
}

func (n *StructDecl) Type() NodeType { return AST_STRUCT_DECL }
func (n *StructDecl) Base() *NodeBase { return &n.NodeBase }

// Field represents a struct field
type Field struct {
	NodeBase
	Name string
	Type Node // Type node
}

// EnumDecl represents an enum declaration
type EnumDecl struct {
	NodeBase
	Name     string
	Variants []EnumVariant
}

func (n *EnumDecl) Type() NodeType { return AST_ENUM_DECL }
func (n *EnumDecl) Base() *NodeBase { return &n.NodeBase }

// InterfaceDecl represents an interface declaration
type InterfaceDecl struct {
	NodeBase
	Name    string
	Methods []*FuncDecl // Method declarations
}

func (n *InterfaceDecl) Type() NodeType { return AST_INTERFACE_DECL }
func (n *InterfaceDecl) Base() *NodeBase { return &n.NodeBase }

// ImplDecl represents an interface implementation
// New syntax (version 0.24): StructName : InterfaceName { ... }
type ImplDecl struct {
	NodeBase
	StructName   string
	InterfaceName string
	Methods      []*FuncDecl
}

func (n *ImplDecl) Type() NodeType { return AST_IMPL_DECL }
func (n *ImplDecl) Base() *NodeBase { return &n.NodeBase }

// ErrorDecl represents an error declaration
type ErrorDecl struct {
	NodeBase
	Name string
}

func (n *ErrorDecl) Type() NodeType { return AST_ERROR_DECL }
func (n *ErrorDecl) Base() *NodeBase { return &n.NodeBase }

// ExternDecl represents an external declaration
type ExternDecl struct {
	NodeBase
	Name string
	Decl Node // Function or variable declaration
}

func (n *ExternDecl) Type() NodeType { return AST_EXTERN_DECL }
func (n *ExternDecl) Base() *NodeBase { return &n.NodeBase }

// MacroDecl represents a macro declaration
type MacroDecl struct {
	NodeBase
	Name string
	Body Node
}

func (n *MacroDecl) Type() NodeType { return AST_MACRO_DECL }
func (n *MacroDecl) Base() *NodeBase { return &n.NodeBase }

