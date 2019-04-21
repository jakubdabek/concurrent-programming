package corporation

import (
	"fmt"
	"sync/atomic"
)

type Job struct {
	index       int64
	left, right float64
	executor    JobExecutor
}

func (j Job) String() string {
	return fmt.Sprintf("Job[%d]{%f %v %f}", j.index, j.left, j.executor, j.right)
}

var jobIndexCounter int64 = 0

func newJob(left, right float64, executor JobExecutor) Job {
	return Job{
		index:    atomic.AddInt64(&productIndexCounter, 1),
		left:     left,
		right:    right,
		executor: executor,
	}
}

var productIndexCounter int64 = 0

type Product struct {
	index int64
	value float64
}

type JobExecutor interface {
	execute(left, right float64) Product
}

type Addition struct{}

func (Addition) execute(left, right float64) Product {
	return Product{atomic.AddInt64(&productIndexCounter, 1), left + right}
}

func (Addition) String() string {
	return "\"+\""
}

type Subtraction struct{}

func (Subtraction) execute(left, right float64) Product {
	return Product{atomic.AddInt64(&productIndexCounter, 1), left - right}
}

func (Subtraction) String() string {
	return "\"-\""
}

type Multiplication struct{}

func (Multiplication) execute(left, right float64) Product {
	return Product{atomic.AddInt64(&productIndexCounter, 1), left * right}
}

func (Multiplication) String() string {
	return "\"*\""
}

var jobExecutorConstructors = []func() JobExecutor{
	func() JobExecutor { return Addition{} },
	func() JobExecutor { return Subtraction{} },
	func() JobExecutor { return Multiplication{} },
}
