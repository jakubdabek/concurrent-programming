with Jobs;
with Concurrent;

package Corporation is

   type JobQueue_Task_Access is access all Jobs.JobQueue_Task;
   type ProductStorage_Task_Access is access all Jobs.ProductStorage_Task;

   task type CEO_Task is
      entry Start(JobQueueIn : in JobQueue_Task_Access);
   end CEO_Task;

   task type Worker_Task is
      entry Start(IndexIn : in Natural; JobQueueIn : in JobQueue_Task_Access; ProductStorageIn : in ProductStorage_Task_Access);
   end Worker_Task;

   task type Client_Task is
      entry Start(Semaphore : Concurrent.Semaphore_Access; ProductStorageIn : in ProductStorage_Task_Access);
   end Client_Task;

end Corporation;
