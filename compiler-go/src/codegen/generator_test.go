package codegen

import (
	"os"
	"testing"

	"github.com/uya/compiler-go/src/ir"
)

// TestNewGenerator tests code generator creation
func TestNewGenerator(t *testing.T) {
	gen := NewGenerator()
	if gen == nil {
		t.Fatal("NewGenerator returned nil")
	}

	if gen.labelCounter != 0 {
		t.Errorf("Expected labelCounter = 0, got %d", gen.labelCounter)
	}

	if gen.tempCounter != 0 {
		t.Errorf("Expected tempCounter = 0, got %d", gen.tempCounter)
	}

	if gen.errorMap == nil {
		t.Error("Expected errorMap to be initialized")
	}

	if len(gen.errorMap) != 0 {
		t.Errorf("Expected errorMap length = 0, got %d", len(gen.errorMap))
	}
}

// TestGenerator_SetOutputFile tests setting output file
func TestGenerator_SetOutputFile(t *testing.T) {
	gen := NewGenerator()
	defer gen.Free()

	tmpfile, err := os.CreateTemp("", "test_codegen_*.c")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	tmpfile.Close()
	defer os.Remove(tmpfile.Name())

	if err := gen.SetOutputFile(tmpfile.Name()); err != nil {
		t.Fatalf("SetOutputFile failed: %v", err)
	}

	if gen.outputFile == nil {
		t.Error("Expected outputFile to be set")
	}

	if gen.outputWriter == nil {
		t.Error("Expected outputWriter to be set")
	}

	if gen.outputFilename != tmpfile.Name() {
		t.Errorf("Expected outputFilename = %s, got %s", tmpfile.Name(), gen.outputFilename)
	}
}

// TestGenerator_Write tests writing to output
func TestGenerator_Write(t *testing.T) {
	gen := NewGenerator()
	defer gen.Free()

	tmpfile, err := os.CreateTemp("", "test_codegen_*.c")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	tmpfile.Close()
	defer os.Remove(tmpfile.Name())

	if err := gen.SetOutputFile(tmpfile.Name()); err != nil {
		t.Fatalf("SetOutputFile failed: %v", err)
	}

	testString := "int main() { return 0; }\n"
	if err := gen.Write(testString); err != nil {
		t.Fatalf("Write failed: %v", err)
	}

	// Flush to ensure data is written
	if err := gen.outputWriter.Flush(); err != nil {
		t.Fatalf("Flush failed: %v", err)
	}

	// Read back and verify
	data, err := os.ReadFile(tmpfile.Name())
	if err != nil {
		t.Fatalf("Failed to read file: %v", err)
	}

	if string(data) != testString {
		t.Errorf("Expected %q, got %q", testString, string(data))
	}
}

// TestGenerator_Writef tests formatted writing
func TestGenerator_Writef(t *testing.T) {
	gen := NewGenerator()
	defer gen.Free()

	tmpfile, err := os.CreateTemp("", "test_codegen_*.c")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	tmpfile.Close()
	defer os.Remove(tmpfile.Name())

	if err := gen.SetOutputFile(tmpfile.Name()); err != nil {
		t.Fatalf("SetOutputFile failed: %v", err)
	}

	if err := gen.Writef("int %s = %d;\n", "x", 42); err != nil {
		t.Fatalf("Writef failed: %v", err)
	}

	if err := gen.outputWriter.Flush(); err != nil {
		t.Fatalf("Flush failed: %v", err)
	}

	data, err := os.ReadFile(tmpfile.Name())
	if err != nil {
		t.Fatalf("Failed to read file: %v", err)
	}

	expected := "int x = 42;\n"
	if string(data) != expected {
		t.Errorf("Expected %q, got %q", expected, string(data))
	}
}

// TestGenerator_NextLabel tests label generation
func TestGenerator_NextLabel(t *testing.T) {
	gen := NewGenerator()

	label1 := gen.NextLabel()
	if label1 != "label_0" {
		t.Errorf("Expected label_0, got %s", label1)
	}

	label2 := gen.NextLabel()
	if label2 != "label_1" {
		t.Errorf("Expected label_1, got %s", label2)
	}

	if gen.labelCounter != 2 {
		t.Errorf("Expected labelCounter = 2, got %d", gen.labelCounter)
	}
}

