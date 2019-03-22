with Ada.Numerics.Float_Random;

package My_Constants is 
   
   package Rand renames Ada.Numerics.Float_Random;
   
   NumberOfWorkers : constant := 3;
   JobQueueCapacity : constant := 5;
   StorageCapacity : constant := 20;
   ClientCapacity : constant := 2;


   WorkerSleepTimeMin : constant := 3.0;
   WorkerSleepTimeMax : constant := 8.0;
   function Get_Worker_Sleep_Time (Generator : Rand.Generator) return Duration;
   
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