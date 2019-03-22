package main

import (
	"bufio"
	"constants"
	"fmt"
	"math/rand"
	"os"
	"time"
)

var logger chan string = make(chan string, 100)
const introductionLength = 12
var rng = rand.New(rand.NewSource(42))

type Worker struct{}

func (*Worker) run(index int64, queue <-chan Job, storage *Storage) {
	for {
		time.Sleep(constants.WorkerSleepTime())
		myJob := <-queue
		logger <- fmt.Sprintf("%*s %*d: got new job to do: %#v", introductionLength - 4, "Worker", 3, index, myJob)
		time.Sleep(constants.JobExecutionTime())
		product := myJob.executor.execute(myJob.left, myJob.right)
		logger <- fmt.Sprintf("%*s %*d: job done: %#v", introductionLength - 4, "Worker", 3, index, myJob)
		storage.receiveChannel <- product
		logger <- fmt.Sprintf("%*s %*d: product given to storage: %#v", introductionLength - 4, "Worker", 3, index, product)
	}
}

type CEO struct{}

func (*CEO) run(jobQueue chan<- Job) {
	logger <- "CEO: running"
	for {
		time.Sleep(constants.JobCreationTime())
		exec := jobExecutorConstructors[rng.Intn(len(jobExecutorConstructors))]()
		job := newJob(
			rng.Float64()*1000,
			rng.Float64()*1000,
			exec,
		)
		logger <- fmt.Sprintf("%*s: thought of a new job: %v", introductionLength, "CEO", job)
		jobQueue <- job
	}
}

type Client struct{}

func (*Client) run(index int64, productChannel <-chan Product, doneChannel <-chan bool) {
	logger <- fmt.Sprintf("%*s %*d: buying a product", introductionLength - 4, "Client", 3, index)
	product := <-productChannel
	logger <- fmt.Sprintf("%*s %*d: got product: %#v", introductionLength - 4, "Client", 3, index, product)
	<-doneChannel
}

type JobQueue struct {
	receiveChannel, produceChannel chan Job
	jobs                           []Job
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

func (jobQueue *JobQueue) run(stateRequestChannel chan []Job) {
	for {
		if len(jobQueue.jobs) == 0 {
			select {
			case job := <-jobQueue.receiveChannel:
				jobQueue.jobs = append(jobQueue.jobs, job)
			case stateRequestChannel <- jobQueue.jobs:
				<-stateRequestChannel
			}
		} else {
			select {
			case job := <-maybeJobChannel(len(jobQueue.jobs) < cap(jobQueue.jobs), jobQueue.receiveChannel):
				jobQueue.jobs = append(jobQueue.jobs, job)
			case jobQueue.produceChannel <- jobQueue.jobs[0]:
				popJob(&jobQueue.jobs)
			case stateRequestChannel <- jobQueue.jobs:
				<-stateRequestChannel
			}
		}
	}
}

type Storage struct {
	receiveChannel, produceChannel chan Product
	products                       []Product
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

func (storage *Storage) run(stateRequestChannel chan []Product) {
	for {
		if len(storage.products) == 0 {
			select {
			case prod := <-storage.receiveChannel:
				storage.products = append(storage.products, prod)
			case stateRequestChannel <- storage.products:
				<-stateRequestChannel
			}
		} else {
			index := rng.Intn(len(storage.products))
			select {
			case prod := <-maybeProductChannel(len(storage.products) > cap(storage.products), storage.receiveChannel):
				storage.products = append(storage.products, prod)
			case storage.produceChannel <- storage.products[index]:
				deleteProduct(&storage.products, index)
			case stateRequestChannel <- storage.products:
				<-stateRequestChannel
			}
		}
	}
}

type UserInteractor struct {
	jobQueueStateRequestChannel chan []Job
	storageStateRequestChannel  chan []Product
}

func (userInteractor *UserInteractor) run() {
	scanner := bufio.NewScanner(os.Stdin)
	fmt.Println("Enter 's' for status")
	for scanner.Scan() {
		switch scanner.Text() {
		// case "s":
		// 	fmt.Println("Silent mode engaged")
		// 	verbose = false
		// case "v":
		// 	fmt.Println("Verbose mode engaged")
		// 	verbose = true
		case "s":
			jobs := <-userInteractor.jobQueueStateRequestChannel
			products := <-userInteractor.storageStateRequestChannel
			fmt.Printf("Job queue: %v\nStorage: %v\n", jobs, products)
			fmt.Println("Simulation (mostly) paused, press enter to continue")
			scanner.Scan()
			userInteractor.jobQueueStateRequestChannel<-nil
			userInteractor.storageStateRequestChannel<-nil
		}
		fmt.Println("Enter 's' for status")
	}
}

var verbose = false

func main() {

	if (len(os.Args) < 2) {
		verbose = false
	} else if (os.Args[1] == "-v") {
		verbose = true
	}

	go func() {
		for message := range logger {
			if verbose {
				fmt.Println(message)
			}
		}
	}()

	userInteractor := &UserInteractor{
		jobQueueStateRequestChannel: make(chan []Job),
		storageStateRequestChannel:  make(chan []Product),
	}
	if !verbose {
		go userInteractor.run()
	}

	storage := &Storage{
		receiveChannel: make(chan Product, 3),
		produceChannel: make(chan Product),
		products:       make([]Product, 0, constants.StorageCapacity),
	}

	jobQueue := &JobQueue{
		receiveChannel: make(chan Job, 3),
		produceChannel: make(chan Job),
		jobs:           make([]Job, 0, constants.JobQueueCapacity),
	}

	ceo := CEO{}
	workers := make([]*Worker, constants.NumberOfWorkers)
	for i := range workers {
		workers[i] = &Worker{}
	}
	logger <- "Starting CEO, job queue, and storage"
	go ceo.run(jobQueue.receiveChannel)
	go jobQueue.run(userInteractor.jobQueueStateRequestChannel)
	go storage.run(userInteractor.storageStateRequestChannel)
	logger <- "Starting workers"
	for i, worker := range workers {
		go worker.run(int64(i), jobQueue.produceChannel, storage)
	}

	doneChannel := make(chan bool, constants.ClientCapacity)
	var i int64 = 0
	for {
		time.Sleep(constants.ClientArrivalTime())
		doneChannel<-true
		go new(Client).run(i, storage.produceChannel, doneChannel)
		i++
	}
}