// TestGenerator_NextTemp tests temporary variable name generation
func TestGenerator_NextTemp(t *testing.T) {
	gen := NewGenerator()

	temp1 := gen.NextTemp()
	if temp1 != "temp_0" {
		t.Errorf("Expected temp_0, got %s", temp1)
	}

	temp2 := gen.NextTemp()
	if temp2 != "temp_1" {
		t.Errorf("Expected temp_1, got %s", temp2)
	}

	if gen.tempCounter != 2 {
		t.Errorf("Expected tempCounter = 2, got %d", gen.tempCounter)
	}
}

// TestGetCType tests type conversion
func TestGetCType(t *testing.T) {
	tests := []struct {
		name    string
		irType  ir.Type
		want    string
	}{
		{"i32", ir.TypeI32, "int32_t"},
		{"i64", ir.TypeI64, "int64_t"},
		{"u32", ir.TypeU32, "uint32_t"},
		{"f32", ir.TypeF32, "float"},
		{"f64", ir.TypeF64, "double"},
		{"bool", ir.TypeBool, "uint8_t"},
		{"void", ir.TypeVoid, "void"},
		{"ptr", ir.TypePtr, "void*"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GetCType(tt.irType)
			if got != tt.want {
				t.Errorf("GetCType(%v) = %v, want %v", tt.irType, got, tt.want)
			}
		})
	}
}

// TestGetCTypeWithName tests type conversion with original name
func TestGetCTypeWithName(t *testing.T) {
	tests := []struct {
		name           string
		irType         ir.Type
		originalName   string
		want           string
	}{
		{"struct with name", ir.TypeStruct, "MyStruct", "MyStruct"},
		{"enum with name", ir.TypeEnum, "MyEnum", "MyEnum"},
		{"ptr with name", ir.TypePtr, "MyType", "MyType*"},
		{"array with name", ir.TypeArray, "int32_t", "int32_t[]"},
		{"i32 without name", ir.TypeI32, "", "int32_t"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GetCTypeWithName(tt.irType, tt.originalName)
			if got != tt.want {
				t.Errorf("GetCTypeWithName(%v, %q) = %v, want %v", tt.irType, tt.originalName, got, tt.want)
			}
		})
	}
}

// TestGenerator_WriteValue_Constant tests writing constant values
func TestGenerator_WriteValue_Constant(t *testing.T) {
	gen := NewGenerator()
	defer gen.Free()

	tmpfile, err := os.CreateTemp("", "test_codegen_*.c")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	tmpfile.Close()
	defer os.Remove(tmpfile.Name())

	if err := gen.SetOutputFile(tmpfile.Name()); err != nil {
		t.Fatalf("SetOutputFile failed: %v", err)
	}

	// Test numeric constant
	constInst := ir.NewConstantInst("42", ir.TypeI32)
	if err := gen.WriteValue(constInst); err != nil {
		t.Fatalf("WriteValue failed: %v", err)
	}

	if err := gen.outputWriter.Flush(); err != nil {
		t.Fatalf("Flush failed: %v", err)
	}

	data, err := os.ReadFile(tmpfile.Name())
	if err != nil {
		t.Fatalf("Failed to read file: %v", err)
	}

	if string(data) != "42" {
		t.Errorf("Expected '42', got %q", string(data))
	}
}

// TestGenerator_WriteValue_StringConstant tests writing string constants
func TestGenerator_WriteValue_StringConstant(t *testing.T) {
	gen := NewGenerator()
	defer gen.Free()

	tmpfile, err := os.CreateTemp("", "test_codegen_*.c")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	tmpfile.Close()
	defer os.Remove(tmpfile.Name())

	if err := gen.SetOutputFile(tmpfile.Name()); err != nil {
		t.Fatalf("SetOutputFile failed: %v", err)
	}

	// Test string constant
	constInst := ir.NewConstantInst("hello", ir.TypePtr)
	if err := gen.WriteValue(constInst); err != nil {
		t.Fatalf("WriteValue failed: %v", err)
	}

	if err := gen.outputWriter.Flush(); err != nil {
		t.Fatalf("Flush failed: %v", err)
	}

	data, err := os.ReadFile(tmpfile.Name())
	if err != nil {
		t.Fatalf("Failed to read file: %v", err)
	}

	expected := "\"hello\""
	if string(data) != expected {
		t.Errorf("Expected %q, got %q", expected, string(data))
	}
}

