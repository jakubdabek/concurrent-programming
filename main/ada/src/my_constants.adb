package body My_Constants is
   
   function Get_Worker_Patience (Generator : Rand.Generator) return Boolean is
   begin
      return Rand.Random(Generator) > PatientWorkerBirthRate;
   end;
   
   function Get_Worker_Sleep_Time (Generator : Rand.Generator) return Duration is
   begin
      return Duration(WorkerSleepTimeMin + (WorkerSleepTimeMax - WorkerSleepTimeMin) * Rand.Random(Generator));
   end;
   
   function Get_CEO_Sleep_Time (Generator : Rand.Generator) return Duration is
   begin
      return Duration(CEOSleepTimeMin + (CEOSleepTimeMax - CEOSleepTimeMin) * Rand.Random(Generator));
   end;
   
   function Get_Job_Execution_Time (Generator : Rand.Generator) return Duration is
   begin
      return Duration(JobExecutionTimeMin + (JobExecutionTimeMax - JobExecutionTimeMin) * Rand.Random(Generator));
   end;
   
   function Get_Client_Arrival_Time (Generator : Rand.Generator) return Duration is
   begin
      return Duration(ClientArrivalTimeMin + (ClientArrivalTimeMax - ClientArrivalTimeMin) * Rand.Random(Generator));
   end;
   

end My_Constants;
