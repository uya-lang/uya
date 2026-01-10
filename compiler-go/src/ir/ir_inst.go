package ir

// InstType 表示 IR 指令类型
type InstType int

// IR 指令类型常量 - 匹配 ir.h 中的 IRInstType
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

// String 返回指令类型的字符串表示
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

// Inst 表示一条 IR 指令
// 这是所有 IR 指令必须实现的基础接口
type Inst interface {
	Type() InstType
	ID() int
	SetID(id int)
}

// BaseInst 提供所有 IR 指令的公共字段
type BaseInst struct {
	id int // 指令 ID（用于 SSA 形式）
}

// ID 返回指令 ID
func (bi *BaseInst) ID() int {
	return bi.id
}

// SetID 设置指令 ID
func (bi *BaseInst) SetID(id int) {
	bi.id = id
}

// 注意：具体的指令类型将在单独的文件中定义，或作为生成器实现的一部分。
// 因为它们具有复杂的类似 union 的结构，更适合表示为嵌入 BaseInst 的独立结构体。