// TestGenerator_WriteValue_VarDecl tests writing variable references
func TestGenerator_WriteValue_VarDecl(t *testing.T) {
	gen := NewGenerator()
	defer gen.Free()

	tmpfile, err := os.CreateTemp("", "test_codegen_*.c")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	tmpfile.Close()
	defer os.Remove(tmpfile.Name())

	if err := gen.SetOutputFile(tmpfile.Name()); err != nil {
		t.Fatalf("SetOutputFile failed: %v", err)
	}

	// Test variable declaration reference
	varInst := ir.NewVarDeclInst("x", ir.TypeI32, "", nil, false, false)
	if err := gen.WriteValue(varInst); err != nil {
		t.Fatalf("WriteValue failed: %v", err)
	}

	if err := gen.outputWriter.Flush(); err != nil {
		t.Fatalf("Flush failed: %v", err)
	}

	data, err := os.ReadFile(tmpfile.Name())
	if err != nil {
		t.Fatalf("Failed to read file: %v", err)
	}

	if string(data) != "x" {
		t.Errorf("Expected 'x', got %q", string(data))
	}
}

// TestGenerator_GenerateInst_VarDecl tests generating variable declaration
func TestGenerator_GenerateInst_VarDecl(t *testing.T) {
	gen := NewGenerator()
	defer gen.Free()

	tmpfile, err := os.CreateTemp("", "test_codegen_*.c")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	tmpfile.Close()
	defer os.Remove(tmpfile.Name())

	if err := gen.SetOutputFile(tmpfile.Name()); err != nil {
		t.Fatalf("SetOutputFile failed: %v", err)
	}

	// Test variable declaration
	// Create VarDeclInst using the struct directly since NewVarDeclInst signature may vary
	varInst := &ir.VarDeclInst{
		BaseInst: ir.BaseInst{},
		Name:     "x",
		Typ:      ir.TypeI32,
	}
	if err := gen.GenerateInst(varInst); err != nil {
		t.Fatalf("GenerateInst failed: %v", err)
	}

	if err := gen.outputWriter.Flush(); err != nil {
		t.Fatalf("Flush failed: %v", err)
	}

	data, err := os.ReadFile(tmpfile.Name())
	if err != nil {
		t.Fatalf("Failed to read file: %v", err)
	}

	expected := "int32_t x;"
	if string(data) != expected {
		t.Errorf("Expected %q, got %q", expected, string(data))
	}
}

// TestGenerator_GenerateInst_VarDeclWithInit tests variable declaration with initialization
func TestGenerator_GenerateInst_VarDeclWithInit(t *testing.T) {
	gen := NewGenerator()
	defer gen.Free()

	tmpfile, err := os.CreateTemp("", "test_codegen_*.c")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	tmpfile.Close()
	defer os.Remove(tmpfile.Name())

	if err := gen.SetOutputFile(tmpfile.Name()); err != nil {
		t.Fatalf("SetOutputFile failed: %v", err)
	}

	// Test variable declaration with initialization
	initInst := ir.NewConstantInst("42", ir.TypeI32)
	varInst := &ir.VarDeclInst{
		BaseInst: ir.BaseInst{},
		Name:     "x",
		Typ:      ir.TypeI32,
		Init:     initInst,
	}
	if err := gen.GenerateInst(varInst); err != nil {
		t.Fatalf("GenerateInst failed: %v", err)
	}

	if err := gen.outputWriter.Flush(); err != nil {
		t.Fatalf("Flush failed: %v", err)
	}

	data, err := os.ReadFile(tmpfile.Name())
	if err != nil {
		t.Fatalf("Failed to read file: %v", err)
	}

	expected := "int32_t x = 42;"
	if string(data) != expected {
		t.Errorf("Expected %q, got %q", expected, string(data))
	}
}

