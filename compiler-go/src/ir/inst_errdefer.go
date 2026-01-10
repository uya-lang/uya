package ir

// ErrDeferInst 表示 errdefer 语句指令
type ErrDeferInst struct {
	BaseInst
	Body []Inst // errdefer 块中的指令列表
}

// Type 返回指令类型
func (e *ErrDeferInst) Type() InstType {
	return InstErrDefer
}

// NewErrDeferInst 创建一个 errdefer 语句指令
func NewErrDeferInst(body []Inst) *ErrDeferInst {
	return &ErrDeferInst{
		BaseInst: BaseInst{id: -1},
		Body:     body,
	}
}

