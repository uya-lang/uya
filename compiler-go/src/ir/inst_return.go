package ir

// ReturnInst 表示返回指令
type ReturnInst struct {
	BaseInst
	Value Inst // 返回值（可选，void函数为nil）
}

// Type 返回指令类型
func (r *ReturnInst) Type() InstType {
	return InstReturn
}

// NewReturnInst 创建一个返回指令
func NewReturnInst(value Inst) *ReturnInst {
	return &ReturnInst{
		BaseInst: BaseInst{id: -1},
		Value:    value,
	}
}

