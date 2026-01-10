package ir

// LabelInst 表示标签指令
type LabelInst struct {
	BaseInst
	Label string // 标签名
}

// Type 返回指令类型
func (l *LabelInst) Type() InstType {
	return InstLabel
}

// NewLabelInst 创建一个标签指令
func NewLabelInst(label string) *LabelInst {
	return &LabelInst{
		BaseInst: BaseInst{id: -1},
		Label:    label,
	}
}

