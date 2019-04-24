package main

import (
	"bufio"
	"constants"
	. "corporation"
	"fmt"
	"math/rand"
	"os"
	"time"
)

var rng = rand.New(rand.NewSource(42))

type Client struct{}

func (*Client) Run(index int64, logger *Logger, storage *Storage, doneChannel <-chan bool) {
	logger.Log(fmt.Sprintf("%*s %*d: buying a product", constants.LogIntroductionLength-4, "Client", 3, index))
	product := storage.Take()
	logger.Log(fmt.Sprintf("%*s %*d: got product: %#v", constants.LogIntroductionLength-4, "Client", 3, index, product))
	<-doneChannel
}

type UserInteractor struct {
	jobQueueStateRequestChannel chan []Job
	storageStateRequestChannel  chan []Product
}

func (userInteractor *UserInteractor) Run() {
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
		}
		fmt.Println("Enter 's' for status")
	}
}

func main() {
	verbose := false
	if len(os.Args) > 1 && os.Args[1] == "-v" {
		verbose = true
	}

	logger := NewLogger(verbose)
	go logger.Run()

	userInteractor := &UserInteractor{
		jobQueueStateRequestChannel: make(chan []Job),
		storageStateRequestChannel:  make(chan []Product),
	}
	if !verbose {
		go userInteractor.Run()
	}

	storage := NewStorage(constants.StorageCapacity)

	jobQueue := NewJobQueue(constants.JobQueueCapacity)

	ceo := CEO{}
	workers := make([]*Worker, constants.NumberOfWorkers)
	for i := range workers {
		workers[i] = &Worker{}
	}
	logger.Log("Starting CEO, job queue, and storage")
	go ceo.Run(logger, jobQueue)
	go jobQueue.Run(logger, userInteractor.jobQueueStateRequestChannel)
	go storage.Run(logger, userInteractor.storageStateRequestChannel)
	
	machines := make(map[OperationType][]*WorkStation)
	const numWS = constants.NumberOfWorkStations
	additionMachines := make([]*WorkStation, 0, numWS)
	for i := 0; i < numWS; i++ {
		additionMachines = append(additionMachines, NewWorkStation(int64(i), Addition{}))
	}
	machines['+'] = additionMachines
	
	multiplicationMachines := make([]*WorkStation, 0, numWS)
	for i := 0; i < numWS; i++ {
		multiplicationMachines = append(multiplicationMachines, NewWorkStation(int64(i + numWS), Multiplication{}))
	}
	machines['*'] = multiplicationMachines

	logger.Log("Starting machines")
	for _, v := range machines {
		for _, station := range v {
			go station.Run(logger)
		}
	}
	
	logger.Log("Starting workers")
	for i, worker := range workers {
		go worker.Run(int64(i), logger, jobQueue, machines, storage)
	}

	doneChannel := make(chan bool, constants.ClientCapacity)
	var i int64 = 0
	for {
		time.Sleep(constants.ClientArrivalTime())
		doneChannel <- true
		go new(Client).Run(i, logger, storage, doneChannel)
		i++
	}
}
