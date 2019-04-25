with Corporation;

package Logging is

   task type Logger is
      entry Start(VerboseIn : Boolean);
      entry Log(X : String);
   end Logger;
   
   L : Logger;
   
   task type UserInteractor is
      entry Start(JobQueueIn : in Corporation.JobQueue_Task_Access;
                  ProductStorageIn : in Corporation.ProductStorage_Task_Access;
                  WorkersIn : in Corporation.WorkerArray_Ptr);
   end UserInteractor;
   
end Logging;
