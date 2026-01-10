package parser

// Type is the interface for type nodes
type Type interface {
	Node
	isType()
}

// NamedType represents a named type
type NamedType struct {
	NodeBase
	Name string
}

func (n *NamedType) Type() NodeType { return AST_TYPE_NAMED }
func (n *NamedType) Base() *NodeBase { return &n.NodeBase }
func (n *NamedType) isType() {}

// PointerType represents a pointer type
type PointerType struct {
	NodeBase
	PointeeType Type
}

func (n *PointerType) Type() NodeType { return AST_TYPE_POINTER }
func (n *PointerType) Base() *NodeBase { return &n.NodeBase }
func (n *PointerType) isType() {}

// ArrayType represents an array type
type ArrayType struct {
	NodeBase
	ElementType Type
	Size        int // -1 for unsized arrays
}

func (n *ArrayType) Type() NodeType { return AST_TYPE_ARRAY }
func (n *ArrayType) Base() *NodeBase { return &n.NodeBase }
func (n *ArrayType) isType() {}

// FuncType represents a function pointer type: fn(param_types) return_type
type FuncType struct {
	NodeBase
	ParamTypes []Type // Parameter type list (types only, no parameter names)
	ReturnType Type   // Return type
}

func (n *FuncType) Type() NodeType { return AST_TYPE_FN }
func (n *FuncType) Base() *NodeBase { return &n.NodeBase }
func (n *FuncType) isType() {}

// ErrorUnionType represents an error union type (!T)
type ErrorUnionType struct {
	NodeBase
	BaseType Type
}

func (n *ErrorUnionType) Type() NodeType { return AST_TYPE_ERROR_UNION }
func (n *ErrorUnionType) Base() *NodeBase { return &n.NodeBase }
func (n *ErrorUnionType) isType() {}

// AtomicType represents an atomic type (atomic T)
type AtomicType struct {
	NodeBase
	BaseType Type
}

func (n *AtomicType) Type() NodeType { return AST_TYPE_ATOMIC }
func (n *AtomicType) Base() *NodeBase { return &n.NodeBase }
func (n *AtomicType) isType() {}

// BoolType represents the bool type
type BoolType struct {
	NodeBase
}

func (n *BoolType) Type() NodeType { return AST_TYPE_BOOL }
func (n *BoolType) Base() *NodeBase { return &n.NodeBase }
func (n *BoolType) isType() {}

// TupleType represents a tuple type
type TupleType struct {
	NodeBase
	ElementTypes []Type
}

func (n *TupleType) Type() NodeType { return AST_TYPE_TUPLE }
func (n *TupleType) Base() *NodeBase { return &n.NodeBase }
func (n *TupleType) isType() {}

