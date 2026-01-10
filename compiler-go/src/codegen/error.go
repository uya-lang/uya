package codegen

import (
	"fmt"

	"github.com/uya/compiler-go/src/ir"
)

// WriteErrorUnionTypeName writes the error union type name (struct error_union_T)
func (g *Generator) WriteErrorUnionTypeName(baseType ir.Type) error {
	baseName := GetCType(baseType)
	return g.Writef("struct error_union_%s", baseName)
}

// WriteErrorUnionTypeDef writes the error union type definition
// According to uya.md: struct error_union_T { uint32_t error_id; T value; }
// error_id == 0: success (use value field)
// error_id != 0: error (error_id contains error code, value field undefined)
func (g *Generator) WriteErrorUnionTypeDef(baseType ir.Type) error {
	baseName := GetCType(baseType)
	
	if err := g.Writef("struct error_union_%s {\n", baseName); err != nil {
		return err
	}
	
	if err := g.Write("    uint32_t error_id; // 0 = success (use value), non-zero = error (use error_id)\n"); err != nil {
		return err
	}
	
	if baseType == ir.TypeVoid {
		// For !void, only error_id field, no value field
		return g.Write("};\n\n")
	}
	
	// For non-void types, include value field
	if err := g.Writef("    %s value; // success value (only valid when error_id == 0)\n", baseName); err != nil {
		return err
	}
	
	return g.Write("};\n\n")
}

// HashErrorName generates a hash code for an error name
// Hash function: error_code = error_code * 31 + char (similar to Java's String.hashCode)
// This ensures stability: same error name always generates same error code,
// even when other errors are added or removed
func HashErrorName(errorName string) uint32 {
	if errorName == "" {
		return 1 // Default error code (non-zero)
	}
	
	var errorCode uint32 = 0
	for _, r := range errorName {
		errorCode = errorCode*31 + uint32(r)
	}
	
	// Make sure error code is non-zero (0 indicates success)
	if errorCode == 0 {
		errorCode = 1
	}
	
	return errorCode
}

// GetErrorCodeString returns the error code as a C uint32_t literal string
func GetErrorCodeString(errorName string) string {
	code := HashErrorName(errorName)
	return fmt.Sprintf("%dU", code)
}

