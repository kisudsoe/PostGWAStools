bedtools	sort	-i	./1b_stitzellab/GSM3333912_EndoC_BH1_ATACseq_broadPeak.fdr0.05.noBlacklist.bed	|	bedtools	closest	-d	-a	gwas_hg19_biomart_2003.bed	-b	stdin	>	./1b_stitzellab_dist/EndoC_BH1_ATAC_broadPeak.tsv