package ir

// SubscriptInst 表示数组下标访问指令（arr[index]）
type SubscriptInst struct {
	BaseInst
	Dest  string // 目标变量名
	Array Inst   // 数组表达式
	Index Inst   // 索引表达式
}

// Type 返回指令类型
func (s *SubscriptInst) Type() InstType {
	return InstSubscript
}

// NewSubscriptInst 创建一个数组下标访问指令
func NewSubscriptInst(dest string, array Inst, index Inst) *SubscriptInst {
	return &SubscriptInst{
		BaseInst: BaseInst{id: -1},
		Dest:     dest,
		Array:    array,
		Index:    index,
	}
}

