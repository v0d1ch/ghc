{-# LANGUAGE CPP, ForeignFunctionInterface #-}
#if __GLASGOW_HASKELL__ < 603
#include "config.h"
#else
#include "ghcconfig.h"
#endif
-----------------------------------------------------------------------------
--
-- (c) The University of Glasgow, 2004
--
-- runghc program, for invoking from a #! line in a script.  For example:
--
--   script.lhs:
--      #!/usr/bin/env /usr/bin/runghc
--      > main = putStrLn "hello!"
--
-- runghc accepts one flag:
--
--      -f <path>    specify the path
--
-- -----------------------------------------------------------------------------

module Main (main) where

import Control.Exception
import Data.Char
import Data.List
import System.Cmd
import System.Directory
import System.Environment
import System.Exit
import System.FilePath
import System.IO

main :: IO ()
main = do
    args <- getArgs
    case getGhcLoc args of
        (Just ghc, args') -> doIt ghc args'
        (Nothing, args') -> do
            mbPath <- getExecPath
            case mbPath of
                Nothing  -> dieProg ("cannot find ghc")
                Just path ->
                    let ghc = takeDirectory (normalise path) </> "ghc"
                    in doIt ghc args'

getGhcLoc :: [String] -> (Maybe FilePath, [String])
getGhcLoc args = case args of
                 "-f" : ghc : args' -> f ghc args'
                 ('-' : 'f' : ghc) : args' -> f ghc args'
                 -- If you need the first GHC flag to be a -f flag then
                 -- you can pass -- first
                 "--" : args -> (Nothing, args)
                 args        -> (Nothing, args)
    where f ghc args' = -- If there is another -f flag later on then
                        -- that overrules the one that we've already
                        -- found
                        case getGhcLoc args' of
                        (Nothing, _) -> (Just ghc, args')
                        success -> success

doIt :: String -> [String] -> IO ()
doIt ghc args = do
    let (ghc_args, rest) = getGhcArgs args
    case rest of
        [] -> do
           -- behave like typical perl, python, ruby interpreters:
           -- read from stdin
           tmpdir <- getTemporaryDirectory
           bracket
             (openTempFile tmpdir "runghcXXXX.hs")
             (\(filename,_) -> removeFile filename)
             $ \(filename,h) -> do
                 getContents >>= hPutStr h
                 hClose h
                 doIt ghc (ghc_args ++ [filename])
        filename : prog_args -> do
            let c1 = ":set prog " ++ show filename
                c2 = ":main " ++ show prog_args
            res <- rawSystem ghc (["-ignore-dot-ghci"] ++ ghc_args ++
                                  [ "-e", c1, "-e", c2, filename])
            exitWith res

getGhcArgs :: [String] -> ([String], [String])
getGhcArgs args
 = let (ghcArgs, otherArgs) = case break pastArgs args of
                              (xs, "--":ys) -> (xs, ys)
                              (xs, ys)      -> (xs, ys)
   in (map unescape ghcArgs, otherArgs)
    where unescape ('-':'-':'g':'h':'c':'-':'a':'r':'g':'=':arg) = arg
          unescape arg = arg

pastArgs :: String -> Bool
-- You can use -- to mark the end of the flags, in case you need to use
-- a file called -foo.hs for some reason. You almost certainly shouldn't,
-- though.
pastArgs "--" = True
pastArgs ('-':_) = False
pastArgs _       = True

dieProg :: String -> IO a
dieProg msg = do
    p <- getProgName
    hPutStrLn stderr (p ++ ": " ++ msg)
    exitWith (ExitFailure 1)

-- usage :: String
-- usage = "syntax: runghc [-f GHC-PATH | --] [GHC-ARGS] [--] FILE ARG..."

getExecPath :: IO (Maybe String)
#if defined(mingw32_HOST_OS)
getExecPath =
     allocaArray len $ \buf -> do
         ret <- getModuleFileName nullPtr buf len
         if ret == 0 then return Nothing
                     else liftM Just $ peekCString buf
    where len = 2048 -- Plenty, PATH_MAX is 512 under Win32.

foreign import stdcall unsafe "GetModuleFileNameA"
    getModuleFileName :: Ptr () -> CString -> Int -> IO Int32
#else
getExecPath = return Nothing
#endif

