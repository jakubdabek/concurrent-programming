with Jobs;
with Concurrent;
with My_Constants;

package Corporation is

   type JobQueue_Task_Access is access all Jobs.JobQueue_Task;
   type ProductStorage_Task_Access is access all Jobs.ProductStorage_Task;

   task type CEO_Task is
      entry Start(JobQueueIn : in JobQueue_Task_Access);
   end CEO_Task;

   task type Work_Station_Task(Index : Natural; Operation_Type : Jobs.OperationT; Operation_Val : Jobs.Operation_Ptr) is
      entry Use_Work_Station(Job : in out Jobs.JobT);
      entry Repair;
   end Work_Station_Task;

   type Work_Station_Ptr is access all Work_Station_Task;
   type Work_Station_Array is array(1..My_Constants.NumberOfWorkStations) of Work_Station_Ptr;
   type Work_Station_Types is array(Jobs.OperationT) of Work_Station_Array;
   type Work_Station_Types_Ptr is access all Work_Station_Types;

   function Use_Work_Station1(S : Work_Station_Ptr; Job : in out Jobs.JobT) return Boolean;
   function Use_Work_Station2(S : Work_Station_Ptr; Job : in out Jobs.JobT; timeout : Duration) return Boolean;

   task type Repair_Service_Task is
      entry Start (Work_Stations_In : in Work_Station_Types_Ptr);
      entry Report_Malfunction (Operation_Type : Jobs.OperationT; Index : Natural);
   private
      entry Report_Repair (Service_Worker_Index : Natural;
                           Operation_Type : Jobs.OperationT;
                           Work_Station_Index : Natural;
                           Successful : Boolean
                          );
   end Repair_Service_Task;
   type Repair_Service_Task_Ptr is access all Repair_Service_Task;

   task type Worker_Task is
      entry Start (IndexIn : in Natural;
                   Patience_In : in Boolean;
                   Jobs_Done_In : in Concurrent.Counter_Ptr;
                   JobQueueIn : in JobQueue_Task_Access;
                   Work_Stations_In : in Work_Station_Types_Ptr;
                   ProductStorageIn : in ProductStorage_Task_Access;
                   Repair_Service_In : in Repair_Service_Task_Ptr
                  );
   end Worker_Task;
   type Worker_Task_Ptr is access all Worker_Task;

   task type WorkerT(Index : Natural; Patience : Boolean) is
      entry Start(JobQueueIn : in JobQueue_Task_Access;
                  Work_Stations : in Work_Station_Types_Ptr;
                  ProductStorageIn : in ProductStorage_Task_Access;
                  Repair_Service_In : in Repair_Service_Task_Ptr
                 );
      entry Get_Jobs_Done(Jobs_Done_Out : out Natural);
   end WorkerT;

   type Worker_Ptr is access all WorkerT;
   type WorkerArray is array(1..My_Constants.NumberOfWorkers) of Corporation.Worker_Ptr;
   type WorkerArray_Ptr is access all WorkerArray;

   task type Client_Task is
      entry Start(Semaphore : Concurrent.Semaphore_Access; ProductStorageIn : in ProductStorage_Task_Access);
   end Client_Task;

end Corporation;
