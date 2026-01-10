package ir

import (
	"testing"

	"github.com/uya/compiler-go/src/parser"
)

// TestNewGenerator tests IR generator creation
func TestNewGenerator(t *testing.T) {
	gen := NewGenerator()
	if gen == nil {
		t.Fatal("NewGenerator returned nil")
	}

	if gen.instructions == nil {
		t.Error("Generator.instructions is nil")
	}

	if gen.currentID != 0 {
		t.Errorf("Generator.currentID = %d, want 0", gen.currentID)
	}
}

// TestGenerator_AddInstruction tests adding instructions to generator
func TestGenerator_AddInstruction(t *testing.T) {
	gen := NewGenerator()

	// Create a constant instruction
	constInst := NewConstantInst("42", TypeI32)
	gen.AddInstruction(constInst)

	if len(gen.instructions) != 1 {
		t.Errorf("Expected 1 instruction, got %d", len(gen.instructions))
	}

	if gen.currentID != 1 {
		t.Errorf("Expected currentID = 1, got %d", gen.currentID)
	}

	// Verify instruction ID was set
	if constInst.ID() != 0 {
		t.Errorf("Expected instruction ID = 0, got %d", constInst.ID())
	}
}

// TestGenerator_Reset tests resetting the generator
func TestGenerator_Reset(t *testing.T) {
	gen := NewGenerator()

	// Add some instructions
	gen.AddInstruction(NewConstantInst("1", TypeI32))
	gen.AddInstruction(NewConstantInst("2", TypeI32))

	if gen.currentID != 2 {
		t.Errorf("Expected currentID = 2 before reset, got %d", gen.currentID)
	}

	gen.Reset()

	if gen.currentID != 0 {
		t.Errorf("Expected currentID = 0 after reset, got %d", gen.currentID)
	}

	if len(gen.instructions) != 0 {
		t.Errorf("Expected 0 instructions after reset, got %d", len(gen.instructions))
	}
}

// TestGenerateExpr_NumberLiteral tests generating IR for number literals
func TestGenerateExpr_NumberLiteral(t *testing.T) {
	gen := NewGenerator()

	expr := &parser.NumberLiteral{
		NodeBase: parser.NodeBase{
			Line:     1,
			Column:   1,
			Filename: "test.uya",
		},
		Value: "42",
	}

	inst := gen.GenerateExpr(expr)
	if inst == nil {
		t.Fatal("GenerateExpr returned nil")
	}

	if inst.Type() != InstConstant {
		t.Errorf("Expected InstConstant, got %v", inst.Type())
	}

	constInst, ok := inst.(*ConstantInst)
	if !ok {
		t.Fatal("Expected *ConstantInst")
	}

	if constInst.Value != "42" {
		t.Errorf("Expected value '42', got '%s'", constInst.Value)
	}

	if constInst.Typ != TypeI32 {
		t.Errorf("Expected type TypeI32, got %v", constInst.Typ)
	}
}

// TestGenerateExpr_StringLiteral tests generating IR for string literals
func TestGenerateExpr_StringLiteral(t *testing.T) {
	gen := NewGenerator()

	expr := &parser.StringLiteral{
		NodeBase: parser.NodeBase{
			Line:     1,
			Column:   1,
			Filename: "test.uya",
		},
		Value: "hello",
	}

	inst := gen.GenerateExpr(expr)
	if inst == nil {
		t.Fatal("GenerateExpr returned nil")
	}

	if inst.Type() != InstConstant {
		t.Errorf("Expected InstConstant, got %v", inst.Type())
	}

	constInst, ok := inst.(*ConstantInst)
	if !ok {
		t.Fatal("Expected *ConstantInst")
	}

	if constInst.Value != "hello" {
		t.Errorf("Expected value 'hello', got '%s'", constInst.Value)
	}

	if constInst.Typ != TypePtr {
		t.Errorf("Expected type TypePtr, got %v", constInst.Typ)
	}
}

// TestGenerateExpr_BoolLiteral tests generating IR for boolean literals
func TestGenerateExpr_BoolLiteral(t *testing.T) {
	gen := NewGenerator()

	tests := []struct {
		name  string
		value bool
		want  string
	}{
		{"true", true, "true"},
		{"false", false, "false"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			expr := &parser.BoolLiteral{
				NodeBase: parser.NodeBase{
					Line:     1,
					Column:   1,
					Filename: "test.uya",
				},
				Value: tt.value,
			}

			inst := gen.GenerateExpr(expr)
			if inst == nil {
				t.Fatal("GenerateExpr returned nil")
			}

			constInst, ok := inst.(*ConstantInst)
			if !ok {
				t.Fatal("Expected *ConstantInst")
			}

			if constInst.Value != tt.want {
				t.Errorf("Expected value '%s', got '%s'", tt.want, constInst.Value)
			}

			if constInst.Typ != TypeBool {
				t.Errorf("Expected type TypeBool, got %v", constInst.Typ)
			}
		})
	}
}

// TestGenerateExpr_Identifier tests generating IR for identifiers
func TestGenerateExpr_Identifier(t *testing.T) {
	gen := NewGenerator()

	expr := &parser.Identifier{
		NodeBase: parser.NodeBase{
			Line:     1,
			Column:   1,
			Filename: "test.uya",
		},
		Name: "x",
	}

	inst := gen.GenerateExpr(expr)
	if inst == nil {
		t.Fatal("GenerateExpr returned nil")
	}

	if inst.Type() != InstVarDecl {
		t.Errorf("Expected InstVarDecl, got %v", inst.Type())
	}

	varInst, ok := inst.(*VarDeclInst)
	if !ok {
		t.Fatal("Expected *VarDeclInst")
	}

	if varInst.Name != "x" {
		t.Errorf("Expected name 'x', got '%s'", varInst.Name)
	}
}

