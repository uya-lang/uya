package ir

// DeferInst 表示 defer 语句指令
type DeferInst struct {
	BaseInst
	Body []Inst // defer 块中的指令列表
}

// Type 返回指令类型
func (d *DeferInst) Type() InstType {
	return InstDefer
}

// NewDeferInst 创建一个 defer 语句指令
func NewDeferInst(body []Inst) *DeferInst {
	return &DeferInst{
		BaseInst: BaseInst{id: -1},
		Body:     body,
	}
}

