package corporation

import (
	"constants"
	"fmt"
	"math/rand"
	"time"
)

var rng = rand.New(rand.NewSource(42))

type privateLogger struct {
	verbose        bool
	messageChannel chan string
}

type Logger struct {
	privateLogger
}

func NewLogger(verbose bool) *Logger {
	return &Logger{
		privateLogger{
			verbose:        verbose,
			messageChannel: make(chan string, 100),
		},
	}
}

func (logger *Logger) Run() {
	for message := range logger.messageChannel {
		if logger.verbose {
			fmt.Println(message)
		}
	}
}

func (logger *Logger) Log(s string) {
	logger.messageChannel <- s
}

type CEO struct{}

func (*CEO) Run(logger *Logger, jobQueue *JobQueue) {
	logger.Log("CEO: running")
	for {
		time.Sleep(constants.JobCreationTime())
		operationType := operationTypes[rng.Intn(len(operationTypes))]
		job := newJob(
			rng.Float64()*1000,
			rng.Float64()*1000,
			operationType,
		)
		logger.Log(fmt.Sprintf("%*s: thought of a new job: %v", constants.LogIntroductionLength, "CEO", job))
		jobQueue.Add(job)
	}
}

type useWorkStationOp struct {
	job *Job
	responseChannel chan *Job
}

type privateWorkStation struct {
	operation Operation
	waitQueue chan useWorkStationOp
}

type WorkStation struct {
	index int64
	privateWorkStation
}

func NewWorkStation(index int64, operation Operation) *WorkStation {
	return &WorkStation {
		index,
		privateWorkStation {
			operation: operation,
			waitQueue: make(chan useWorkStationOp),
		},
	}
}

func timeoutChannel(duration *time.Duration) <-chan time.Time {
	if duration != nil {
		return time.After(*duration)
	}
	return nil
}

func (workStation *WorkStation) Use(job *Job, timeout *time.Duration) *Job {
	op := useWorkStationOp { job, make(chan *Job) }
	select {
	case workStation.waitQueue <- op:
		return <-op.responseChannel
	case <-timeoutChannel(timeout):
		return nil
	}
}

func (workStation *WorkStation) Run(logger *Logger) {
	for op := range workStation.waitQueue {
		job := op.job
		if job.operationType != workStation.operation.getType() {
			panic("incorrect job given to station")
		}
		logger.Log(fmt.Sprintf("%*s %*d: got new job to do: %v",
			constants.LogIntroductionLength-4,
			"Station",
			3,
			workStation.index,
			job))
		time.Sleep(constants.JobExecutionTime())
		product := workStation.operation.perform(job.left, job.right)
		job.result = &product
		logger.Log(fmt.Sprintf("%*s %*d: job done: %v",
			constants.LogIntroductionLength-4,
			"Station",
			3,
			workStation.index,
			job))
		op.responseChannel <- job 
	}
}

type Worker struct {

}

func (*Worker) Run(index int64, logger *Logger, queue *JobQueue, workStations map[OperationType][]*WorkStation, storage *Storage, stateRequestChannel chan<-int64) {
	var doneJobs int64 = 0
	for {
		time.Sleep(constants.WorkerSleepTime())
		myJob := queue.Take()
		logger.Log(fmt.Sprintf("%*s %*d: got new job to do: %v", constants.LogIntroductionLength-4, "Worker", 3, index, myJob))
		appropriateWorkStations := workStations[myJob.operationType]
		workStation := appropriateWorkStations[rng.Intn(len(appropriateWorkStations))]
		doneJob := workStation.Use(&myJob, nil)
		logger.Log(fmt.Sprintf("%*s %*d: job done: %v", constants.LogIntroductionLength-4, "Worker", 3, index, doneJob))
		storage.Add(*doneJob.result)
	}
}

type takeJobOp struct {
	responseChannel chan Job
}

type privateJobQueue struct {
	addChannel  chan Job
	takeChannel chan *takeJobOp
	jobs        []Job
}

type JobQueue struct {
	privateJobQueue
}

func NewJobQueue(capacity int) *JobQueue {
	return &JobQueue{
		privateJobQueue{
			addChannel:  make(chan Job),
			takeChannel: make(chan *takeJobOp),
			jobs:        make([]Job, 0, capacity),
		},
	}
}

func (jobQueue *JobQueue) Add(job Job) {
	jobQueue.addChannel <- job
}

func (jobQueue *JobQueue) Take() Job {
	op := &takeJobOp{make(chan Job)}
	jobQueue.takeChannel <- op
	return <-op.responseChannel
}

func popJob(jobs *[]Job) {
	*jobs = (*jobs)[:copy(*jobs, (*jobs)[1:])]
}

func maybeJobChannel(predicate bool, ch chan Job) chan Job {
	if predicate {
		return ch
	}
	return nil
}

func maybeTakeJobOpChannel(predicate bool, ch chan *takeJobOp) chan *takeJobOp {
	if predicate {
		return ch
	}
	return nil
}

func (jobQueue *JobQueue) Run(logger *Logger, stateRequestChannel chan<-[]Job) {
	for {
		select {
		case job := <-maybeJobChannel(len(jobQueue.jobs) < cap(jobQueue.jobs), jobQueue.addChannel):
			logger.Log(fmt.Sprintf("%*s: new job: %v", constants.LogIntroductionLength, "Job Queue", job))
			jobQueue.jobs = append(jobQueue.jobs, job)
		case op := <-maybeTakeJobOpChannel(len(jobQueue.jobs) > 0, jobQueue.takeChannel):
			op.responseChannel <- jobQueue.jobs[0]
			popJob(&jobQueue.jobs)
		case stateRequestChannel <- jobQueue.jobs:
		}
	}
}

type takeProductOp struct {
	responseChannel chan Product
}

type privateStorage struct {
	addChannel  chan Product
	takeChannel chan *takeProductOp
	products    []Product
}

type Storage struct {
	privateStorage
}

func NewStorage(capacity int) *Storage {
	return &Storage{
		privateStorage{
			addChannel:  make(chan Product),
			takeChannel: make(chan *takeProductOp),
			products:    make([]Product, 0, capacity),
		},
	}
}

func (storage *Storage) Add(product Product) {
	storage.addChannel <- product
}

func (storage *Storage) Take() Product {
	op := &takeProductOp{make(chan Product)}
	storage.takeChannel <- op
	return <-op.responseChannel
}

func deleteProduct(products *[]Product, index int) {
	*products = (*products)[:index+copy((*products)[index:], (*products)[index+1:])]
}

func maybeProductChannel(predicate bool, ch chan Product) chan Product {
	if predicate {
		return ch
	}
	return nil
}

func maybeTakeProductOpChannel(predicate bool, ch chan *takeProductOp) chan *takeProductOp {
	if predicate {
		return ch
	}
	return nil
}

func (storage *Storage) Run(logger *Logger, stateRequestChannel chan<-[]Product) {
	for {
		select {
		case prod := <-maybeProductChannel(len(storage.products) < cap(storage.products), storage.addChannel):
			logger.Log(fmt.Sprintf("%*s: new product: %#v", constants.LogIntroductionLength, "Storage", prod))
			storage.products = append(storage.products, prod)
		case op := <-maybeTakeProductOpChannel(len(storage.products) > 0, storage.takeChannel):
			index := rng.Intn(len(storage.products))
			op.responseChannel <- storage.products[index]
			deleteProduct(&storage.products, index)
		case stateRequestChannel <- storage.products:
		}

	}
}
