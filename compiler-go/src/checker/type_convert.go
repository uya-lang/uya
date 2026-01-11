package checker

import (
	"github.com/uya/compiler-go/src/parser"
)

// getTypeFromAST converts an AST Type node to a Type
// This is a temporary implementation until IR module is implemented
func getTypeFromAST(astType parser.Type) Type {
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
		default:
			// User-defined types (structs, etc.) are treated as struct type
			return TypeStruct
		}

	case *parser.PointerType:
		return TypePtr

	case *parser.ArrayType:
		return TypeArray

	case *parser.FuncType:
		return TypeFn

	case *parser.ErrorUnionType:
		// Error union type uses the base type
		return getTypeFromAST(t.BaseType)

	case *parser.AtomicType:
		// Atomic type uses the base type
		return getTypeFromAST(t.BaseType)

	case *parser.TupleType:
		// Tuple type uses TypeStruct as a placeholder
		return TypeStruct

	case *parser.BoolType:
		return TypeBool

	default:
		return TypeVoid
	}
}

// getArraySizeFromAST extracts array size from AST type node
func getArraySizeFromAST(astType parser.Type) int {
	if astType == nil {
		return -1
	}

	arrayType, ok := astType.(*parser.ArrayType)
	if !ok {
		return -1
	}

	return arrayType.Size
}

// getArrayElementTypeFromAST extracts array element type from AST type node
func getArrayElementTypeFromAST(astType parser.Type) Type {
	if astType == nil {
		return TypeVoid
	}

	arrayType, ok := astType.(*parser.ArrayType)
	if !ok {
		return TypeVoid
	}

	return getTypeFromAST(arrayType.ElementType)
}

// getTupleElementCountFromAST extracts tuple element count from AST type node
func getTupleElementCountFromAST(astType parser.Type) int {
	if astType == nil {
		return -1
	}

	tupleType, ok := astType.(*parser.TupleType)
	if !ok {
		return -1
	}

	return len(tupleType.ElementTypes)
}

// typeMatch checks if two types match
// This is a simplified version - full implementation would handle type compatibility
func typeMatch(t1, t2 Type) bool {
	// Exact match
	if t1 == t2 {
		return true
	}

	// Void types don't match with anything
	if t1 == TypeVoid || t2 == TypeVoid {
		return false
	}

	// For now, we allow some numeric type compatibility
	// This is a simplification - actual type checking would be more strict
	if isNumericType(t1) && isNumericType(t2) {
		return true
	}

	return false
}

// isNumericType checks if a type is numeric (integer or float)
func isNumericType(t Type) bool {
	return t == TypeI8 || t == TypeI16 || t == TypeI32 || t == TypeI64 ||
		t == TypeU8 || t == TypeU16 || t == TypeU32 || t == TypeU64 ||
		t == TypeF32 || t == TypeF64
}

// isIntegerType checks if a type is an integer type
func isIntegerType(t Type) bool {
	return t == TypeI8 || t == TypeI16 || t == TypeI32 || t == TypeI64 ||
		t == TypeU8 || t == TypeU16 || t == TypeU32 || t == TypeU64 || t == TypeByte
}

// isFloatType checks if a type is a float type
func isFloatType(t Type) bool {
	return t == TypeF32 || t == TypeF64
}

// isBoolType checks if a type is bool
func isBoolType(t Type) bool {
	return t == TypeBool
}

// isPointerType checks if a type is a pointer type
func isPointerType(t Type) bool {
	return t == TypePtr
}

// getTypeName returns a string representation of a Type for error messages
func getTypeName(t Type) string {
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
		return "[T : N]"
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

// isErrorValueExpr checks if an expression is an error value expression (error.ErrorName)
func isErrorValueExpr(expr parser.Expr) bool {
	if expr == nil {
		return false
	}

	// Check if it's a MemberAccess expression with object = Identifier("error")
	if memberAccess, ok := expr.(*parser.MemberAccess); ok {
		if ident, ok := memberAccess.Object.(*parser.Identifier); ok {
			return ident.Name == "error"
		}
	}

	// Check if it's an ErrorExpr
	if _, ok := expr.(*parser.ErrorExpr); ok {
		return true
	}

	return false
}
