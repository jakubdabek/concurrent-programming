with Ada.Text_IO; use Ada.Text_IO;
with Corporation; with Jobs;
with Ada.Containers.Vectors;
with Ada.Numerics.Float_Random;
with Ada.Calendar;
with Ada.Command_Line;
with Logging;
with Concurrent;
with My_Constants;

procedure Main is
   Queue : Corporation.JobQueue_Task_Access := new Jobs.JobQueue_Task(Max_Size => 10);
   Storage : Corporation.ProductStorage_Task_Access := new Jobs.ProductStorage_Task(Max_Size => 10);

   CEO : Corporation.CEO_Task;
   type WorkerArray is array(1..My_Constants.NumberOfWorkers) of Corporation.Worker_Task;
   Workers : WorkerArray;

   Verbose : Boolean := False;
   type UIA is access all Logging.UserInteractor;
   UserInteractor : UIA;

   procedure Spawn_Clients is
      type Client_Task_Access is access all Corporation.Client_Task;
      --package Clients is new Ada.Containers.Vectors(Natural, Client_Task_Access);
      Client : Client_Task_Access;

      package Rand renames Ada.Numerics.Float_Random;
      Seed : Rand.Generator;
      Sem : Concurrent.Semaphore_Access := new Concurrent.Semaphore(My_Constants.ClientCapacity);
   begin
      Rand.Reset(Seed);
      loop
         Sem.Wait;
         delay My_Constants.Get_Client_Arrival_Time(Seed);
         Client := new Corporation.Client_Task;
         Client.Start(Sem, Storage);
      end loop;
   end Spawn_Clients;

begin

   if Ada.Command_Line.Argument_Count > 0 then
      Verbose := Ada.Command_Line.Argument(1) = "-v";
   end if;
   Logging.L.Start(Verbose);
   if not Verbose then
      UserInteractor := new Logging.UserInteractor;
      UserInteractor.Start(Queue, Storage);
   end if;

   CEO.Start(Corporation.JobQueue_Task_Access(Queue));
   for W in Workers'Range loop
      Workers(W).Start(Natural(W), Queue, Storage);
   end loop;

   Spawn_Clients;

end Main;
