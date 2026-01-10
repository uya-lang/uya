package checker

import (
	"strconv"

	"github.com/uya/compiler-go/src/lexer"
	"github.com/uya/compiler-go/src/parser"
)

// ConstValueType represents the type of a constant value
type ConstValueType int

const (
	ConstValInt ConstValueType = iota
	ConstValFloat
	ConstValBool
	ConstValNone // Not a constant
)

// ConstValue represents a constant value
type ConstValue struct {
	Type  ConstValueType
	Value struct {
		IntVal   int64
		FloatVal float64
		BoolVal  bool
	}
}

// EvalExpr evaluates a constant expression and stores the result
// Returns true if the expression is a constant, false otherwise
func EvalExpr(expr parser.Expr, result *ConstValue) bool {
	if expr == nil || result == nil {
		return false
	}

	result.Type = ConstValNone

	switch e := expr.(type) {
	case *parser.NumberLiteral:
		// Try to parse as integer first
		intVal, err := strconv.ParseInt(e.Value, 10, 64)
		if err == nil {
			result.Type = ConstValInt
			result.Value.IntVal = intVal
			return true
		}

		// Try to parse as float
		floatVal, err := strconv.ParseFloat(e.Value, 64)
		if err == nil {
			result.Type = ConstValFloat
			result.Value.FloatVal = floatVal
			return true
		}

		return false

	case *parser.BoolLiteral:
		result.Type = ConstValBool
		result.Value.BoolVal = e.Value
		return true

	case *parser.BinaryExpr:
		return evalBinaryExpr(e, result)

	case *parser.UnaryExpr:
		return evalUnaryExpr(e, result)

	default:
		return false
	}
}

// evalBinaryExpr evaluates a binary expression
func evalBinaryExpr(expr *parser.BinaryExpr, result *ConstValue) bool {
	var leftVal, rightVal ConstValue

	leftConst := EvalExpr(expr.Left, &leftVal)
	rightConst := EvalExpr(expr.Right, &rightVal)

	if !leftConst || !rightConst {
		return false
	}

	op := lexer.TokenType(expr.Op)

	// Integer operations
	if leftVal.Type == ConstValInt && rightVal.Type == ConstValInt {
		a := leftVal.Value.IntVal
		b := rightVal.Value.IntVal

		switch op {
		case lexer.TOKEN_PLUS:
			result.Type = ConstValInt
			result.Value.IntVal = a + b
			return true

		case lexer.TOKEN_MINUS:
			result.Type = ConstValInt
			result.Value.IntVal = a - b
			return true

		case lexer.TOKEN_ASTERISK:
			result.Type = ConstValInt
			result.Value.IntVal = a * b
			return true

		case lexer.TOKEN_SLASH:
			if b == 0 {
				return false // Division by zero
			}
			result.Type = ConstValInt
			result.Value.IntVal = a / b
			return true

		case lexer.TOKEN_PERCENT:
			if b == 0 {
				return false // Division by zero
			}
			result.Type = ConstValInt
			result.Value.IntVal = a % b
			return true

		case lexer.TOKEN_EQUAL:
			result.Type = ConstValBool
			result.Value.BoolVal = (a == b)
			return true

		case lexer.TOKEN_NOT_EQUAL:
			result.Type = ConstValBool
			result.Value.BoolVal = (a != b)
			return true

		case lexer.TOKEN_LESS:
			result.Type = ConstValBool
			result.Value.BoolVal = (a < b)
			return true

		case lexer.TOKEN_LESS_EQUAL:
			result.Type = ConstValBool
			result.Value.BoolVal = (a <= b)
			return true

		case lexer.TOKEN_GREATER:
			result.Type = ConstValBool
			result.Value.BoolVal = (a > b)
			return true

		case lexer.TOKEN_GREATER_EQUAL:
			result.Type = ConstValBool
			result.Value.BoolVal = (a >= b)
			return true

		default:
			return false
		}
	}

	// Float operations (convert int to float if needed)
	if leftVal.Type == ConstValFloat || rightVal.Type == ConstValFloat {
		var a, b float64
		if leftVal.Type == ConstValFloat {
			a = leftVal.Value.FloatVal
		} else {
			a = float64(leftVal.Value.IntVal)
		}
		if rightVal.Type == ConstValFloat {
			b = rightVal.Value.FloatVal
		} else {
			b = float64(rightVal.Value.IntVal)
		}

		switch op {
		case lexer.TOKEN_PLUS:
			result.Type = ConstValFloat
			result.Value.FloatVal = a + b
			return true

		case lexer.TOKEN_MINUS:
			result.Type = ConstValFloat
			result.Value.FloatVal = a - b
			return true

		case lexer.TOKEN_ASTERISK:
			result.Type = ConstValFloat
			result.Value.FloatVal = a * b
			return true

		case lexer.TOKEN_SLASH:
			if b == 0.0 {
				return false // Division by zero
			}
			result.Type = ConstValFloat
			result.Value.FloatVal = a / b
			return true

		case lexer.TOKEN_EQUAL:
			result.Type = ConstValBool
			result.Value.BoolVal = (a == b)
			return true

		case lexer.TOKEN_NOT_EQUAL:
			result.Type = ConstValBool
			result.Value.BoolVal = (a != b)
			return true

		case lexer.TOKEN_LESS:
			result.Type = ConstValBool
			result.Value.BoolVal = (a < b)
			return true

		case lexer.TOKEN_LESS_EQUAL:
			result.Type = ConstValBool
			result.Value.BoolVal = (a <= b)
			return true

		case lexer.TOKEN_GREATER:
			result.Type = ConstValBool
			result.Value.BoolVal = (a > b)
			return true

		case lexer.TOKEN_GREATER_EQUAL:
			result.Type = ConstValBool
			result.Value.BoolVal = (a >= b)
			return true

		default:
			return false
		}
	}

	return false
}

