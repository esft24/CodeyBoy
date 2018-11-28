import Control.Monad.State

type ECMonad = StateT [Int] IO

f :: Int -> Int -> ECMonad ()
f identificador tipo = do 
  x <- get
  let maybeEstado = Just [4,5,6]
  case maybeEstado of Nothing -> liftIO $ print "Hubo un errorBoy"
                      Just nuevoEstado -> put nuevoEstado

principal :: ECMonad ()
principal = do
  f 1 2
  return ()