package Concurrent is

   protected type Counter is
      procedure Increment(Value : out Natural);
      procedure Increment;
      function Get_Value return Natural;
   private
      N : Natural := 0;
   end Counter;
   
   type Counter_Ptr is access all Counter;
   
   protected type Semaphore(Initial_Count : Natural) is
      entry Wait;
      procedure Signal;
   private
      Count : Natural := Initial_Count;
   end Semaphore;
   
   type Semaphore_Access is access all Semaphore;
   

end Concurrent;
