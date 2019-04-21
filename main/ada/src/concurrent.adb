package body Concurrent is

   protected body Counter is
      procedure Increment(Value : out Natural) is
      begin
         Value := N;
         N := N + 1;
      end Increment;
            
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
