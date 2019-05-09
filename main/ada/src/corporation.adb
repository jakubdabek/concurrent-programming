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

   task body Work_Station_Task is
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

            if My_Constants.Get_Work_Station_Break_Event(Seed) then
               Logging.L.Log("Machine[" & Index'Image & " ]: Malfunction!!");
               Malfunction:
               loop
                  select
                     accept Use_Work_Station (Job : in out Jobs.JobT) do
                        Job.Product := null;
                     end Use_Work_Station;
                  or
                     accept Repair do
                        Logging.L.Log("Machine[" & Index'Image & " ]: Repaired");
                     end Repair;
                     exit Malfunction;
                  end select;
               end loop Malfunction;
            end if;
         or
            delay 5.0;
            Logging.L.Log("Machine[" & Index'Image & " ]: Working");
         end select;
      end loop;
   exception
      when Error: others =>
         New_Line(3);
         Put ("Unexpected exception: ");
         Put_Line (Exception_Information(Error));

   end Work_Station_Task;

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

   task body Repair_Service_Task is
      task type Service_Worker_Task(Index : Natural) is
         entry Send_To_Work_Station (Operation_Type_In : Jobs.OperationT; Index_In : Natural; Work_Station_In : Work_Station_Ptr);
      end Service_Worker_Task;
      task body Service_Worker_Task is
         Operation_Type : Jobs.OperationT;
         Work_Station_Index : Natural;
         Work_Station : Work_Station_Ptr;
      begin
         loop
            accept Send_To_Work_Station (Operation_Type_In : Jobs.OperationT; Index_In : Natural; Work_Station_In : Work_Station_Ptr) do
               Operation_Type := Operation_Type_In;
               Work_Station_Index := Index_In;
               Work_Station := Work_Station_In;
            end Send_To_Work_Station;

            delay My_Constants.Get_Repair_Worker_Travel_Time(Seed);
            Logging.L.Log("Repairman[" & Index'Image & "]: Repairing: " & Operation_Type'Image & Work_Station_Index'Image);

            select
               Work_Station.Repair;
               Logging.L.Log("Repairman[" & Index'Image & "]: Repair successful: " & Operation_Type'Image & Work_Station_Index'Image);
               Report_Repair(Index, Operation_Type, Work_Station_Index, True);
            or
               delay 1.0;
               Logging.L.Log("Repairman[" & Index'Image & "]: Repair infeasible: " & Operation_Type'Image & Work_Station_Index'Image);
               Report_Repair(Index, Operation_Type, Work_Station_Index, False);
            end select;
         end loop;
      exception
         when Error: others =>
            New_Line(3);
            Put ("Unexpected exception: ");
            Put_Line (Exception_Information(Error));
      end Service_Worker_Task;
      type Service_Worker_Task_Ptr is access all Service_Worker_Task;

      type Service_Worker_Info is record
         Busy : Boolean := False;
         Service_Worker : Service_Worker_Task_Ptr;
      end record;

      type Service_Workers_Array is array(1..My_Constants.NumberOfRepairWorkers) of Service_Worker_Info;

      type Work_Station_Status is record
         Working : Boolean := True;
         Service_Sent : Boolean := False;
      end record;

      type Work_Station_Status_Ptr is access all Work_Station_Status;
      type Work_Station_Status_Array is array(1..My_Constants.NumberOfWorkStations) of Work_Station_Status_Ptr;
      type Work_Station_Status_Types is array(Jobs.OperationT) of Work_Station_Status_Array;

      Work_Stations : Work_Station_Types_Ptr;
      Work_Station_Statuses : Work_Station_Status_Types;
      Service_Workers : Service_Workers_Array;

      function Send_Repairman (T : Jobs.OperationT; W : Natural) return Boolean is
      begin
         for I in Service_Workers'Range loop
            if not Service_Workers(I).Busy then
               Service_Workers(I).Busy := True;
               Service_Workers(I).Service_Worker.Send_To_Work_Station(T, W, Work_Stations(T)(W));

               return True;
            end if;
         end loop;

         return False;
      end Send_Repairman;
   begin
      accept Start (Work_Stations_In : in Work_Station_Types_Ptr) do
         Work_Stations := Work_Stations_In;
         for I in Service_Workers'Range loop
            Service_Workers(I).Service_Worker := new Service_Worker_Task(I);
         end loop;
         for T in Work_Station_Statuses'Range loop
            for W in Work_Station_Statuses(T)'Range loop
               Work_Station_Statuses(T)(W) := new Work_Station_Status;
            end loop;
         end loop;
      end Start;

      loop
         select
            accept Report_Malfunction (Operation_Type : in Jobs.OperationT; Index : in Natural) do
               Logging.L.Log("Service: New malfunction report: " & Operation_Type'Image & Index'Image);
               Work_Station_Statuses(Operation_Type)(Index).Working := False;
            end Report_Malfunction;
         or
            accept Report_Repair (Service_Worker_Index : Natural;
                                  Operation_Type : Jobs.OperationT;
                                  Work_Station_Index : Natural;
                                  Successful : Boolean
                                 ) do
               Service_Workers(Service_Worker_Index).Busy := False;
               if Successful then
                  Work_Station_Statuses(Operation_Type)(Work_Station_Index).Working := True;
                  Work_Station_Statuses(Operation_Type)(Work_Station_Index).Service_Sent := False;
                  Logging.L.Log("Service: Station repaired: " & Operation_Type'Image & Work_Station_Index'Image);
               end if;
            end Report_Repair;
         end select;

         Outer:
         for T in Work_Station_Statuses'Range loop
            for W in Work_Station_Statuses(T)'Range loop
               if not Work_Station_Statuses(T)(W).Working and then not Work_Station_Statuses(T)(W).Service_Sent then
                  if Send_Repairman(T, W) then
                     Logging.L.Log("Service: Service sent: " & T'Image & W'Image);
                     Work_Station_Statuses(T)(W).Service_Sent := True;
                  else
                     Logging.L.Log("Service: No free workers");
                     exit Outer;
                  end if;
               end if;
            end loop;
         end loop Outer;

      end loop;
   exception
      when Error: others =>
         New_Line(3);
         Put ("Unexpected exception: ");
         Put_Line (Exception_Information(Error));
   end Repair_Service_Task;

   task body Worker_Task is
      Index : Natural;
      Patience : Boolean;
      JobQueue : JobQueue_Task_Access;
      Work_Stations : Work_Station_Types_Ptr;
      ProductStorage : ProductStorage_Task_Access;
      Repair_Service : Repair_Service_Task_Ptr;
      Jobs_Done : Concurrent.Counter_Ptr;
      Job : Jobs.JobT;
   begin
      accept Start (IndexIn : in Natural;
                    Patience_In : in Boolean;
                    Jobs_Done_In : in Concurrent.Counter_Ptr;
                    JobQueueIn : in JobQueue_Task_Access;
                    Work_Stations_In : in Work_Station_Types_Ptr;
                    ProductStorageIn : in ProductStorage_Task_Access;
                    Repair_Service_In : in Repair_Service_Task_Ptr
                   ) do
         Index := IndexIn;
         Patience := Patience_In;
         JobQueue := JobQueueIn;
         Work_Stations := Work_Stations_In;
         ProductStorage := ProductStorageIn;
         Repair_Service := Repair_Service_In;
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
            use type Jobs.Product_Ptr;
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

               if Done and then Job.Product = null then
                  Logging.L.Log(" Worker[" & Index'Image & " ]: reporting malfunction of machine[" & Job.OperationType'Image & "," & N'Image & "]");
                  Repair_Service.Report_Malfunction(Job.OperationType, N);
                  delay My_Constants.Get_Worker_Sleep_Time(Seed);
                  Done := False;
               end if;
            end loop;
         end;

         Jobs_Done.Increment;
         Logging.L.Log(" Worker[" & Index'Image & " ]: Job done: " & Jobs.Product_Image(Job.Product.all));
         ProductStorage.New_Product(Product => Job.Product.all);
      end loop;
   exception
      when Error: others =>
         New_Line(3);
         Put ("Unexpected exception: ");
         Put_Line (Exception_Information(Error));
   end Worker_Task;

   task body WorkerT is
      Jobs_Done : Concurrent.Counter_Ptr := new Concurrent.Counter;
      T : Worker_Task;
   begin
      accept Start(JobQueueIn : in JobQueue_Task_Access;
                   Work_Stations : in Work_Station_Types_Ptr;
                   ProductStorageIn : in ProductStorage_Task_Access;
                   Repair_Service_In : in Repair_Service_Task_Ptr
                  ) do
         T.Start(Index, Patience, Jobs_Done, JobQueueIn, Work_Stations, ProductStorageIn, Repair_Service_In);
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
