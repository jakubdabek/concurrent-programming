with Ada.Text_IO; use Ada.Text_IO;
with Jobs; with Corporation;

package body Logging is

   task body Logger is
      Verbose : Boolean;
   begin
      accept Start (VerboseIn : in Boolean) do
         Verbose := VerboseIn;
      end Start;
      loop
         accept Log (X : in String) do
            if Verbose then
               Put_Line(X);
            end if;
         end Log;
      end loop;
   end Logger;

   task body UserInteractor is
      JobQueue : Corporation.JobQueue_Task_Access;
      ProductStorage : Corporation.ProductStorage_Task_Access;
      Workers : Corporation.WorkerArray_Ptr;
   begin
      accept Start (JobQueueIn : in Corporation.JobQueue_Task_Access;
                    ProductStorageIn : in Corporation.ProductStorage_Task_Access;
                    WorkersIn : in Corporation.WorkerArray_Ptr) do
         JobQueue := JobQueueIn;
         ProductStorage := ProductStorageIn;
         Workers := WorkersIn;
      end Start;
      loop
         declare
            S : String(1..40);
            Last : Natural;
            Product_Vector : Jobs.ProductStorage_Vector.Vector;
            Job_List : Jobs.JobQueue_LinkedList.List;
            Worker : Corporation.Worker_Ptr;
            Jobs_Done : Natural;
         begin
            Put_Line("Enter 'p' for product storage info, 'q' for job queue info, or 'w' for worker info");
            Get_Line(S, Last);
            if S(1..Last) = "p" then
               ProductStorage.Status(Product_Vector);
               Put_Line("Number of products in storage:" & Product_Vector.Length'Image);
            elsif S(1..Last) = "q" then
               JobQueue.Status(Job_List);
               Put_Line("Number of jobs in queue:" & Job_List.Length'Image);
            elsif S(1..Last) = "w" then
               for W in Workers'Range loop
                  Worker := Workers(W);
                  Worker.Get_Jobs_Done(Jobs_Done);
                  Put("{" & Worker.Index'Image & Worker.Patience'Image & Jobs_Done'Image & "}");
               end loop;
               Put_Line("");
            end if;
               
         end;
      end loop;
   end UserInteractor;
      
end Logging;
