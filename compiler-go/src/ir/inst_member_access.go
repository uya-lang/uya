package ir

// MemberAccessInst 表示成员访问指令（obj.field）
type MemberAccessInst struct {
	BaseInst
	Dest     string // 目标变量名
	Object   Inst   // 对象表达式
	FieldName string // 字段名
}

// Type 返回指令类型
func (m *MemberAccessInst) Type() InstType {
	return InstMemberAccess
}

// NewMemberAccessInst 创建一个成员访问指令
func NewMemberAccessInst(dest string, object Inst, fieldName string) *MemberAccessInst {
	return &MemberAccessInst{
		BaseInst:  BaseInst{id: -1},
		Dest:      dest,
		Object:    object,
		FieldName: fieldName,
	}
}

