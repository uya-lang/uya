package ir

// BinaryOpInst 表示二元运算指令
type BinaryOpInst struct {
	BaseInst
	Dest  string // 目标变量名
	Op    Op     // 操作符
	Left  Inst   // 左操作数
	Right Inst   // 右操作数
}

// Type 返回指令类型
func (b *BinaryOpInst) Type() InstType {
	return InstBinaryOp
}

// NewBinaryOpInst 创建一个二元运算指令
func NewBinaryOpInst(dest string, op Op, left, right Inst) *BinaryOpInst {
	return &BinaryOpInst{
		BaseInst: BaseInst{id: -1},
		Dest:     dest,
		Op:       op,
		Left:     left,
		Right:    right,
	}
}

