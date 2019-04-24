package corporation

import (
	"fmt"
	"sync/atomic"
)

type Job struct {
	index         int64
	left, right   float64
	operationType OperationType
	result        *Product
}

func (j Job) String() string {
	return fmt.Sprintf("Job[%d]{%f %c %f = %v}", j.index, j.left, j.operationType, j.right, j.result)
}

var jobIndexCounter int64 = 0

func newJob(left, right float64, operationType OperationType) Job {
	return Job{
		index:         atomic.AddInt64(&jobIndexCounter, 1),
		left:          left,
		right:         right,
		operationType: operationType,
	}
}

var productIndexCounter int64 = 0

type Product struct {
	index int64
	value float64
}

type OperationType rune

type Operation interface {
	getType() OperationType
	perform(left, right float64) Product
}

type Addition struct{}

func (Addition) getType() OperationType { return '+' }

func (Addition) perform(left, right float64) Product {
	return Product{atomic.AddInt64(&productIndexCounter, 1), left + right}
}

func (Addition) String() string {
	return "\"+\""
}

type Subtraction struct{}

func (Subtraction) getType() OperationType { return '-' }

func (Subtraction) perform(left, right float64) Product {
	return Product{atomic.AddInt64(&productIndexCounter, 1), left - right}
}

func (Subtraction) String() string {
	return "\"-\""
}

type Multiplication struct{}

func (Multiplication) getType() OperationType { return '*' }

func (Multiplication) perform(left, right float64) Product {
	return Product{atomic.AddInt64(&productIndexCounter, 1), left * right}
}

func (Multiplication) String() string {
	return "\"*\""
}

var operationTypes = []OperationType{
	'+',
	// '-',
	'*',
}

var jobExecutorConstructors = []func() Operation{
	func() Operation { return Addition{} },
	func() Operation { return Subtraction{} },
	func() Operation { return Multiplication{} },
}
