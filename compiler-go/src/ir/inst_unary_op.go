package ir

// UnaryOpInst 表示一元运算指令
type UnaryOpInst struct {
	BaseInst
	Dest    string // 目标变量名
	Op      Op     // 操作符
	Operand Inst   // 操作数
}

// Type 返回指令类型
func (u *UnaryOpInst) Type() InstType {
	return InstUnaryOp
}

// NewUnaryOpInst 创建一个一元运算指令
func NewUnaryOpInst(dest string, op Op, operand Inst) *UnaryOpInst {
	return &UnaryOpInst{
		BaseInst: BaseInst{id: -1},
		Dest:     dest,
		Op:       op,
		Operand:  operand,
	}
}

