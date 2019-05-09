with Ada.Numerics.Float_Random;

package My_Constants is 
   
   package Rand renames Ada.Numerics.Float_Random;
   
   NumberOfWorkers : constant := 3;
   JobQueueCapacity : constant := 5;
   StorageCapacity : constant := 20;
   ClientCapacity : constant := 2;
   NumberOfWorkStations : constant := 1;
   NumberOfRepairWorkers : constant := 2;
   
   PatientWorkerBirthRate : constant := 0.6;
   function Get_Worker_Patience (Generator : Rand.Generator) return Boolean;
   WorkStationBreakChance : constant := 0.5;
   function Get_Work_Station_Break_Event (Generator : Rand.Generator) return Boolean;
   
   ImpatientWorkerAttentionSpan : constant := 0.2;

   WorkerSleepTimeMin : constant := 3.0;
   WorkerSleepTimeMax : constant := 8.0;
   function Get_Worker_Sleep_Time (Generator : Rand.Generator) return Duration;
   
   RepairWorkerTravelTimeMin : constant := 2.0;
   RepairWorkerTravelTimeMax : constant := 4.0;
   function Get_Repair_Worker_Travel_Time (Generator : Rand.Generator) return Duration;
   
   CEOSleepTimeMin : constant := 1.5;
   CEOSleepTimeMax : constant := 3.0;
   function Get_CEO_Sleep_Time (Generator : Rand.Generator) return Duration;
   
   JobExecutionTimeMin : constant := 3.0;
   JobExecutionTimeMax : constant := 4.5;
   function Get_Job_Execution_Time (Generator : Rand.Generator) return Duration;
   
   ClientArrivalTimeMin : constant := 1.2;
   ClientArrivalTimeMax : constant := 10.0;
   function Get_Client_Arrival_Time (Generator : Rand.Generator) return Duration;
   
end My_Constants;
