library(GO.db)
goterms <- Term(GOTERM)
syn <- unlist(lapply(Synonym(GOTERM), function(x)paste(x, collapse="; ")))
keywords <- paste(goterms, syn, sep="; ")
names(keywords) <- names(goterms)
write.table(keywords, sep="\t", file="go.txt")