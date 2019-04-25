package body Concurrent is

   protected body Counter is
      procedure Increment(Value : out Natural) is
      begin
         Value := N;
         N := N + 1;
      end Increment;
      
      procedure Increment is
      begin
         N := N + 1;
      end Increment;
      
      function Get_Value return Natural is
      begin
         return N;
      end Get_Value;
   end Counter;
   
   protected body Semaphore is
      entry Wait when Count > 0 is
      begin
         Count := Count - 1;
      end Wait;
      procedure Signal is
      begin
         Count := Count + 1;
      end Signal;
   end Semaphore;
   

end Concurrent;
