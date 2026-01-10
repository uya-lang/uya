package ir

// InstType represents an IR instruction type
type InstType int

// IR instruction type constants - matching IRInstType from ir.h
const (
	InstFuncDecl InstType = iota
	InstFuncDef
	InstVarDecl
	InstAssign
	InstBinaryOp
	InstUnaryOp
	InstCall
	InstReturn
	InstIf
	InstWhile
	InstBlock
	InstLoad
	InstStore
	InstGoto
	InstLabel
	InstAlloc
	InstStructDecl
	InstEnumDecl
	InstMemberAccess
	InstSubscript
	InstCast
	InstErrorUnion
	InstTryCatch
	InstSlice
	InstFor
	InstConstant
	InstStructInit
	InstDrop
	InstDefer
	InstErrDefer
	InstErrorValue
	InstStringInterpolation
)

// String returns the string representation of an instruction type
func (it InstType) String() string {
	switch it {
	case InstFuncDecl:
		return "func_decl"
	case InstFuncDef:
		return "func_def"
	case InstVarDecl:
		return "var_decl"
	case InstAssign:
		return "assign"
	case InstBinaryOp:
		return "binary_op"
	case InstUnaryOp:
		return "unary_op"
	case InstCall:
		return "call"
	case InstReturn:
		return "return"
	case InstIf:
		return "if"
	case InstWhile:
		return "while"
	case InstBlock:
		return "block"
	case InstLoad:
		return "load"
	case InstStore:
		return "store"
	case InstGoto:
		return "goto"
	case InstLabel:
		return "label"
	case InstAlloc:
		return "alloc"
	case InstStructDecl:
		return "struct_decl"
	case InstEnumDecl:
		return "enum_decl"
	case InstMemberAccess:
		return "member_access"
	case InstSubscript:
		return "subscript"
	case InstCast:
		return "cast"
	case InstErrorUnion:
		return "error_union"
	case InstTryCatch:
		return "try_catch"
	case InstSlice:
		return "slice"
	case InstFor:
		return "for"
	case InstConstant:
		return "constant"
	case InstStructInit:
		return "struct_init"
	case InstDrop:
		return "drop"
	case InstDefer:
		return "defer"
	case InstErrDefer:
		return "errdefer"
	case InstErrorValue:
		return "error_value"
	case InstStringInterpolation:
		return "string_interpolation"
	default:
		return "unknown"
	}
}

// Inst represents an IR instruction
// This is the base interface that all IR instructions must implement
type Inst interface {
	Type() InstType
	ID() int
	SetID(id int)
}

// BaseInst provides common fields for all IR instructions
type BaseInst struct {
	id int // Instruction ID for SSA form
}

// ID returns the instruction ID
func (bi *BaseInst) ID() int {
	return bi.id
}

// SetID sets the instruction ID
func (bi *BaseInst) SetID(id int) {
	bi.id = id
}

// Note: Specific instruction types will be defined in separate files
// or as part of the generator implementation, as they have complex
// union-like structures that are better represented as separate structs
// with embedded BaseInst.

