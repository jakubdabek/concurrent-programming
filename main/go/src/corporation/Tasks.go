package corporation

import (
	"constants"
	"fmt"
	"math/rand"
	"sync"
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
	job             *Job
	responseChannel chan *Job
}

type privateWorkStation struct {
	operation     Operation
	waitQueue     chan useWorkStationOp
	repairChannel chan bool
}

type WorkStation struct {
	index int64
	privateWorkStation
}

func NewWorkStation(index int64, operation Operation) *WorkStation {
	return &WorkStation{
		index,
		privateWorkStation{
			operation:     operation,
			waitQueue:     make(chan useWorkStationOp),
			repairChannel: make(chan bool),
		},
	}
}

func timeoutChannel(duration *time.Duration) <-chan time.Time {
	if duration != nil {
		return time.After(*duration)
	}
	return nil
}

func (workStation *WorkStation) Use(job *Job, timeout *time.Duration) (*Job, bool) {
	op := useWorkStationOp{job, make(chan *Job)}
	select {
	case workStation.waitQueue <- op:
		return <-op.responseChannel, false
	case <-timeoutChannel(timeout):
		return nil, true
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

		if rng.Float64() < constants.WorkStationBreakChance {
			logger.Log(fmt.Sprintf("%*s %*d: malfunction",
				constants.LogIntroductionLength-4,
				"Station",
				3,
				workStation.index))

			for {
				select {
				case op := <-workStation.waitQueue:
					logger.Log(fmt.Sprintf("%*s %*d: got new job to do: %v, but there was a malfunction",
						constants.LogIntroductionLength-4,
						"Station",
						3,
						workStation.index,
						op.job))
					op.responseChannel <- nil
				case <-workStation.repairChannel:
					logger.Log(fmt.Sprintf("%*s %*d: repaired",
						constants.LogIntroductionLength-4,
						"Station",
						3,
						workStation.index))
					goto AfterMalfunction
				}
			}
		AfterMalfunction:
		}
	}
}

type serviceWorker struct {
	id   int64
	busy bool
}

type completionReport struct {
	malfunction *malfunctionReport
	worker      *serviceWorker
}

func (worker *serviceWorker) repair(logger *Logger, report *malfunctionReport, machine *WorkStation, completionChannel chan completionReport) {
	time.Sleep(constants.RepairWorkerTravelTime())
	logger.Log(fmt.Sprintf("%*s %*d: repairing: %v", constants.LogIntroductionLength-4, "Repairman", 3, worker.id, report))
	select {
	case machine.repairChannel <- true:
		logger.Log(fmt.Sprintf("%*s %*d: repair done: %v", constants.LogIntroductionLength-4, "Repairman", 3, worker.id, report))
		completionChannel <- completionReport{report, worker}
	case <-time.After(1000):
		logger.Log(fmt.Sprintf("%*s %*d: repair infeasible: %v", constants.LogIntroductionLength-4, "Repairman", 3, worker.id, report))
		completionChannel <- completionReport{nil, worker}
	}
}

type malfunctionReport struct {
	operationType OperationType
	index         int64
}

func (rep malfunctionReport) String() string {
	return fmt.Sprintf("{%c %d}", rep.operationType, rep.index)
}

type workStationStatus struct {
	working     bool
	serviceSent bool
}

type privateRepairService struct {
	serviceWorkers      []*serviceWorker
	workStations        map[OperationType][]*WorkStation
	workStationStatuses map[OperationType][]workStationStatus
	pendingReports      chan malfunctionReport
}

type RepairService struct {
	privateRepairService
}

func NewRepairService(numberOfWorkers int64, machines map[OperationType][]*WorkStation) *RepairService {
	statuses := make(map[OperationType][]workStationStatus, len(machines))
	for k, v := range machines {
		statuses[k] = make([]workStationStatus, len(v))
		for i := range statuses[k] {
			statuses[k][i].working = true
			statuses[k][i].serviceSent = false
		}
	}
	serviceWorkers := make([]*serviceWorker, numberOfWorkers)
	for i := range serviceWorkers {
		serviceWorkers[i] = &serviceWorker{int64(i), false}
	}
	return &RepairService{
		privateRepairService{
			serviceWorkers:      serviceWorkers,
			workStations:        machines,
			workStationStatuses: statuses,
			pendingReports:      make(chan malfunctionReport, 10),
		},
	}
}

