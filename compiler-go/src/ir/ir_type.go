package ir

// Type 表示 IR 类型
type Type int

// IR 类型常量 - 匹配 ir.h 中的 IRType
const (
	TypeI8 Type = iota
	TypeI16
	TypeI32
	TypeI64
	TypeU8
	TypeU16
	TypeU32
	TypeU64
	TypeF32
	TypeF64
	TypeBool
	TypeByte
	TypeVoid
	TypePtr
	TypeArray
	TypeStruct
	TypeEnum
	TypeFn
	TypeErrorUnion // !T 类型
)

// String 返回 IR 类型的字符串表示
func (t Type) String() string {
	switch t {
	case TypeI8:
		return "i8"
	case TypeI16:
		return "i16"
	case TypeI32:
		return "i32"
	case TypeI64:
		return "i64"
	case TypeU8:
		return "u8"
	case TypeU16:
		return "u16"
	case TypeU32:
		return "u32"
	case TypeU64:
		return "u64"
	case TypeF32:
		return "f32"
	case TypeF64:
		return "f64"
	case TypeBool:
		return "bool"
	case TypeByte:
		return "byte"
	case TypeVoid:
		return "void"
	case TypePtr:
		return "*T"
	case TypeArray:
		return "[T]"
	case TypeStruct:
		return "struct"
	case TypeEnum:
		return "enum"
	case TypeFn:
		return "fn"
	case TypeErrorUnion:
		return "!T"
	default:
		return "unknown"
	}
}

// Op 表示 IR 操作符
type Op int

// IR 操作符常量 - 匹配 ir.h 中的 IROp
const (
	OpAdd Op = iota
	OpSub
	OpMul
	OpDiv
	OpMod
	OpBitAnd
	OpBitOr
	OpBitXor
	OpBitNot
	OpLeftShift
	OpRightShift
	OpLogicAnd
	OpLogicOr
	OpNeg
	OpNot
	OpEq
	OpNe
	OpLt
	OpLe
	OpGt
	OpGe
	OpAddrOf // 取地址操作符 &
	OpDeref  // 解引用操作符 *
)

// String 返回 IR 操作符的字符串表示
func (o Op) String() string {
	switch o {
	case OpAdd:
		return "+"
	case OpSub:
		return "-"
	case OpMul:
		return "*"
	case OpDiv:
		return "/"
	case OpMod:
		return "%"
	case OpBitAnd:
		return "&"
	case OpBitOr:
		return "|"
	case OpBitXor:
		return "^"
	case OpBitNot:
		return "~"
	case OpLeftShift:
		return "<<"
	case OpRightShift:
		return ">>"
	case OpLogicAnd:
		return "&&"
	case OpLogicOr:
		return "||"
	case OpNeg:
		return "-"
	case OpNot:
		return "!"
	case OpEq:
		return "=="
	case OpNe:
		return "!="
	case OpLt:
		return "<"
	case OpLe:
		return "<="
	case OpGt:
		return ">"
	case OpGe:
		return ">="
	case OpAddrOf:
		return "&"
	case OpDeref:
		return "*"
	default:
		return "unknown"
	}
}

