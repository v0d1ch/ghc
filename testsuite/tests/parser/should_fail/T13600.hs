module T13600 where

f0 :: [a] -> Int -> a
f0 ! x = f0 x

f1 :: [Int] -> IO Int
f1 !x = return (sum x)

f2 :: [Int] -> IO Int
f2 ! x = return (sum x)

f3 :: Maybe [Int] -> IO Int
f3 !(Just x) = return (sum x)

f4 :: Maybe [Int] -> IO Int
f4 ! (Just x) = return (sum x)

f5 :: IO Int
f5 =
   let f0 !x = return (sum x)
   in f0 [1,2,3]

f6 :: Int
f6 =
  let f ! x = f ! x
  in [1,2,3] ! 1
