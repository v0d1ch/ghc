module T13600 where

f4 :: [Int] -> IO Int
f4 !x = return (sum x)
