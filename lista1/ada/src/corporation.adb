with Ada.Text_IO; use Ada.Text_IO;
with My_Constants;
with Ada.Numerics.Float_Random;
with Logging;
with Concurrent;

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
            Job : Jobs.JobT := (Jobs.ValueType(Rand.Random(Seed)*1000.0),
                                Jobs.ValueType(Rand.Random(Seed)*1000.0),
                                Jobs.NewExecutor(Seed));
         begin
            Logging.L.Log("CEO thought of a new job: " & Jobs.Job_Image(Job));
            JobQueue.New_Job(Job => Job);
         end;
      end loop;
   end CEO_Task;

   task body Worker_Task is
      Index : Natural;
      JobQueue : JobQueue_Task_Access;
      ProductStorage : ProductStorage_Task_Access;
      Job : Jobs.JobT;
      Value : Jobs.ValueType;
   begin
      accept Start (IndexIn : in Natural; JobQueueIn : in JobQueue_Task_Access; ProductStorageIn : in ProductStorage_Task_Access) do
         Index := IndexIn;
         JobQueue := JobQueueIn;
         ProductStorage := ProductStorageIn;
      end Start;
      loop
         delay My_Constants.Get_Worker_Sleep_Time(Seed);

         JobQueue.Next_Job(Job);
         Logging.L.Log("Worker[" & Index'Image & " ]: Got new job: " & Jobs.Job_Image(Job));
         Value := Job.Executor.Execute(Job.Left, Job.Right);

         delay My_Constants.Get_Job_Execution_Time(Seed);

         declare
            Product : Jobs.ProductT := Jobs.NewProduct(Value);
         begin
            Logging.L.Log("Worker[" & Index'Image & " ]: Job done: " & Jobs.Product_Image(Product));
            ProductStorage.New_Product(Product => Product);
         end;

      end loop;
   end Worker_Task;

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
