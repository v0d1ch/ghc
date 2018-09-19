module T13600 where

(!) :: [a] -> Int -> a
(!) x i = x!!i

f1 :: [Int] -> IO Int
f1 !x = return (sum x)

f2 :: [Int] -> IO Int
f2 ! x = return (sum x)

f3 :: Maybe [Int] -> IO Int
f3 !(Just x) = return (sum x)

f4 :: Maybe [Int] -> IO Int
f4 ! (Just x) = return (sum x)