func (service *RepairService) ReportMalfunction(operationType OperationType, index int64) {
	service.pendingReports <- malfunctionReport{operationType, index}
}

func (service *RepairService) sendWorker(logger *Logger, operationType OperationType, index int64, completionChannel chan completionReport) bool {
	for _, w := range service.serviceWorkers {
		if !w.busy {
			w.busy = true
			go w.repair(logger, &malfunctionReport{operationType, index}, service.workStations[operationType][index], completionChannel)
			return true
		}
	}

	return false
}

func (service *RepairService) Run(logger *Logger) {
	completionChannel := make(chan completionReport)
	for {
		select {
		case newReport := <-service.pendingReports:
			logger.Log(fmt.Sprintf("%*s: new report: %v", constants.LogIntroductionLength, "Service", newReport))
			service.workStationStatuses[newReport.operationType][newReport.index].working = false
		case completedReport := <-completionChannel:
			completedReport.worker.busy = false
			malRep := completedReport.malfunction
			if malRep != nil {
				service.workStationStatuses[malRep.operationType][malRep.index].working = true
				service.workStationStatuses[malRep.operationType][malRep.index].serviceSent = false
				logger.Log(fmt.Sprintf("%*s: station repaired: %v", constants.LogIntroductionLength, "Service", malRep))
			}
		}

		for k, singleTypeStatuses := range service.workStationStatuses {
			for i := range singleTypeStatuses {
				if !singleTypeStatuses[i].working && !singleTypeStatuses[i].serviceSent {
					if service.sendWorker(logger, k, int64(i), completionChannel) {
						logger.Log(fmt.Sprintf("%*s: sent worker to : %c %d", constants.LogIntroductionLength, "Service", k, i))
						singleTypeStatuses[i].serviceSent = true
					} else {
						logger.Log(fmt.Sprintf("%*s: no free workers : %c %d", constants.LogIntroductionLength, "Service", k, i))
						goto NoFreeWorkers
					}
				}
			}
		}
	NoFreeWorkers:
	}
}

type privateWorker struct {
	jobsDone      int64
	jobsDoneMutex sync.Mutex
}

type Worker struct {
	id      int64
	patient bool
	privateWorker
}

func NewWorker(id int64, patient bool) *Worker {
	return &Worker{
		id:      id,
		patient: patient,
	}
}

func (worker *Worker) GetId() int64  { return worker.id }
func (worker *Worker) GetLazy() bool { return worker.patient }

func (worker *Worker) incrementJobsDone() {
	worker.jobsDoneMutex.Lock()
	defer worker.jobsDoneMutex.Unlock()

	worker.jobsDone++
}

func (worker *Worker) GetJobsDone() int64 {
	worker.jobsDoneMutex.Lock()
	defer worker.jobsDoneMutex.Unlock()

	return worker.jobsDone
}

func (worker *Worker) Run(logger *Logger, queue *JobQueue, workStations map[OperationType][]*WorkStation, storage *Storage, service *RepairService) {
	for {
		time.Sleep(constants.WorkerSleepTime())
		myJob := queue.Take()
		logger.Log(fmt.Sprintf("%*s %*d: got new job to do: %v", constants.LogIntroductionLength-4, "Worker", 3, worker.id, myJob))
		appropriateWorkStations := workStations[myJob.operationType]
		var doneJob *Job
		for {
			index := rng.Intn(len(appropriateWorkStations))
			workStation := appropriateWorkStations[index]
			var timeout *time.Duration
			if !worker.patient {
				var tmp time.Duration = constants.ImpatientWorkerAttentionSpan
				timeout = &tmp
			}
			logger.Log(fmt.Sprintf("%*s %*d: waiting to use station: %d", constants.LogIntroductionLength-4, "Worker", 3, worker.id, workStation.index))
			var timedOut bool
			doneJob, timedOut = workStation.Use(&myJob, timeout)
			if doneJob != nil {
				break
			}
			if !timedOut {
				service.ReportMalfunction(myJob.operationType, int64(index))
				time.Sleep(constants.WorkerSleepTime())
			}
		}
		worker.incrementJobsDone()
		logger.Log(fmt.Sprintf("%*s %*d: job done: %v", constants.LogIntroductionLength-4, "Worker", 3, worker.id, doneJob))
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

func (jobQueue *JobQueue) Run(logger *Logger, stateRequestChannel chan<- []Job) {
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

func (storage *Storage) Run(logger *Logger, stateRequestChannel chan<- []Product) {
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
