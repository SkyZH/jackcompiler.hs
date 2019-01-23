module ParserProgramStructure where

import TokenParser
import Tokenizer
import ParserUtil

pClassName :: Parser ParseResult
pClassName = ParseNode <$> sat isIdentifier

pSubroutineName :: Parser ParseResult
pSubroutineName = ParseNode <$> sat isIdentifier

pVarName :: Parser ParseResult
pVarName = ParseNode <$> sat isIdentifier

pType :: Parser ParseResult
pType = (ParseNode <$> sat (== Keyword "int"))
        +++ (ParseNode <$> sat (== Keyword "char"))
        +++ (ParseNode <$> sat (== Keyword "boolean"))
        +++ pClassName

pClass :: Parser ParseResult
pClass = do 
    kwd <- ParseNode <$> sat (== Keyword "class")
    className <- pClassName
    decs <- pBrackets '{' '}' $ do
        classVarDecs <- many0 pClassVarDec
        subroutineDecs <- many0 pSubroutineDec
        return $ classVarDecs ++ subroutineDecs
    return $ ParseTree {
        what = "class",
        children = [kwd, className] ++ decs
    }

pClassVarDec :: Parser ParseResult
pClassVarDec = do
    kwd <- sat (== Keyword "static") +++ sat (== Keyword "field")
    whattype <- pType
    varNames <-  pVarName `sepby1` (ParseNode <$> sat (== Symbol ','))
    end <- pEnd
    return $ ParseTree {
        what = "classVarDec",
        children = [
            ParseNode kwd,
            whattype
        ] ++ varNames ++ [end]
    }

pSubroutineDec :: Parser ParseResult
pSubroutineDec = do
    kwd <- ParseNode <$> sat (== Keyword "constructor") +++ sat (== Keyword "function") +++ sat (== Keyword "method")
    rettype <- pType +++ (ParseNode <$> sat (== Keyword "void"))
    subroutineName <- pSubroutineName
    parameterList <- pBracket '(' ')' pParameterList
    subroutineBody <- pSubroutineBody
    return ParseTree {
        what = "subroutineDec",
        children = [
            kwd,
            rettype,
            subroutineName
        ] ++ parameterList ++ [subroutineBody]
    }

pSubroutineBody :: Parser ParseResult
pSubroutineBody = do
    sym1 <- ParseNode <$> sat (== Symbol '{')
    sym2 <- ParseNode <$> sat (== Symbol '}')
    return ParseTree {
        what = "subroutineBody",
        children = [
            sym1,
            sym2
        ]
    }

pParameterList :: Parser ParseResult
pParameterList = let
        parseResult = parameter `sepby0` ((\x -> [x]) . ParseNode <$> sat (== Symbol ','))
        parameter = do
            whattype <- pType
            varName <- pVarName
            return [whattype, varName]
    in do
        results <- parseResult
        return ParseTree {
            what = "parameterList",
            children = concat results
        }

