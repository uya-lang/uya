package ir

// GotoInst 表示goto指令
type GotoInst struct {
	BaseInst
	Label string // 目标标签名
}

// Type 返回指令类型
func (g *GotoInst) Type() InstType {
	return InstGoto
}

// NewGotoInst 创建一个goto指令
func NewGotoInst(label string) *GotoInst {
	return &GotoInst{
		BaseInst: BaseInst{id: -1},
		Label:    label,
	}
}

