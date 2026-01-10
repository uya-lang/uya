package checker

import (
	"math"
)

// ConstraintType represents the type of a constraint
type ConstraintType int

const (
	ConstraintRange ConstraintType = iota // x >= min && x < max
	ConstraintNonzero                     // x != 0
	ConstraintNotNull                     // ptr != null
	ConstraintInitialized                 // var is initialized
)

// Constraint represents a constraint condition
type Constraint struct {
	Type    ConstraintType
	VarName string

	// Data specific to constraint type
	RangeData struct {
		Min int64 // Range minimum (inclusive)
		Max int64 // Range maximum (exclusive)
	}
}

// ConstraintSet represents a set of constraints
type ConstraintSet struct {
	constraints []*Constraint
}

// NewConstraintSet creates a new constraint set
func NewConstraintSet() *ConstraintSet {
	return &ConstraintSet{
		constraints: make([]*Constraint, 0, 16),
	}
}

// Add adds a constraint to the set
func (cs *ConstraintSet) Add(constraint *Constraint) bool {
	if constraint == nil {
		return false
	}

	// Check if constraint already exists
	existing := cs.Find(constraint.VarName, constraint.Type)
	if existing != nil {
		// If exists, merge for range constraints
		if constraint.Type == ConstraintRange {
			// Take stricter constraint (smaller range)
			if constraint.RangeData.Min > existing.RangeData.Min {
				existing.RangeData.Min = constraint.RangeData.Min
			}
			if constraint.RangeData.Max < existing.RangeData.Max {
				existing.RangeData.Max = constraint.RangeData.Max
			}
		}
		// Don't add duplicate constraint
		return true
	}

	// Add constraint
	cs.constraints = append(cs.constraints, constraint)
	return true
}

// Find finds a constraint by variable name and type
func (cs *ConstraintSet) Find(varName string, constraintType ConstraintType) *Constraint {
	if varName == "" {
		return nil
	}

	for _, c := range cs.constraints {
		if c.Type == constraintType && c.VarName == varName {
			return c
		}
	}

	return nil
}

// Copy creates a copy of the constraint set
func (cs *ConstraintSet) Copy() *ConstraintSet {
	if cs == nil {
		return nil
	}

	copy := NewConstraintSet()
	for _, c := range cs.constraints {
		copy.constraints = append(copy.constraints, cs.copyConstraint(c))
	}

	return copy
}

// copyConstraint creates a copy of a constraint
func (cs *ConstraintSet) copyConstraint(c *Constraint) *Constraint {
	if c == nil {
		return nil
	}

	copy := &Constraint{
		Type:    c.Type,
		VarName: c.VarName,
		RangeData: struct {
			Min int64
			Max int64
		}{
			Min: c.RangeData.Min,
			Max: c.RangeData.Max,
		},
	}

	return copy
}

// Merge merges constraints from another set into this set
func (cs *ConstraintSet) Merge(other *ConstraintSet) {
	if other == nil {
		return
	}

	for _, c := range other.constraints {
		cs.Add(cs.copyConstraint(c))
	}
}

// Constraint creation functions

// NewRangeConstraint creates a range constraint
func NewRangeConstraint(varName string, min, max int64) *Constraint {
	return &Constraint{
		Type:    ConstraintRange,
		VarName: varName,
		RangeData: struct {
			Min int64
			Max int64
		}{
			Min: min,
			Max: max,
		},
	}
}

// NewNonzeroConstraint creates a nonzero constraint
func NewNonzeroConstraint(varName string) *Constraint {
	return &Constraint{
		Type:    ConstraintNonzero,
		VarName: varName,
	}
}

// NewNotNullConstraint creates a not-null constraint
func NewNotNullConstraint(varName string) *Constraint {
	return &Constraint{
		Type:    ConstraintNotNull,
		VarName: varName,
	}
}

// NewInitializedConstraint creates an initialized constraint
func NewInitializedConstraint(varName string) *Constraint {
	return &Constraint{
		Type:    ConstraintInitialized,
		VarName: varName,
	}
}

// Helper constants for range constraints
const (
	MinInt64 = math.MinInt64
	MaxInt64 = math.MaxInt64
)

