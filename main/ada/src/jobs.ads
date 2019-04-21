with Ada.Containers.Synchronized_Queue_Interfaces;
with Ada.Containers.Bounded_Synchronized_Queues;
with Ada.Containers.Doubly_Linked_Lists;
with Ada.Containers.Vectors;
with Ada.Numerics.Float_Random;
with Concurrent;


package Jobs is
   type IndexType is new Positive;
   type ValueType is new Float;
   
   type ProductT is record
      Index : IndexType;
      Value : ValueType;
   end record;
   
   function Product_Image(Product : in ProductT) return String;
   
   function NewProduct(Value : ValueType) return ProductT;
   ProductIndexCounter : Concurrent.Counter;

   type JobExecutor is interface;

   function Execute(This : in out JobExecutor; Left : in ValueType; Right : in ValueType)
                    return ValueType is abstract;
   function Executor_Image(This : in JobExecutor) return String is abstract;

   type JobExecutor_Ptr is access JobExecutor'Class;

   type Addition is new JobExecutor with null record;
   function Execute(This : in out Addition; Left : in ValueType; Right : in ValueType)
                    return ValueType;
   function Executor_Image(This : in Addition) return String;
   
    
   type Subtraction is new JobExecutor with null record;
   function Execute(This : in out Subtraction; Left : in ValueType; Right : in ValueType)
                    return ValueType;
   function Executor_Image(This : in Subtraction) return String;
   

   type Multiplication is new JobExecutor with null record;
   function Execute(This : in out Multiplication; Left : in ValueType; Right : in ValueType)
                    return ValueType;
   function Executor_Image(This : in Multiplication) return String;
   
   
   function NewExecutor(S :Ada.Numerics.Float_Random.Generator) return JobExecutor_Ptr;
    
   type JobT is record
      Left : ValueType;
      Right : ValueType;
      Executor : JobExecutor_Ptr;
   end record;
   
   function Job_Image(Job : in JobT) return String;
   
   package JobQueue_LinkedList is
     new Ada.Containers.Doubly_Linked_Lists(Element_Type => JobT);
   
   task type JobQueue_Task(Max_Size : Ada.Containers.Count_Type) is
      entry New_Job(Job : in JobT);
      entry Next_Job(Job : out JobT);
      entry Status(Status : out JobQueue_LinkedList.List);
   end JobQueue_Task;
   
   package ProductStorage_Vector is
     new Ada.Containers.Vectors(Index_Type   => Natural,
                                Element_Type => ProductT);
   
   task type ProductStorage_Task(Max_Size : Natural) is
      entry New_Product(Product : in ProductT);
      entry Next_Product(Product : out ProductT);
      entry Status(Status : out ProductStorage_Vector.Vector);
   end ProductStorage_Task;
   
end Jobs;
