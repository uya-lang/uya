package checker

// Type represents a type in the type system
// This is a temporary type definition until IR module is implemented
// TODO: Replace with IRType from ir module when available
type Type int

// Type constants - matching IRType from ir.h
// These will be replaced when IR module is implemented
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
	TypeErrorUnion
)

// Symbol represents a symbol in the symbol table
type Symbol struct {
	Name              string
	Type              Type
	IsMut             bool
	IsConst           bool
	IsInitialized     bool
	IsModified        bool
	ScopeLevel        int
	Line              int
	Column            int
	Filename          string
	OriginalTypeName  string // For user-defined types like structs
	ArraySize         int    // Array size (-1 means not an array or unknown size)
	ArrayElementType  Type   // Array element type (only valid when Type is TypeArray)
	TupleElementCount int    // Tuple element count (-1 means not a tuple or unknown)
}

// SymbolTable represents a symbol table
type SymbolTable struct {
	symbols []*Symbol
}

// ScopeStack represents a scope stack for managing scopes
type ScopeStack struct {
	levels      []int
	currentLevel int
}

// NewSymbolTable creates a new symbol table
func NewSymbolTable() *SymbolTable {
	return &SymbolTable{
		symbols: make([]*Symbol, 0, 32),
	}
}

// AddSymbol adds a symbol to the symbol table
func (st *SymbolTable) AddSymbol(symbol *Symbol) {
	st.symbols = append(st.symbols, symbol)
}

// LookupSymbol looks up a symbol by name in the current scope and parent scopes
// Returns the symbol if found, nil otherwise
func (st *SymbolTable) LookupSymbol(name string, currentScope int) *Symbol {
	// Search from the end (most recent symbols) to the beginning
	// This ensures we find the symbol in the innermost scope first
	for i := len(st.symbols) - 1; i >= 0; i-- {
		sym := st.symbols[i]
		if sym.Name == name && sym.ScopeLevel <= currentScope {
			return sym
		}
	}
	return nil
}

// RemoveSymbolsInScope removes all symbols in the specified scope
func (st *SymbolTable) RemoveSymbolsInScope(scopeLevel int) {
	// Remove symbols from the end (most recent) until we find one not in this scope
	for len(st.symbols) > 0 {
		last := st.symbols[len(st.symbols)-1]
		if last.ScopeLevel == scopeLevel {
			st.symbols = st.symbols[:len(st.symbols)-1]
		} else {
			break
		}
	}
}

// NewScopeStack creates a new scope stack
func NewScopeStack() *ScopeStack {
	return &ScopeStack{
		levels:       make([]int, 0, 16),
		currentLevel: 0,
	}
}

// EnterScope enters a new scope
func (ss *ScopeStack) EnterScope() int {
	ss.currentLevel++
	ss.levels = append(ss.levels, ss.currentLevel)
	return ss.currentLevel
}

// ExitScope exits the current scope and returns the previous scope level
func (ss *ScopeStack) ExitScope() int {
	if len(ss.levels) == 0 {
		return 0
	}
	ss.levels = ss.levels[:len(ss.levels)-1]
	if len(ss.levels) > 0 {
		ss.currentLevel = ss.levels[len(ss.levels)-1]
	} else {
		ss.currentLevel = 0
	}
	return ss.currentLevel
}

// CurrentScope returns the current scope level
func (ss *ScopeStack) CurrentScope() int {
	return ss.currentLevel
}

// FunctionSignature represents a function signature
type FunctionSignature struct {
	Name        string
	ParamTypes  []Type
	ReturnType  Type
	IsExtern    bool
	HasVarargs  bool
	Line        int
	Column      int
	Filename    string
}

// FunctionTable represents a function table
type FunctionTable struct {
	functions []*FunctionSignature
}

// NewFunctionTable creates a new function table
func NewFunctionTable() *FunctionTable {
	return &FunctionTable{
		functions: make([]*FunctionSignature, 0, 32),
	}
}

// AddFunction adds a function signature to the function table
func (ft *FunctionTable) AddFunction(sig *FunctionSignature) {
	ft.functions = append(ft.functions, sig)
}

// LookupFunction looks up a function by name
func (ft *FunctionTable) LookupFunction(name string) *FunctionSignature {
	for _, fn := range ft.functions {
		if fn.Name == name {
			return fn
		}
	}
	return nil
}