// evalUnaryExpr evaluates a unary expression
func evalUnaryExpr(expr *parser.UnaryExpr, result *ConstValue) bool {
	var operandVal ConstValue

	if !EvalExpr(expr.Operand, &operandVal) {
		return false
	}

	op := lexer.TokenType(expr.Op)

	switch op {
	case lexer.TOKEN_MINUS:
		if operandVal.Type == ConstValInt {
			result.Type = ConstValInt
			result.Value.IntVal = -operandVal.Value.IntVal
			return true
		} else if operandVal.Type == ConstValFloat {
			result.Type = ConstValFloat
			result.Value.FloatVal = -operandVal.Value.FloatVal
			return true
		}
		return false

	case lexer.TOKEN_EXCLAMATION:
		if operandVal.Type == ConstValBool {
			result.Type = ConstValBool
			result.Value.BoolVal = !operandVal.Value.BoolVal
			return true
		}
		return false

	default:
		return false
	}
}

// IsConstant checks if an expression is a constant
func IsConstant(expr parser.Expr) bool {
	if expr == nil {
		return false
	}

	switch expr.(type) {
	case *parser.NumberLiteral, *parser.BoolLiteral:
		return true

	case *parser.BinaryExpr:
		e := expr.(*parser.BinaryExpr)
		return IsConstant(e.Left) && IsConstant(e.Right)

	case *parser.UnaryExpr:
		e := expr.(*parser.UnaryExpr)
		return IsConstant(e.Operand)

	default:
		return false
	}
}

// GetIntValue gets the integer value of a constant expression
// Returns 0 if the expression is not a constant or not an integer
func GetIntValue(expr parser.Expr) int64 {
	if expr == nil {
		return 0
	}

	switch e := expr.(type) {
	case *parser.NumberLiteral:
		val, err := strconv.ParseInt(e.Value, 10, 64)
		if err == nil {
			return val
		}
		return 0

	case *parser.BoolLiteral:
		if e.Value {
			return 1
		}
		return 0

	default:
		var result ConstValue
		if EvalExpr(expr, &result) && result.Type == ConstValInt {
			return result.Value.IntVal
		}
		return 0
	}
}

