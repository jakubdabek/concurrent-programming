with Ada.Text_IO; use Ada.Text_IO;
with My_Constants;
with Ada.Numerics.Float_Random;
with Ada.Numerics.Discrete_Random;
with Logging;
with Concurrent;
with Jobs;
use type Jobs.OperationT;
with Ada.Exceptions;
use Ada.Exceptions;

package body Corporation is
   package Rand renames Ada.Numerics.Float_Random;
   Seed : Rand.Generator;

   task body CEO_Task is
      JobQueue : JobQueue_Task_Access;
   begin
      Rand.Reset(Seed); -- TODO: maybe initialize it another way
      accept Start (JobQueueIn : in JobQueue_Task_Access) do
         JobQueue := JobQueueIn;
      end Start;
      loop
         delay My_Constants.Get_CEO_Sleep_Time(Seed);
         declare
            Job : Jobs.JobT := Jobs.NewJob(Jobs.ValueType(Rand.Random(Seed)*1000.0),
                                           Jobs.ValueType(Rand.Random(Seed)*1000.0),
                                           Jobs.NewOperationType(Seed));
         begin
            Logging.L.Log("CEO thought of a new job: " & Jobs.Job_Image(Job));
            JobQueue.New_Job(Job => Job);
         end;
      end loop;
   end CEO_Task;

   task body Work_Station is
   begin
      Logging.L.Log("Machine[" & Index'Image & " ]: Started");
      loop
         select
            accept Use_Work_Station (Job : in out Jobs.JobT) do
               delay My_Constants.Get_Job_Execution_Time(Seed);
               if Job.OperationType = Operation_Type then
                  Logging.L.Log("Machine[" & Index'Image & " ]: Got new job: " & Jobs.Job_Image(Job));
                  --                 Logging.L.Log("    Machine: Got new job: " & Jobs.Job_Image(Job));
                  Job.Product := Jobs.NewProduct(Operation_Val.Execute(Job.Left, Job.Right));
                  Logging.L.Log("Machine[" & Index'Image & " ]: Job done: " & Jobs.Product_Image(Job.Product.all));
               else
                  Logging.L.Log("Machine[" & Index'Image & " ]: Incorrect type");
               end if;
            end Use_Work_Station;
         or
            delay 5.0;
            Logging.L.Log("Machine[" & Index'Image & " ]: Working");
         end select;
      end loop;
   exception
      when Error: others =>
         Put ("Unexpected exception: ");
         Put_Line (Exception_Information(Error));

   end Work_Station;

   function Use_Work_Station1(S : Work_Station_Ptr; Job : in out Jobs.JobT) return Boolean is
   begin
      Logging.L.Log("patient");
      S.Use_Work_Station(Job);
      return True;
   end Use_Work_Station1;

   function Use_Work_Station2(S : Work_Station_Ptr; Job : in out Jobs.JobT; Timeout : Duration) return Boolean is
   begin
      Logging.L.Log("impatient");
      select
         S.Use_Work_Station(Job);
         return True;
      or
         delay Timeout;
         return False;
      end select;
   end Use_Work_Station2;

   task body Worker_Task is
      Index : Natural;
      JobQueue : JobQueue_Task_Access;
      Work_Stations : Work_Station_Types_Ptr;
      ProductStorage : ProductStorage_Task_Access;
      Jobs_Done : Concurrent.Counter_Ptr;
      Job : Jobs.JobT;
   begin
      accept Start (IndexIn : in Natural; Patience : Boolean; Jobs_Done_In : in Concurrent.Counter_Ptr; JobQueueIn : in JobQueue_Task_Access; Work_Stations_In : in Work_Station_Types_Ptr; ProductStorageIn : in ProductStorage_Task_Access) do
         Index := IndexIn;
         JobQueue := JobQueueIn;
         Work_Stations := Work_Stations_In;
         ProductStorage := ProductStorageIn;
         Jobs_Done := Jobs_Done_In;
      end Start;
      loop
         delay My_Constants.Get_Worker_Sleep_Time(Seed);

         JobQueue.Next_Job(Job);
         Logging.L.Log(" Worker[" & Index'Image & " ]: Got new job: " & Jobs.Job_Image(Job));

         declare
            subtype R is Integer range 1..My_Constants.NumberOfWorkStations;
            package My_Rand is new Ada.Numerics.Discrete_Random(R);
            G : My_Rand.Generator;
            N : Integer;
            WS : Work_Station_Ptr;
            Done : Boolean := False;
         begin
            My_Rand.Reset(G);
            while not Done loop
               N := My_Rand.Random(G);
               Logging.L.Log(" Worker[" & Index'Image & " ]: Trying to reach machine[" & Job.OperationType'Image & "," & N'Image & "]");
               WS := Work_Stations(Job.OperationType)(N);
               Logging.L.Log(" Worker[" & Index'Image & " ]: Chosen machine[" & WS.Operation_Type'Image & "," & WS.Index'Image & "]");
               if Patience then
                  Done := Use_Work_Station1(WS, Job);
               else
                  Done := Use_Work_Station2(WS, Job, My_Constants.ImpatientWorkerAttentionSpan);
               end if;
            end loop;
         end;

         Jobs_Done.Increment;
         Logging.L.Log(" Worker[" & Index'Image & " ]: Job done: " & Jobs.Product_Image(Job.Product.all));
         ProductStorage.New_Product(Product => Job.Product.all);
      end loop;
   end Worker_Task;

   task body WorkerT is
      Jobs_Done : Concurrent.Counter_Ptr := new Concurrent.Counter;
      T : Worker_Task(Patience);
   begin
      accept Start(JobQueueIn : in JobQueue_Task_Access; Work_Stations : in Work_Station_Types_Ptr; ProductStorageIn : in ProductStorage_Task_Access) do
         T.Start(Index, Patience, Jobs_Done, JobQueueIn, Work_Stations, ProductStorageIn);
      end Start;
      loop
         accept Get_Jobs_Done(Jobs_Done_Out : out Natural) do
            Jobs_Done_Out := Jobs_Done.Get_Value;
         end Get_Jobs_Done;
      end loop;
   end WorkerT;

   task body Client_Task is
      ProductStorage : ProductStorage_Task_Access;
      Product : Jobs.ProductT;
      Sem : Concurrent.Semaphore_Access;
   begin
      accept Start (Semaphore : Concurrent.Semaphore_Access; ProductStorageIn : in ProductStorage_Task_Access) do
         Sem := Semaphore;
         ProductStorage := ProductStorageIn;
      end Start;
      Logging.L.Log("     Client: Buying a product");
      ProductStorage.Next_Product(Product);
      Logging.L.Log("     Client: Bought a product: " & Jobs.Product_Image(Product));
      Sem.Signal;
   end Client_Task;

end Corporation;
