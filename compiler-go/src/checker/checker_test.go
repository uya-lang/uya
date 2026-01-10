package checker

import (
	"testing"

	"github.com/uya/compiler-go/src/parser"
)

// TestTypeChecker_BasicCreation tests basic TypeChecker creation
func TestTypeChecker_BasicCreation(t *testing.T) {
	tc := NewTypeChecker()
	if tc == nil {
		t.Fatal("NewTypeChecker() returned nil")
	}

	if tc.ErrorCount() != 0 {
		t.Errorf("Expected 0 errors, got %d", tc.ErrorCount())
	}

	if tc.symbolTable == nil {
		t.Error("symbolTable is nil")
	}

	if tc.scopes == nil {
		t.Error("scopes is nil")
	}

	if tc.functionTable == nil {
		t.Error("functionTable is nil")
	}
}

// TestTypeChecker_CheckEmptyProgram tests checking an empty program
func TestTypeChecker_CheckEmptyProgram(t *testing.T) {
	tc := NewTypeChecker()
	program := &parser.Program{
		Decls: []parser.Node{},
	}

	result := tc.Check(program)
	if !result {
		t.Error("Check() should return true for empty program")
	}

	if tc.ErrorCount() != 0 {
		t.Errorf("Expected 0 errors, got %d", tc.ErrorCount())
	}
}

// TestTypeChecker_CheckNilProgram tests checking a nil program
func TestTypeChecker_CheckNilProgram(t *testing.T) {
	tc := NewTypeChecker()

	result := tc.Check(nil)
	if result {
		t.Error("Check() should return false for nil program")
	}

	if tc.ErrorCount() == 0 {
		t.Error("Expected at least one error for nil program")
	}
}

// TestTypeChecker_ErrorReporting tests error reporting functionality
func TestTypeChecker_ErrorReporting(t *testing.T) {
	tc := NewTypeChecker()

	tc.AddError("Test error 1")
	tc.AddError("Test error 2: %s", "value")

	if tc.ErrorCount() != 2 {
		t.Errorf("Expected 2 errors, got %d", tc.ErrorCount())
	}

	errors := tc.Errors()
	if len(errors) != 2 {
		t.Errorf("Expected 2 errors in Errors(), got %d", len(errors))
	}

	if errors[0] != "Test error 1" {
		t.Errorf("Expected 'Test error 1', got '%s'", errors[0])
	}

	if errors[1] != "Test error 2: value" {
		t.Errorf("Expected 'Test error 2: value', got '%s'", errors[1])
	}
}

// TestTypeChecker_SimpleVarDecl tests checking a simple variable declaration
func TestTypeChecker_SimpleVarDecl(t *testing.T) {
	tc := NewTypeChecker()

	// Create a simple program with a variable declaration
	// var x: i32 = 42;
	varDecl := &parser.VarDecl{
		NodeBase: parser.NodeBase{
			Line:   1,
			Column: 1,
		},
		Name:    "x",
		VarType: &parser.NamedType{NodeBase: parser.NodeBase{Line: 1, Column: 10}, Name: "i32"},
		Init: &parser.NumberLiteral{
			NodeBase: parser.NodeBase{Line: 1, Column: 18},
			Value:    "42",
		},
		IsMut:   false,
		IsConst: false,
	}

	program := &parser.Program{
		Decls: []parser.Node{varDecl},
	}

	// Note: This test is basic - it tests that the checker doesn't crash
	// Full type checking would require a complete AST with proper initialization
	result := tc.Check(program)
	// The result depends on whether the initialization expression type matches
	// For now, we just check that it doesn't crash
	_ = result
}

// TestTypeChecker_FunctionSignatureCollection tests function signature collection
func TestTypeChecker_FunctionSignatureCollection(t *testing.T) {
	tc := NewTypeChecker()

	// Create a simple function declaration
	funcDecl := &parser.FuncDecl{
		NodeBase: parser.NodeBase{
			Line:   1,
			Column: 1,
		},
		Name: "testFunc",
		Params: []*parser.Param{
			{
				NodeBase: parser.NodeBase{Line: 1, Column: 20},
				Name:     "x",
				Type:     &parser.NamedType{NodeBase: parser.NodeBase{Line: 1, Column: 25}, Name: "i32"},
			},
		},
		ReturnType: &parser.NamedType{NodeBase: parser.NodeBase{Line: 1, Column: 35}, Name: "i32"},
		Body:       nil, // No body for this test
		IsExtern:   false,
	}

	program := &parser.Program{
		Decls: []parser.Node{funcDecl},
	}

	// Check the program (first pass should collect function signature)
	result := tc.Check(program)
	// Result depends on implementation details
	_ = result

	// Check that function was added to function table
	sig := tc.LookupFunction("testFunc")
	if sig == nil {
		t.Error("Function signature was not added to function table")
	} else {
		if sig.Name != "testFunc" {
			t.Errorf("Expected function name 'testFunc', got '%s'", sig.Name)
		}
		if len(sig.ParamTypes) != 1 {
			t.Errorf("Expected 1 parameter, got %d", len(sig.ParamTypes))
		}
		if sig.ReturnType != TypeI32 {
			t.Errorf("Expected return type TypeI32, got %v", sig.ReturnType)
		}
	}
}

