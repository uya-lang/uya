package ir

import (
	"strings"

	"github.com/uya/compiler-go/src/parser"
)

// GetIRType 将 AST 类型转换为 IR 类型
func GetIRType(astType parser.Type) Type {
	if astType == nil {
		return TypeVoid
	}

	switch t := astType.(type) {
	case *parser.NamedType:
		name := t.Name
		switch name {
		case "i8":
			return TypeI8
		case "i16":
			return TypeI16
		case "i32":
			return TypeI32
		case "i64":
			return TypeI64
		case "u8":
			return TypeU8
		case "u16":
			return TypeU16
		case "u32":
			return TypeU32
		case "u64":
			return TypeU64
		case "f32":
			return TypeF32
		case "f64":
			return TypeF64
		case "bool":
			return TypeBool
		case "void":
			return TypeVoid
		case "byte":
			return TypeByte
		case "T":
			// 泛型类型参数 T（暂时作为 i32 处理，直到泛型完全实现）
			return TypeI32
		default:
			// 用户定义类型（如 Point、Vec3 等）返回 STRUCT 类型
			return TypeStruct
		}

	case *parser.ArrayType:
		return TypeArray

	case *parser.PointerType:
		return TypePtr

	case *parser.ErrorUnionType:
		// 错误联合类型，暂时返回基础类型
		// 完整的错误处理实现将在后续添加
		return GetIRType(t.BaseType)

	case *parser.AtomicType:
		// 原子类型，返回基础类型
		// atomic 标志将单独设置
		return GetIRType(t.BaseType)

	case *parser.FuncType:
		// 函数指针类型：fn(param_types) return_type
		return TypeFn

	case *parser.TupleType:
		// 元组类型使用 IR_TYPE_STRUCT 作为占位符
		return TypeStruct

	default:
		return TypeVoid
	}
}

// InferIRTypeFromExpr 从表达式节点推断 IR 类型（简化版）
func InferIRTypeFromExpr(expr parser.Expr) Type {
	if expr == nil {
		return TypeVoid
	}

	switch e := expr.(type) {
	case *parser.NumberLiteral:
		// 检查是否是浮点数字面量
		value := e.Value
		if strings.Contains(value, ".") || strings.Contains(value, "e") || strings.Contains(value, "E") {
			return TypeF64
		}
		return TypeI32

	case *parser.BoolLiteral:
		return TypeBool

	case *parser.Identifier:
		// 对于标识符，默认返回 i32（实际类型应该在类型检查阶段确定）
		return TypeI32

	case *parser.BinaryExpr:
		// 对于二元表达式，返回左操作数的类型
		return InferIRTypeFromExpr(e.Left)

	case *parser.UnaryExpr:
		// 对于一元表达式，返回操作数的类型
		return InferIRTypeFromExpr(e.Operand)

	default:
		return TypeI32 // 默认返回 i32
	}
}

// GetTypeNameString 从 AST 类型节点获取类型名称字符串
func GetTypeNameString(typeNode parser.Type) string {
	if typeNode == nil {
		return ""
	}

	switch t := typeNode.(type) {
	case *parser.NamedType:
		return t.Name

	case *parser.ArrayType:
		// 对于数组：array_ElementType
		elemName := GetTypeNameString(t.ElementType)
		if elemName == "" {
			return ""
		}
		return "array_" + elemName

	case *parser.PointerType:
		// 对于指针：ptr_PointeeType
		elemName := GetTypeNameString(t.PointeeType)
		if elemName == "" {
			return ""
		}
		return "ptr_" + elemName

	case *parser.TupleType:
		// 对于元组：tuple_T1_T2_...
		// TODO: 实现元组类型名称生成
		return "tuple"

	default:
		return ""
	}
}

