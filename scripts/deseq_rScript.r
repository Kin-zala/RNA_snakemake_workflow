library (DESeq2)
args <- commandArgs (trailingOnly = TRUE)
print(args)

countdata <- read.table(args[1], header = TRUE, stringsAsFactors = FALSE, skip = 1)
genenames <- countdata$Geneid #Extract the gene names from the count data
countdata <- countdata[, 7:ncol (countdata)] # Select columns with counts (samples @ to 5)
colnames(countdata) <- colnames(read.table(args[1], header=TRUE, skip=1))[7:ncol(read.table(args[1], header=TRUE, skip=1))] #rename columns
countdata <- as.matrix(countdata) #convert the data as matrix format
rownames (countdata) <- genenames
# Filter out any genes whose names start with "ERCC-" (these are typically external control genes)
sel <- sapply(rownames (countdata), function(x) { if (substr(x, 1,5)=="ERCC-"){return(FALSE)}else{return(TRUE)} })
countdata <- countdata[sel, ]

coldata <- data.frame(condition = as.factor(c(rep("A", 3), rep("B", 3))), #assign the experimental cond. A/B
row.names = colnames (countdata))

dds <- DESeqDataSetFromMatrix (countData = countdata, # Create a DESegDataSet from the count data and conditions.
colData = coldata,
design = ~ condition) # Define the design formula

keep <- rowSums (countdata) > 0
dds <- dds[keep, ] # Keep only the genes that have non-zero count

dds <- DESeq(dds, fitType = "mean") # Perform differential expression analysis using DESeq
res <- results(dds)

write.table(res, file = args[2], sep = "\t", row.names = TRUE, quote = FALSE)

up_genes <- res[res$log2FoldChange >= 2 & !is.na(res$log2FoldChange),]
write.table(up_genes, "deseq2_up.txt", sep = "\t", quote = FALSE, row.names = TRUE)

down_genes <- res [res$log2FoldChange <= -2 & !is.na(res$log2FoldChange),]
write.table(down_genes, "deseq2_down.txt", sep = "\t", quote = FALSE, row.names = TRUE)

write.table(up_genes, args[3], sep="\t", quote=FALSE)
write.table(down_genes, args[4], sep="\t", quote=FALSE)