// TestTypeChecker_ScopeManagement tests scope management
func TestTypeChecker_ScopeManagement(t *testing.T) {
	tc := NewTypeChecker()

	initialScope := tc.CurrentScope()
	if initialScope != 0 {
		t.Errorf("Expected initial scope 0, got %d", initialScope)
	}

	tc.EnterScope()
	scope1 := tc.CurrentScope()
	if scope1 <= initialScope {
		t.Errorf("Expected scope > %d after EnterScope(), got %d", initialScope, scope1)
	}

	tc.EnterScope()
	scope2 := tc.CurrentScope()
	if scope2 <= scope1 {
		t.Errorf("Expected scope > %d after second EnterScope(), got %d", scope1, scope2)
	}

	tc.ExitScope()
	scopeAfterExit := tc.CurrentScope()
	if scopeAfterExit != scope1 {
		t.Errorf("Expected scope %d after ExitScope(), got %d", scope1, scopeAfterExit)
	}

	tc.ExitScope()
	finalScope := tc.CurrentScope()
	if finalScope != initialScope {
		t.Errorf("Expected scope %d after all ExitScope(), got %d", initialScope, finalScope)
	}
}

// TestTypeChecker_SymbolLookup tests symbol lookup functionality
func TestTypeChecker_SymbolLookup(t *testing.T) {
	tc := NewTypeChecker()

	// Add a symbol
	symbol := &Symbol{
		Name:       "testVar",
		Type:       TypeI32,
		IsMut:      false,
		IsConst:    false,
		ScopeLevel: tc.CurrentScope(),
		Line:       1,
		Column:     1,
	}

	if !tc.AddSymbol(symbol) {
		t.Error("Failed to add symbol")
	}

	// Lookup the symbol
	found := tc.LookupSymbol("testVar")
	if found == nil {
		t.Error("LookupSymbol() returned nil for existing symbol")
	} else {
		if found.Name != "testVar" {
			t.Errorf("Expected symbol name 'testVar', got '%s'", found.Name)
		}
		if found.Type != TypeI32 {
			t.Errorf("Expected symbol type TypeI32, got %v", found.Type)
		}
	}

	// Lookup non-existent symbol
	notFound := tc.LookupSymbol("nonExistent")
	if notFound != nil {
		t.Error("LookupSymbol() should return nil for non-existent symbol")
	}
}

// TestTypeChecker_DuplicateSymbol tests duplicate symbol detection
func TestTypeChecker_DuplicateSymbol(t *testing.T) {
	tc := NewTypeChecker()

	scope := tc.CurrentScope()

	// Add first symbol
	symbol1 := &Symbol{
		Name:       "duplicate",
		Type:       TypeI32,
		ScopeLevel: scope,
		Line:       1,
		Column:     1,
	}

	if !tc.AddSymbol(symbol1) {
		t.Error("Failed to add first symbol")
	}

	// Try to add duplicate symbol in same scope
	symbol2 := &Symbol{
		Name:       "duplicate",
		Type:       TypeI64,
		ScopeLevel: scope,
		Line:       2,
		Column:     1,
	}

	if tc.AddSymbol(symbol2) {
		t.Error("AddSymbol() should return false for duplicate symbol in same scope")
	}

	if tc.ErrorCount() == 0 {
		t.Error("Expected error for duplicate symbol")
	}
}

// TestTypeChecker_FunctionTable tests function table operations
func TestTypeChecker_FunctionTable(t *testing.T) {
	tc := NewTypeChecker()

	// Add a function signature
	sig := &FunctionSignature{
		Name:       "testFunc",
		ParamTypes: []Type{TypeI32, TypeI64},
		ReturnType: TypeBool,
		IsExtern:   false,
	}

	tc.AddFunction(sig)

	// Lookup the function
	found := tc.LookupFunction("testFunc")
	if found == nil {
		t.Error("LookupFunction() returned nil for existing function")
	} else {
		if found.Name != "testFunc" {
			t.Errorf("Expected function name 'testFunc', got '%s'", found.Name)
		}
		if len(found.ParamTypes) != 2 {
			t.Errorf("Expected 2 parameters, got %d", len(found.ParamTypes))
		}
		if found.ParamTypes[0] != TypeI32 {
			t.Errorf("Expected first parameter TypeI32, got %v", found.ParamTypes[0])
		}
		if found.ParamTypes[1] != TypeI64 {
			t.Errorf("Expected second parameter TypeI64, got %v", found.ParamTypes[1])
		}
		if found.ReturnType != TypeBool {
			t.Errorf("Expected return type TypeBool, got %v", found.ReturnType)
		}
	}

	// Lookup non-existent function
	notFound := tc.LookupFunction("nonExistent")
	if notFound != nil {
		t.Error("LookupFunction() should return nil for non-existent function")
	}
}

