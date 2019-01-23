{-# LANGUAGE TemplateHaskell #-}
module TokenParser where

import Control.Applicative
import Control.Monad
import Data.DeriveTH
import Tokenizer

derive makeIs ''JackToken

newtype Parser a = Parser { parse :: ([JackToken] -> [(a, [JackToken])]) }

item :: Parser JackToken
item = Parser (\cs -> case cs of
                      [] -> []
                      (c:cs) -> [(c, cs)])

instance Functor Parser where
    fmap = liftM

instance Applicative Parser where
    pure  = return
    (<*>) = ap

instance Alternative Parser where
    empty = mzero
    (<|>) = mplus
    
instance Monad Parser where
    return a = Parser (\cs -> [(a, cs)])
    p >>= f = Parser (\cs -> concat 
                    [parse (f a) cs' | 
                        (a, cs') <- parse p cs])

instance MonadPlus Parser where
    mzero = Parser (\cs -> [])
    mplus p q = Parser (\cs -> parse p cs ++ parse q cs)

(+++) :: Parser a -> Parser a -> Parser a
p +++ q = Parser (\cs -> case parse (p `mplus` q) cs of
                              []     -> []
                              (x:xs) -> [x])

sat :: (JackToken -> Bool) -> Parser JackToken
sat p = do { c <- item; if p c then return c else mzero }

many0 :: Parser a -> Parser [a]
many0 p = many1 p +++ return []

many1 :: Parser a -> Parser [a]
many1 p = do { a <- p ; as <- many0 p ; return (a:as) }

sepby0 :: Parser a -> Parser a -> Parser [a]
p `sepby0` sep = (p `sepby1` sep) +++ return []

sepby1 :: Parser a -> Parser a -> Parser [a]
p `sepby1` sep = do a <- p
                    as <- many (do {sep <- sep; p <- p ; return [sep,p] })
                    return (a:concat as)

optional :: Parser [a] -> Parser [a]
optional p = return [] +++ do { a <- p ; return a }

optional1 :: Parser a -> Parser [a]
optional1 p = return [] +++ do { a <- p ; return [a] }


data ParseResult = ParseTree { what :: String, children :: [ParseResult] }
    | ParseNode { content :: JackToken }
    deriving (Show, Eq)
   
parseXML :: [(ParseResult, a)] -> String
parseXML = parseXML' . fst . head where
    parseXML' (ParseTree what children) = wrap what ++ "\n" ++ (prepend . parseXMLChildren) children ++ wrap ('/':what)
    parseXML' (ParseNode token) = parseOneTokenXML token
    wrap what = "<" ++ what ++ ">"
    parseXMLChildren (x:xs) = parseXML' x ++ "\n" ++ parseXMLChildren xs
    parseXMLChildren _ = ""
    prepend = unlines . (map (\x -> "    " ++ x)) . lines
    