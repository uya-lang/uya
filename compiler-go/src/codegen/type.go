package codegen

import (
	"fmt"

	"github.com/uya/compiler-go/src/ir"
)

// GetCType converts an IR type to its C type string representation
func GetCType(irType ir.Type) string {
	switch irType {
	case ir.TypeI8:
		return "int8_t"
	case ir.TypeI16:
		return "int16_t"
	case ir.TypeI32:
		return "int32_t"
	case ir.TypeI64:
		return "int64_t"
	case ir.TypeU8:
		return "uint8_t"
	case ir.TypeU16:
		return "uint16_t"
	case ir.TypeU32:
		return "uint32_t"
	case ir.TypeU64:
		return "uint64_t"
	case ir.TypeF32:
		return "float"
	case ir.TypeF64:
		return "double"
	case ir.TypeBool:
		return "uint8_t"
	case ir.TypeByte:
		return "uint8_t"
	case ir.TypeVoid:
		return "void"
	case ir.TypePtr:
		return "void*"
	case ir.TypeArray:
		return "array_type" // Needs special handling
	case ir.TypeStruct:
		return "struct_type" // Needs special handling
	case ir.TypeEnum:
		return "enum_type" // Needs special handling
	case ir.TypeFn:
		return "fn_type" // Needs special handling
	case ir.TypeErrorUnion:
		return "error_union" // Needs special handling
	default:
		return "unknown_type"
	}
}

// GetCTypeWithName converts an IR type with an original type name to C type string
// This is used for user-defined types like structs
func GetCTypeWithName(irType ir.Type, originalTypeName string) string {
	// If we have an original type name (for structs, enums, etc.), use it
	if originalTypeName != "" {
		switch irType {
		case ir.TypeStruct:
			return originalTypeName
		case ir.TypeEnum:
			return originalTypeName
		case ir.TypePtr:
			// For pointer types with original name, use the name directly
			return originalTypeName + "*"
		case ir.TypeArray:
			// For array types, originalTypeName would be the element type name
			return fmt.Sprintf("%s[]", originalTypeName)
		}
	}

	// Fall back to basic type conversion
	return GetCType(irType)
}

// GetCTypeForVarDecl converts an IR type for a variable declaration
func GetCTypeForVarDecl(irType ir.Type, originalTypeName string, isAtomic bool) string {
	cType := GetCTypeWithName(irType, originalTypeName)
	
	// Handle atomic types
	if isAtomic {
		// For atomic types, wrap with _Atomic
		return fmt.Sprintf("_Atomic(%s)", cType)
	}
	
	return cType
}

