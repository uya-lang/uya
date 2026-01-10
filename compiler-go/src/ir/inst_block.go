package ir

// BlockInst 表示代码块指令
type BlockInst struct {
	BaseInst
	Insts []Inst // 块中的指令列表
}

// Type 返回指令类型
func (b *BlockInst) Type() InstType {
	return InstBlock
}

// NewBlockInst 创建一个代码块指令
func NewBlockInst(insts []Inst) *BlockInst {
	return &BlockInst{
		BaseInst: BaseInst{id: -1},
		Insts:    insts,
	}
}

