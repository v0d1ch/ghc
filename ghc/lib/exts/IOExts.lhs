%
% (c) The AQUA Project, Glasgow University, 1994-1996
%
\section[IOExts]{Module @IOExts@}

@IOExts@ provides useful functionality that fall outside the
standard Haskell IO interface. Expect the contents of IOExts
to be the same for Hugs and GHC (same goes for any other
Hugs/GHC extension libraries, unless a function/type is
explicitly flagged as being implementation specific
extension.)

\begin{code}
{-# OPTIONS -fno-implicit-prelude #-}

module IOExts
        ( fixIO
        , unsafePerformIO
        , unsafeInterleaveIO

        , IORef		    -- instance of: Eq
        , newIORef
        , readIORef
        , writeIORef

	, mkWeakIORef

	, IOArray	-- instance of: Eq
	, newIOArray
	, boundsIOArray
	, readIOArray
	, writeIOArray
	, freezeIOArray
	, thawIOArray
#ifndef __HUGS__
	, unsafeFreezeIOArray
	, unsafeThawIOArray
#endif
	
#ifdef __HUGS__
#else
	, openFileEx
	, IOModeEx(..)

        , hSetEcho
	, hGetEcho
	, hIsTerminalDevice
	, hConnectTo
#endif
        , trace
#ifdef __HUGS__
#else
        , performGC
#endif
	
	, unsafePtrEq
	
	, freeHaskellFunctionPtr

        ) where

\end{code}

\begin{code}
#ifdef __HUGS__
import PreludeBuiltin
import ST
#else
import PrelBase
import PrelIOBase
import PrelHandle ( openFileEx, IOModeEx(..),
		    hSetEcho, hGetEcho, getHandleFd
		  )
import PrelST
import PrelArr
import PrelWeak
import PrelGHC
import PrelHandle
import PrelErr
import IO 	( hPutStr, hPutChar )
import PrelAddr ( Addr )
#endif
import Ix

unsafePtrEq :: a -> a -> Bool

#ifdef __HUGS__
unsafePtrEq = primReallyUnsafePtrEquality
#else
unsafePtrEq a b =
    case reallyUnsafePtrEquality# a b of
	 0# -> False
	 _  -> True
#endif
\end{code}

\begin{code}
newIORef   :: a -> IO (IORef a)
readIORef  :: IORef a -> IO a
writeIORef :: IORef a -> a -> IO ()

#ifdef __HUGS__
type IORef a = STRef RealWorld a
newIORef   = newSTRef
readIORef  = readSTRef
writeIORef = writeSTRef
#else
newtype IORef a = IORef (MutableVar RealWorld a) 
    deriving Eq

newIORef v = stToIO (newVar v) >>= \ var -> return (IORef var)
readIORef  (IORef var) = stToIO (readVar var)
writeIORef (IORef var) v = stToIO (writeVar var v)
#endif

mkWeakIORef :: IORef a -> IO () -> IO (Weak (IORef a))
mkWeakIORef r@(IORef (MutableVar r#)) f = IO $ \s ->
  case mkWeak# r# r f s of (# s1, w #) -> (# s1, Weak w #)
\end{code}

\begin{code}
newIOArray          :: Ix ix => (ix,ix) -> elt -> IO (IOArray ix elt)
boundsIOArray       :: Ix ix => IOArray ix elt -> (ix, ix)
readIOArray         :: Ix ix => IOArray ix elt -> ix -> IO elt
writeIOArray        :: Ix ix => IOArray ix elt -> ix -> elt -> IO ()
freezeIOArray       :: Ix ix => IOArray ix elt -> IO (Array ix elt)
thawIOArray	    :: Ix ix => Array ix elt -> IO (IOArray ix elt)
#ifndef __HUGS__
unsafeFreezeIOArray :: Ix ix => IOArray ix elt -> IO (Array ix elt)
unsafeThawIOArray   :: Ix ix => Array ix elt -> IO (IOArray ix elt)
#endif

#ifdef __HUGS__
type IOArray ix elt = STArray RealWorld ix elt
newIOArray    = newSTArray
boundsIOArray = boundsSTArray
readIOArray   = readSTArray
writeIOArray  = writeSTArray
freezeIOArray = freezeSTArray
thawIOArray   = thawSTArray
#else
newtype IOArray ix elt = IOArray (MutableArray RealWorld ix elt)
    deriving Eq

newIOArray ixs elt = 
    stToIO (newArray ixs elt) >>= \arr -> 
    return (IOArray arr)

boundsIOArray (IOArray arr) = boundsOfArray arr

readIOArray (IOArray arr) ix = stToIO (readArray arr ix)

writeIOArray (IOArray arr) ix elt = stToIO (writeArray arr ix elt)

freezeIOArray (IOArray arr) = stToIO (freezeArray arr)

thawIOArray arr = do 
	marr <- stToIO (thawArray arr)
	return (IOArray marr)

unsafeFreezeIOArray (IOArray arr) = stToIO (unsafeFreezeArray arr)
unsafeThawIOArray   arr = do
        marr <- stToIO (unsafeThawArray arr)
	return (IOArray marr)
#endif
\end{code}

\begin{code}
{-# NOINLINE trace #-}
trace :: String -> a -> a
#ifdef __HUGS__
trace string expr = unsafePerformIO $ do
    putStrLn string
    return expr
#else
trace string expr = unsafePerformIO $ do
    fd <- getHandleFd stderr
    hPutStr stderr string
    hPutChar stderr '\n'
    _ccall_ PostTraceHook fd
    return expr
#endif
\end{code}

Not something you want to call normally, but useful
in the cases where you do want to flush stuff out of
the heap or make sure you've got room enough

\begin{code}
#ifdef __HUGS__
#else
performGC :: IO ()
performGC = _ccall_GC_ performGC
#endif
\end{code}

When using 'foreign export dynamic' to dress up a Haskell
IO action to look like a C function pointer, a little bit
of memory is allocated (along with a stable pointer to
the Haskell IO action). When done with the C function
pointer, you'll need to call @freeHaskellFunctionPtr()@ to
let go of these resources - here's the Haskell wrapper for
that RTS entry point, should you want to free it from
within Haskell.

\begin{code}
foreign import ccall "freeHaskellFunctionPtr" 
  freeHaskellFunctionPtr :: Addr -> IO ()

\end{code}

