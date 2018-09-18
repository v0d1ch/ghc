module T13600b where

f4 :: Maybe [Int] -> IO Int
f4 !(Just _) = return (sum x)
