package codegen

import (
	"fmt"

	"github.com/uya/compiler-go/src/ir"
)

// WriteValue writes the C code representation of an IR instruction value
func (g *Generator) WriteValue(inst ir.Inst) error {
	if inst == nil {
		return g.Write("0")
	}

	switch inst.Type() {
	case ir.InstConstant:
		return g.writeConstant(inst.(*ir.ConstantInst))

	case ir.InstVarDecl:
		return g.writeVarDecl(inst.(*ir.VarDeclInst))

	case ir.InstBinaryOp:
		return g.writeBinaryOp(inst.(*ir.BinaryOpInst))

	case ir.InstUnaryOp:
		return g.writeUnaryOp(inst.(*ir.UnaryOpInst))

	case ir.InstCall:
		return g.writeCall(inst.(*ir.CallInst))

	default:
		// For unsupported types, write a placeholder
		return g.Write("/* TODO: unsupported value type */")
	}
}

// writeConstant writes a constant value
func (g *Generator) writeConstant(inst *ir.ConstantInst) error {
	if inst.Typ == ir.TypePtr {
		// String literal - need to escape and format as C string
		return g.Writef("\"%s\"", escapeString(inst.Value))
	}
	// Numeric or bool literal - write directly
	return g.Write(inst.Value)
}

// writeVarDecl writes a variable reference
func (g *Generator) writeVarDecl(inst *ir.VarDeclInst) error {
	return g.Write(inst.Name)
}

// writeBinaryOp writes a binary operation
func (g *Generator) writeBinaryOp(inst *ir.BinaryOpInst) error {
	if err := g.WriteValue(inst.Left); err != nil {
		return err
	}
	if err := g.Write(" "); err != nil {
		return err
	}
	if err := g.writeOp(inst.Op); err != nil {
		return err
	}
	if err := g.Write(" "); err != nil {
		return err
	}
	return g.WriteValue(inst.Right)
}

// writeUnaryOp writes a unary operation
func (g *Generator) writeUnaryOp(inst *ir.UnaryOpInst) error {
	if err := g.writeOp(inst.Op); err != nil {
		return err
	}
	return g.WriteValue(inst.Operand)
}

// writeCall writes a function call
func (g *Generator) writeCall(inst *ir.CallInst) error {
	if err := g.Writef("%s(", inst.FuncName); err != nil {
		return err
	}
	for i, arg := range inst.Args {
		if i > 0 {
			if err := g.Write(", "); err != nil {
				return err
			}
		}
		if err := g.WriteValue(arg); err != nil {
			return err
		}
	}
	return g.Write(")")
}

// writeOp writes an operator symbol
func (g *Generator) writeOp(op ir.Op) error {
	switch op {
	case ir.OpAdd:
		return g.Write("+")
	case ir.OpSub:
		return g.Write("-")
	case ir.OpMul:
		return g.Write("*")
	case ir.OpDiv:
		return g.Write("/")
	case ir.OpMod:
		return g.Write("%")
	case ir.OpEq:
		return g.Write("==")
	case ir.OpNe:
		return g.Write("!=")
	case ir.OpLt:
		return g.Write("<")
	case ir.OpLe:
		return g.Write("<=")
	case ir.OpGt:
		return g.Write(">")
	case ir.OpGe:
		return g.Write(">=")
	case ir.OpLogicAnd:
		return g.Write("&&")
	case ir.OpLogicOr:
		return g.Write("||")
	case ir.OpBitAnd:
		return g.Write("&")
	case ir.OpBitOr:
		return g.Write("|")
	case ir.OpBitXor:
		return g.Write("^")
	case ir.OpLeftShift:
		return g.Write("<<")
	case ir.OpRightShift:
		return g.Write(">>")
	case ir.OpNeg:
		return g.Write("-")
	case ir.OpNot:
		return g.Write("!")
	case ir.OpBitNot:
		return g.Write("~")
	case ir.OpAddrOf:
		return g.Write("&")
	case ir.OpDeref:
		return g.Write("*")
	default:
		return g.Write("?")
	}
}

// escapeString escapes a string for C code
func escapeString(s string) string {
	result := ""
	for _, r := range s {
		switch r {
		case '\n':
			result += "\\n"
		case '\t':
			result += "\\t"
		case '\r':
			result += "\\r"
		case '\\':
			result += "\\\\"
		case '"':
			result += "\\\""
		case '\'':
			result += "\\'"
		default:
			if r < 32 || r > 126 {
				// Non-printable character - use octal escape
				result += fmt.Sprintf("\\%03o", r)
			} else {
				result += string(r)
			}
		}
	}
	return result
}

