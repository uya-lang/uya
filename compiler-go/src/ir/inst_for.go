package ir

// ForInst 表示 for 循环指令
type ForInst struct {
	BaseInst
	Iterable   Inst   // 可迭代对象表达式
	IndexRange Inst   // 索引范围表达式（可选）
	ItemVar    string // 项变量名
	IndexVar   string // 索引变量名（可选）
	Body       []Inst // 循环体的指令列表
}

// Type 返回指令类型
func (f *ForInst) Type() InstType {
	return InstFor
}

// NewForInst 创建一个 for 循环指令
func NewForInst(iterable Inst, indexRange Inst, itemVar string, indexVar string, body []Inst) *ForInst {
	return &ForInst{
		BaseInst:   BaseInst{id: -1},
		Iterable:   iterable,
		IndexRange: indexRange,
		ItemVar:    itemVar,
		IndexVar:   indexVar,
		Body:       body,
	}
}

