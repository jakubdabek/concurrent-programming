with Ada.Containers; use Ada.Containers;
with Ada.Numerics.Discrete_Random;
with Ada.Numerics.Float_Random;
with Logging;

with Ada.Text_IO; use Ada.Text_IO;

package body Jobs is

   function Product_Image(Product : in ProductT) return String is
   begin
      return "Product[" & Product.Index'Image & " ]{" & Product.Value'Image & " }";
   end Product_Image;


   function NewProduct(Value : ValueType) return Product_Ptr is
      Cnt : Natural;
   begin
      ProductIndexCounter.Increment(Cnt);
      return new ProductT'(IndexType(Cnt), Value);
   end;

   function Execute(This : in out Addition; Left : in ValueType; Right : in ValueType)
                    return ValueType is
   begin
      return Left + Right;
   end Execute;
   function Operator_Image(This : in Addition) return String is
   begin
      return "'+'";
   end Operator_Image;


   function Execute(This : in out Subtraction; Left : in ValueType; Right : in ValueType)
                    return ValueType is
   begin
      return Left - Right;
   end Execute;
   function Operator_Image(This : in Subtraction) return String is
   begin
      return "'-'";
   end Operator_Image;


   function Execute(This : in out Multiplication; Left : in ValueType; Right : in ValueType)
                    return ValueType is
   begin
      return Left * Right;
   end Execute;
   function Operator_Image(This : in Multiplication) return String is
   begin
      return "'*'";
   end Operator_Image;


   function NewOperation(S : OperationT) return Operation_Ptr is
   begin
      case S is
         when '+' => return new Addition;
         when '*' => return new Multiplication;
         when others => Put_Line("Fuck"); return null;
      end case;
   end NewOperation;


   function NewOperationType(S : Ada.Numerics.Float_Random.Generator) return OperationT is
      C : Float := Ada.Numerics.Float_Random.Random(S);
   begin
      if C < 1.0/2.0 then
         return '+';
      else
         return '*';
      end if;
   end NewOperationType;

   JobIndexCounter : Concurrent.Counter;

   function NewJob(Left : ValueType; Right : ValueType; OperationType : OperationT) return JobT is
      Index : Natural;
   begin
      JobIndexCounter.Increment(Index);
      return (Index, Left, Right, OperationType, null);
   end NewJob;

   function Job_Image(Job : in JobT) return String is
   begin
      return "Job[" & Job.Index'Image & " ]{" & Job.Left'Image & Job.OperationType'Image & Job.Right'Image & " }";
   end Job_Image;


   task body JobQueue_Task is
      List : JobQueue_LinkedList.List;
   begin
      loop
         select
            when List.Length < Max_Size =>
               accept New_Job (Job : in JobT) do
                  List.Append(Job);
               end New_Job;
         or
            when List.Length > 0 =>
               accept Next_Job (Job : out JobT) do
                  Job := List.First_Element;
                  List.Delete_First;
               end Next_Job;
         or
            accept Status (Status : out JobQueue_LinkedList.List) do
               Status := List.Copy;
            end Status;
         or
            terminate;
         end select;
      end loop;
   end JobQueue_Task;

   task body ProductStorage_Task is
      Vector : ProductStorage_Vector.Vector;
      --        type MyVectorIndexType is new ProductStorage_Vector.Index_Type'Base range
      --          ProductStorage_Vector.Index_Type'First..(ProductStorage_Vector.Index_Type'First + Max_Size);
      subtype MyVectorIndexType is Natural range
        Natural'First .. Natural'First + Max_Size;
      package Rand is new Ada.Numerics.Discrete_Random(Result_Subtype => MyVectorIndexType);
      use Rand;
      Seed : Generator;
   begin
      Reset(Seed);
      loop
         --Logging.L.Log("Product storage looping, size " & Natural'Image(Natural(Vector.Length)) &
         --                " max size " & Natural'Image(Natural(Max_Size)));
         select
            when Natural(Vector.Length) < Max_Size =>
               accept New_Product (Product : in ProductT) do
                  Vector.Append(Product);
                  Logging.L.Log("New product put in storage: " & Product_Image(Product));
               end New_Product;
         or
            when Vector.Length > 0 =>
               accept Next_Product (Product : out ProductT) do
                  declare
                     Rand_Index : MyVectorIndexType := Random(Seed);
                  begin
                     if Rand_Index > Vector.Last_Index then
                        Rand_Index := Vector.Last_Index;
                     end if;

                     Product := Vector.Element(Rand_Index);
                     Vector.Delete(Rand_Index);
                  end;
               end Next_Product;
         or
            accept Status (Status : out ProductStorage_Vector.Vector) do
               Status := Vector.Copy;
            end Status;
         end select;
      end loop;
   end;


end Jobs;