// TestGenerateStmt_ReturnStmt tests generating IR for return statements
func TestGenerateStmt_ReturnStmt(t *testing.T) {
	gen := NewGenerator()

	// Test return with expression
	expr := &parser.NumberLiteral{
		NodeBase: parser.NodeBase{
			Line:     1,
			Column:   1,
			Filename: "test.uya",
		},
		Value: "42",
	}

	stmt := &parser.ReturnStmt{
		NodeBase: parser.NodeBase{
			Line:     2,
			Column:   1,
			Filename: "test.uya",
		},
		Expr: expr,
	}

	inst := gen.GenerateStmt(stmt)
	if inst == nil {
		t.Fatal("GenerateStmt returned nil")
	}

	if inst.Type() != InstReturn {
		t.Errorf("Expected InstReturn, got %v", inst.Type())
	}

	retInst, ok := inst.(*ReturnInst)
	if !ok {
		t.Fatal("Expected *ReturnInst")
	}

	if retInst.Value == nil {
		t.Fatal("Expected return value to be non-nil")
	}

	if retInst.Value.Type() != InstConstant {
		t.Errorf("Expected return value to be ConstantInst, got %v", retInst.Value.Type())
	}

	// Test void return
	voidStmt := &parser.ReturnStmt{
		NodeBase: parser.NodeBase{
			Line:     3,
			Column:   1,
			Filename: "test.uya",
		},
		Expr: nil,
	}

	voidInst := gen.GenerateStmt(voidStmt)
	if voidInst == nil {
		t.Fatal("GenerateStmt returned nil for void return")
	}

	voidRetInst, ok := voidInst.(*ReturnInst)
	if !ok {
		t.Fatal("Expected *ReturnInst")
	}

	if voidRetInst.Value != nil {
		t.Error("Expected void return value to be nil")
	}
}

// TestGenerateFunction_Simple tests generating IR for a simple function
func TestGenerateFunction_Simple(t *testing.T) {
	gen := NewGenerator()

	// Create a simple function: fn main() -> void {}
	fnDecl := &parser.FuncDecl{
		NodeBase: parser.NodeBase{
			Line:     1,
			Column:   1,
			Filename: "test.uya",
		},
		Name:       "main",
		Params:     []*parser.Param{},
		ReturnType: &parser.NamedType{
			NodeBase: parser.NodeBase{
				Line:     1,
				Column:   10,
				Filename: "test.uya",
			},
			Name: "void",
		},
		Body: &parser.Block{
			NodeBase: parser.NodeBase{
				Line:     1,
				Column:   15,
				Filename: "test.uya",
			},
			Stmts: []parser.Stmt{},
		},
		IsExtern: false,
	}

	inst := gen.GenerateFunction(fnDecl)
	if inst == nil {
		t.Fatal("GenerateFunction returned nil")
	}

	if inst.Type() != InstFuncDef {
		t.Errorf("Expected InstFuncDef, got %v", inst.Type())
	}

	funcInst, ok := inst.(*FuncDefInst)
	if !ok {
		t.Fatal("Expected *FuncDefInst")
	}

	if funcInst.Name != "main" {
		t.Errorf("Expected function name 'main', got '%s'", funcInst.Name)
	}

	if funcInst.ReturnType != TypeVoid {
		t.Errorf("Expected return type TypeVoid, got %v", funcInst.ReturnType)
	}

	if len(funcInst.Params) != 0 {
		t.Errorf("Expected 0 parameters, got %d", len(funcInst.Params))
	}

	if funcInst.IsExtern {
		t.Error("Expected function to be non-extern")
	}
}

// TestGetIRType tests type conversion from AST types to IR types
func TestGetIRType(t *testing.T) {
	tests := []struct {
		name    string
		astType parser.Type
		want    Type
	}{
		{"i32", &parser.NamedType{Name: "i32"}, TypeI32},
		{"i64", &parser.NamedType{Name: "i64"}, TypeI64},
		{"u32", &parser.NamedType{Name: "u32"}, TypeU32},
		{"f32", &parser.NamedType{Name: "f32"}, TypeF32},
		{"f64", &parser.NamedType{Name: "f64"}, TypeF64},
		{"bool", &parser.NamedType{Name: "bool"}, TypeBool},
		{"void", &parser.NamedType{Name: "void"}, TypeVoid},
		{"pointer", &parser.PointerType{PointeeType: &parser.NamedType{Name: "i32"}}, TypePtr},
		{"array", &parser.ArrayType{ElementType: &parser.NamedType{Name: "i32"}}, TypeArray},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := GetIRType(tt.astType)
			if got != tt.want {
				t.Errorf("GetIRType() = %v, want %v", got, tt.want)
			}
		})
	}
}

// TestConstantInst tests constant instruction creation
func TestConstantInst(t *testing.T) {
	constInst := NewConstantInst("42", TypeI32)

	if constInst.Value != "42" {
		t.Errorf("Expected value '42', got '%s'", constInst.Value)
	}

	if constInst.Typ != TypeI32 {
		t.Errorf("Expected type TypeI32, got %v", constInst.Typ)
	}

	if constInst.Type() != InstConstant {
		t.Errorf("Expected InstConstant, got %v", constInst.Type())
	}

	if constInst.ID() != -1 {
		t.Errorf("Expected ID = -1 (unset), got %d", constInst.ID())
	}
}

