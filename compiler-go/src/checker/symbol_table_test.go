package checker

import (
	"testing"
)

// TestSymbolTable tests basic symbol table operations
func TestSymbolTable(t *testing.T) {
	st := NewSymbolTable()

	// Create a test symbol
	symbol := &Symbol{
		Name:       "x",
		Type:       TypeI32,
		IsMut:      true,
		ScopeLevel: 0,
		Line:       1,
		Column:     1,
		Filename:   "test.uya",
	}

	// Add symbol to table
	st.AddSymbol(symbol)

	// Lookup symbol
	found := st.LookupSymbol("x", 0)
	if found == nil {
		t.Fatal("Expected to find symbol 'x'")
	}
	if found.Name != "x" {
		t.Errorf("Expected symbol name 'x', got '%s'", found.Name)
	}
	if found.Type != TypeI32 {
		t.Errorf("Expected symbol type TypeI32, got %d", found.Type)
	}
	if !found.IsMut {
		t.Error("Expected symbol to be mutable")
	}

	// Lookup non-existent symbol
	notFound := st.LookupSymbol("y", 0)
	if notFound != nil {
		t.Error("Expected not to find symbol 'y'")
	}
}

// TestScopeManagement tests scope stack operations
func TestScopeManagement(t *testing.T) {
	ss := NewScopeStack()

	// Initial scope should be 0
	if ss.CurrentScope() != 0 {
		t.Errorf("Expected initial scope to be 0, got %d", ss.CurrentScope())
	}

	// Enter scope
	level1 := ss.EnterScope()
	if level1 != 1 {
		t.Errorf("Expected scope level 1, got %d", level1)
	}
	if ss.CurrentScope() != 1 {
		t.Errorf("Expected current scope to be 1, got %d", ss.CurrentScope())
	}

	// Enter another scope
	level2 := ss.EnterScope()
	if level2 != 2 {
		t.Errorf("Expected scope level 2, got %d", level2)
	}
	if ss.CurrentScope() != 2 {
		t.Errorf("Expected current scope to be 2, got %d", ss.CurrentScope())
	}

	// Exit scope
	prevLevel := ss.ExitScope()
	if prevLevel != 1 {
		t.Errorf("Expected previous scope to be 1, got %d", prevLevel)
	}
	if ss.CurrentScope() != 1 {
		t.Errorf("Expected current scope to be 1 after exit, got %d", ss.CurrentScope())
	}

	// Exit scope again
	prevLevel = ss.ExitScope()
	if prevLevel != 0 {
		t.Errorf("Expected previous scope to be 0, got %d", prevLevel)
	}
	if ss.CurrentScope() != 0 {
		t.Errorf("Expected current scope to be 0 after exit, got %d", ss.CurrentScope())
	}
}

// TestSymbolTableScoping tests symbol lookup with scopes
func TestSymbolTableScoping(t *testing.T) {
	st := NewSymbolTable()
	ss := NewScopeStack()

	// Add symbol in scope 0
	symbol0 := &Symbol{
		Name:       "x",
		Type:       TypeI32,
		ScopeLevel: 0,
		Line:       1,
		Column:     1,
		Filename:   "test.uya",
	}
	st.AddSymbol(symbol0)

	// Enter scope 1
	level1 := ss.EnterScope()

	// Add symbol with same name in scope 1
	symbol1 := &Symbol{
		Name:       "x",
		Type:       TypeI64,
		ScopeLevel: level1,
		Line:       2,
		Column:     1,
		Filename:   "test.uya",
	}
	st.AddSymbol(symbol1)

	// Lookup in scope 1 should find the inner symbol
	found := st.LookupSymbol("x", level1)
	if found == nil {
		t.Fatal("Expected to find symbol 'x'")
	}
	if found.Type != TypeI64 {
		t.Errorf("Expected to find TypeI64 (inner symbol), got %d", found.Type)
	}

	// Exit scope 1
	ss.ExitScope()

	// Lookup in scope 0 should find the outer symbol
	found = st.LookupSymbol("x", 0)
	if found == nil {
		t.Fatal("Expected to find symbol 'x'")
	}
	if found.Type != TypeI32 {
		t.Errorf("Expected to find TypeI32 (outer symbol), got %d", found.Type)
	}
}

// TestRemoveSymbolsInScope tests removing symbols in a scope
func TestRemoveSymbolsInScope(t *testing.T) {
	st := NewSymbolTable()

	// Add symbols in different scopes
	symbol0 := &Symbol{
		Name:       "x",
		Type:       TypeI32,
		ScopeLevel: 0,
		Line:       1,
		Column:     1,
		Filename:   "test.uya",
	}
	st.AddSymbol(symbol0)

	symbol1 := &Symbol{
		Name:       "y",
		Type:       TypeI64,
		ScopeLevel: 1,
		Line:       2,
		Column:     1,
		Filename:   "test.uya",
	}
	st.AddSymbol(symbol1)

	// Remove symbols in scope 1
	st.RemoveSymbolsInScope(1)

	// Symbol in scope 0 should still exist
	found := st.LookupSymbol("x", 0)
	if found == nil {
		t.Error("Expected to find symbol 'x' in scope 0")
	}

	// Symbol in scope 1 should be removed
	found = st.LookupSymbol("y", 1)
	if found != nil {
		t.Error("Expected symbol 'y' to be removed")
	}
}
