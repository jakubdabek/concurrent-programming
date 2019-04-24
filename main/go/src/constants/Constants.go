package constants

import (
	"math/rand"
	"time"
)

const LogIntroductionLength = 12

const (
	NumberOfWorkers      = 3
	JobQueueCapacity     = 5
	StorageCapacity      = 20
	ClientCapacity       = 4
	NumberOfWorkStations = 3
)

const PatientWorkerBirthRate = 0.3

const (
	WorkerSleepTimeMin, WorkerSleepTimeMax     = 3000, 8000
	ImpatientWorkerAttentionSpan               = 200
	CEOSleepTimeMin, CEOSleepTimeMax           = 1500, 3000
	JobExecutionTimeMin, JobExecutionTimeMax   = 3000, 4500
	ClientArrivalTimeMin, ClientArrivalTimeMax = 1200, 10000
)

var rng = rand.New(rand.NewSource(42))

func myRand(min, max float64) time.Duration {
	return time.Duration(min+rng.Float64()*(max-min)) * time.Millisecond
}

func WorkerSleepTime() time.Duration {
	return myRand(WorkerSleepTimeMin, WorkerSleepTimeMax)
}
func JobExecutionTime() time.Duration {
	return myRand(JobExecutionTimeMin, JobExecutionTimeMax)
}
func JobCreationTime() time.Duration {
	return myRand(CEOSleepTimeMin, CEOSleepTimeMax)
}
func ClientArrivalTime() time.Duration {
	return myRand(ClientArrivalTimeMin, ClientArrivalTimeMax)
}
