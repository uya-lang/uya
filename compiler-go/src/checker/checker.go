package checker

import (
	"fmt"
	"os"

	"github.com/uya/compiler-go/src/parser"
)

// ScanPass represents the scan pass phase
type ScanPass int

const (
	ScanPassCollectSignatures ScanPass = 1 // Collect function signatures
	ScanPassCheckBodies       ScanPass = 2 // Check function bodies
)

// TypeChecker represents a type checker
type TypeChecker struct {
	// Error management
	errors []string

	// Symbol table and scopes
	symbolTable *SymbolTable
	scopes      *ScopeStack

	// Function table (stores all function signatures, including extern functions)
	functionTable *FunctionTable

	// Constraints set (for path-sensitive analysis)
	// TODO: Implement constraints system
	// constraints *ConstraintSet

	// Function scope counter (assigns unique scope level to each function)
	functionScopeCounter int

	// Block scope counter (assigns unique scope level to each block, for catch blocks etc.)
	blockScopeCounter int

	// Scan pass: 1 = collect function signatures, 2 = check function bodies
	scanPass ScanPass

	// Current context
	currentLine   int
	currentColumn int
	currentFile   string

	// Program node (for looking up struct declarations etc.)
	programNode *parser.Program
}

// NewTypeChecker creates a new type checker
func NewTypeChecker() *TypeChecker {
	return &TypeChecker{
		errors:               make([]string, 0, 16),
		symbolTable:          NewSymbolTable(),
		scopes:               NewScopeStack(),
		functionTable:        NewFunctionTable(),
		functionScopeCounter: 0,
		blockScopeCounter:    0,
		scanPass:             ScanPassCollectSignatures,
		currentLine:          0,
		currentColumn:        0,
		currentFile:          "",
		programNode:          nil,
	}
}

// AddError adds an error to the error list
func (tc *TypeChecker) AddError(format string, args ...interface{}) {
	errorMsg := fmt.Sprintf(format, args...)
	tc.errors = append(tc.errors, errorMsg)
}

// ErrorCount returns the number of errors
func (tc *TypeChecker) ErrorCount() int {
	return len(tc.errors)
}

// Errors returns all errors
func (tc *TypeChecker) Errors() []string {
	return tc.errors
}

// PrintErrors prints all errors to stderr
func (tc *TypeChecker) PrintErrors() {
	for _, err := range tc.errors {
		fmt.Fprintf(os.Stderr, "%s\n", err)
	}
}

// Check checks the AST and returns true if there are no errors
func (tc *TypeChecker) Check(program *parser.Program) bool {
	if program == nil {
		tc.AddError("program node is nil")
		return false
	}

	// Set program node pointer
	tc.programNode = program

	// Enter global scope
	tc.scopes.EnterScope()

	// First pass: collect all function signatures
	tc.scanPass = ScanPassCollectSignatures
	// TODO: Implement typecheck_node for collecting signatures
	// result := tc.typecheckNode(program)
	// if !result {
	// 	if tc.ErrorCount() > 0 {
	// 		tc.PrintErrors()
	// 	}
	// 	tc.scopes.ExitScope()
	// 	return false
	// }

	// Second pass: check all function bodies
	tc.scanPass = ScanPassCheckBodies
	// TODO: Implement typecheck_node for checking bodies
	// result = tc.typecheckNode(program)

	// Exit global scope
	tc.scopes.ExitScope()

	return tc.ErrorCount() == 0
}

