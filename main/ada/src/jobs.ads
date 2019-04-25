with Ada.Containers.Synchronized_Queue_Interfaces;
with Ada.Containers.Bounded_Synchronized_Queues;
with Ada.Containers.Doubly_Linked_Lists;
with Ada.Containers.Vectors;
with Ada.Numerics.Float_Random;
with Concurrent;


package Jobs is
   type IndexType is new Natural;
   type ValueType is new Float;
   
   type ProductT is record
      Index : IndexType;
      Value : ValueType;
   end record;
   
   type Product_Ptr is access all ProductT;
   
   function Product_Image(Product : in ProductT) return String;
   
   function NewProduct(Value : ValueType) return Product_Ptr;
   ProductIndexCounter : Concurrent.Counter;
   
   type OperationT is ('+', '*');

   type Operation is interface;

   function Execute(This : in out Operation; Left : in ValueType; Right : in ValueType)
                    return ValueType is abstract;
   function Operator_Image(This : in Operation) return String is abstract;

   type Operation_Ptr is access Operation'Class;

   type Addition is new Operation with null record;
   function Execute(This : in out Addition; Left : in ValueType; Right : in ValueType)
                    return ValueType;
   function Operator_Image(This : in Addition) return String;
   
    
   type Subtraction is new Operation with null record;
   function Execute(This : in out Subtraction; Left : in ValueType; Right : in ValueType)
                    return ValueType;
   function Operator_Image(This : in Subtraction) return String;
   

   type Multiplication is new Operation with null record;
   function Execute(This : in out Multiplication; Left : in ValueType; Right : in ValueType)
                    return ValueType;
   function Operator_Image(This : in Multiplication) return String;
   
   
   function NewOperation(S : OperationT) return Operation_Ptr;
   function NewOperationType(S : Ada.Numerics.Float_Random.Generator) return OperationT;
    
   type JobT is record
      Index : Natural;
      Left : ValueType;
      Right : ValueType;
      OperationType : OperationT;
      Product : Product_Ptr := null;
   end record;
   
   function NewJob(Left : ValueType; Right : ValueType; OperationType : OperationT) return JobT;
   
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
