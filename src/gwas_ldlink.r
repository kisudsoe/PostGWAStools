help_message = '
gwas_ldlink, v2020-01-21
This is a function for LDlink data.

Usage: Rscript postgwas-exe.r --ldlink <Function> --base <base file> --out <out folder> <...>
    --ldlink <Functions: dn/fl>

Functions:
    dn       This is a function for LDlink data download.
    fl       This is a function for LDlink data filter.
    bed      This is a function to generate two BED files (hg19 and hg38).

Global arguments:
    --base   <EFO0001359.tsv>
             One base TSV file is mendatory.
    --out    <default: data>
             Out folder path is mendatory. Default is "data" folder.

Required arguments:
    --popul  <CEU TSI FIN GBR IBS ...>
             An argument for the "--ldlink dn". One or more population option have to be included.
    --r2d    <1/2/3/4>
             An argument for the "--ldlink fl". Choose one number among these options:
                1) r2>0.6 and Dprime=1  <- The most stringent criteria.
                2) r2>0.6               <- Usual choice to define LD association.
                3) Dprime=1
                4) r2>0.6 or Dprime=1
'

## Load global libraries ##
suppressMessages(library(dplyr))

## Functions Start ##
ldlink_bed = function(
    ldfl_path = NULL,   # LDlink filter result. Need to check removing NA value.
    out       = 'data', # Out folder path
    debug     = F
) {
    paste0('\n** Run function ldlink_bed... ') %>% cat
    snps = read.delim(ldfl_path)
    dim(snps) %>% print

    # hg19: save as BED file
    snps_ = na.omit(snps[,c(1,3:5)])
    snps_hg19_length = snps_$hg19_end - snps_$hg19_start
    snp_bed_hg19_li = lapply(c(1:nrow(snps_)),function(i) {
        row = snps_[i,]
        if(snps_hg19_length[i]<0) {
            start = as.numeric(as.character(row$hg19_end))-1
            end   = row$hg19_start
        } else {
            start = as.numeric(as.character(row$hg19_start))-1
            end   = row$hg19_end
        }
        out = data.frame(
            chr   = row$hg19_chr,
            start = start,
            end   = end,
            rsid  = row$rsid
        )
        return(out)
    })
    snp_bed_hg19 = data.table::rbindlist(snp_bed_hg19_li) %>% unique
    if(debug) {
        hg19_snp_lenth = snp_bed_hg19$end - snp_bed_hg19$start
        table(hg19_snp_lenth) %>% print
    }
    f_name1 = paste0(out,'/gwas_hg19_biomart_',nrow(snp_bed_hg19),'.bed')
    write.table(snp_bed_hg19,f_name1,row.names=F,col.names=F,quote=F,sep='\t')
    paste0('Write file:\t',f_name1,'\n') %>% cat

    # hg38: save as BED file
    snps_ = na.omit(snps[,c(1,6:8)])
    snps_length = snps_$end - snps_$start
    snp_bed_hg38_li = lapply(c(1:nrow(snps_)),function(i) {
        row = snps_[i,]
        if(snps_length[i]<0) {
            start = as.numeric(as.character(row$end))-1
            end   = row$start
        } else {
            start = as.numeric(as.character(row$start))-1
            end   = row$end
        }
        out = data.frame(
            chr   = row$chr,
            start = start,
            end   = end,
            rsid  = row$rsid
        )
        return(out)
    })
    snp_bed_hg38 = data.table::rbindlist(snp_bed_hg38_li) %>% unique
    if(debug) {
        hg38_snp_lenth = snp_bed_hg38$end - snp_bed_hg38$start
        table(hg38_snp_lenth) %>% print
    }
    f_name2 = paste0(out,'/gwas_hg38_biomart_',nrow(snp_bed_hg38),'.bed')
    write.table(snp_bed_hg38,f_name2,row.names=F,col.names=F,quote=F,sep='\t')
    paste0('Write file:\t',f_name2,'\n') %>% cat
}

ldlink_fl = function(
    snp_path = NULL,   # GWAS file path
    ld_path  = NULL,   # LDlink download folder path
    out      = 'data', # Out folder path
    r2d      = NULL,   # LDlink filter criteria. R2>0.6 and/or D'=1
    debug    = F
) {
    # Function specific library
    suppressMessages(library(biomaRt))

    paste0('\n** Run function ldlink_ln...\n') %>% cat
    # Read downloaded files
    paste0('Read download files... ') %>% cat
    snpdf     = read.delim(snp_path) %>% unique
    snpids    = snpdf$rsid %>% unique
    col_names = c('No','RS_Number','Coord','Alleles','MAF',
        'Distance','Dprime','R2','Correlated_Alleles','RegulomeDB','Function')
    ldlink    = paste0(ld_path,'/',snpids,'.txt')
    snptb     = data.frame(snpids=snpids, ldlink=ldlink)
    
    paste0(nrow(snptb),'\n') %>% cat
    ldlink_li = apply(snptb,1,function(row) {
        tb1 = try(
            read.table(as.character(row[2]),sep='\t',
                header=F,skip=1,stringsAsFactors=F,
                col.names=col_names) )
        if('try-error' %in% class(tb1)) {
            paste0('  ',row[1],'\n') %>% cat
            return(NULL)
        } else { # If no errors occurred,
            tb2 = data.frame(SNPid=rep(row[1],nrow(tb1)),tb1)
            return(tb2)
        }
    })
    ldlink_df = data.table::rbindlist(ldlink_li) %>% unique
    paste0('  Read LDlink results\t\t= ') %>% cat; dim(ldlink_df) %>% print

    # Filter the LDlink data
    if(r2d==1) {
        cat('Filtering by "r2 > 0.6 and Dprime = 1":\n')
        ldlink_1 = subset(ldlink_df,R2>0.6 & Dprime==1)
    } else if(r2d==2) {
        cat('Filtering by "r2 > 0.6":\n')
	    ldlink_1 = subset(ldlink_df,R2>0.6) # r2 > 0.6
    } else if(r2d==3) {
        cat('Filtering by "Dprime = 1":\n')
	    ldlink_1 = subset(ldlink_df,Dprime==1) # D' = 1
    } else if(r2d==4) {
        cat('Filtering by "r2 > 0.6 or Dprime = 1":\n')
	    ldlink_1 = subset(ldlink_df,R2>0.6 | Dprime==1) # r2 > 0.6 or D' = 1
    } else cat('Which filtering option is not supported.\n')
    ldlink_2 = data.frame(
        gwasSNPs = ldlink_1$SNPid,
        ldSNPs   = ldlink_1$RS_Number,
        ld_coord = ldlink_1$Coord
    ) %>% unique
    paste0('  Filtered data dimension \t= ') %>% cat; dim(ldlink_2) %>% print
    ldlink_ = ldlink_2[!ldlink_2$`ldSNPs` %in% c("."),] # Exclude no rsid elements
    ex = nrow(ldlink_2[ldlink_2$`ldSNPs` %in% c("."),])
    paste0('  Excluded no rsid elements\t= ') %>% cat; print(ex)
    
    # Basic summary of LDlink results
    paste0('Basic summary of LDlink results:\n') %>% cat
    paste0('  SNP Tier 1\t\t\t= ',length(snpids),'\n') %>% cat
    snp_t2 = setdiff(ldlink_$ldSNPs,snpids) %>% unique
    paste0('  SNP Tier 2\t\t\t= ',length(snp_t2),'\n') %>% cat
    snp_cand = union(ldlink_$ldSNPs,snpids) %>% unique
    snps_ = data.frame(rsid=snp_cand)
    #write.table(snp_cand,'snp_cand.tsv',row.names=F,quote=F,sep='\t') # For debug
    paste0('  SNP candidates\t= ',length(snp_cand),'\n') %>% cat

    # Search biomart hg19 to get coordinates
    paste0('Search biomart for SNP coordinates:\n') %>% cat
    paste0('  Query SNPs\t\t= ') %>% cat; length(snp_cand) %>% print
    paste0('  Hg19 result table\t= ') %>% cat
    hg19_snp = useMart(biomart="ENSEMBL_MART_SNP",host="grch37.ensembl.org",
                       dataset='hsapiens_snp',path='/biomart/martservice')
    snp_attr1 = c("refsnp_id","chr_name","chrom_start","chrom_end")
    snps_hg19_bio1 = getBM(
        attributes = snp_attr1,
        filters    = "snp_filter",
        values     = snp_cand,
        mart       = hg19_snp) %>% unique
    snps_merge = merge(snps_,snps_hg19_bio1,
                       by.x='rsid',by.y='refsnp_id',all.x=T)
    which_na = is.na(snps_merge$chr_name) %>% which
    snps_na = snps_merge[which_na,1]
    snp_attr2 = c("refsnp_id",'synonym_name',"chr_name","chrom_start","chrom_end")
    snps_hg19_bio2 = getBM(
        attributes = snp_attr2,
        filters    = "snp_synonym_filter",
        values     = snps_na,
        mart       = hg19_snp) %>% unique
    snps_hg19_bio2 = snps_hg19_bio2[,c(2:5)]
    colnames(snps_hg19_bio2)[1] = "refsnp_id"
    snps_hg19_bio = rbind(snps_hg19_bio1,snps_hg19_bio2) %>% unique
    colnames(snps_hg19_bio) = c('rsid','hg19_chr','hg19_start','hg19_end')
    snps_hg19_bio_ = subset(snps_hg19_bio,hg19_chr %in% c(1:22,'X','Y'))
    snps_hg19_bio_[,2] = paste0('chr',snps_hg19_bio_[,2])
    #snps_hg19_bio_[,3] = as.numeric(as.character(snps_hg19_bio_[,3]))-1
    dim(snps_hg19_bio_) %>% print

    # Search biomart hg38 to get coordinates
    paste0('  Hg38 result table\t= ') %>% cat
    hg38_snp = useMart(biomart="ENSEMBL_MART_SNP",dataset="hsapiens_snp")
    snps_bio1 = getBM(
        attributes = snp_attr1,
        filters    = "snp_filter",
        values     = snp_cand,
        mart       = hg38_snp) %>% unique
    snps_merge = merge(snps_,snps_bio1,
                       by.x='rsid',by.y='refsnp_id',all.x=T)
    which_na = is.na(snps_merge$chr_name) %>% which
    snps_na = snps_merge[which_na,1]
    snps_bio2 = getBM(
        attributes = snp_attr2,
        filters    = "snp_synonym_filter",
        values     = snps_na,
        mart       = hg38_snp) %>% unique
    snps_bio2 = snps_bio2[,c(2:5)]
    colnames(snps_bio2)[1] = "refsnp_id"
    snps_bio = rbind(snps_bio1,snps_bio2) %>% unique
    colnames(snps_bio) = c('rsid','chr','start','end')
    snps_bio_       = subset(snps_bio,chr %in% c(1:22,'X','Y'))
    snps_bio_[,2]   = paste0('chr',snps_bio_[,2])
    #snps_bio_[,3]   = as.numeric(as.character(snps_bio_[,3]))-1
    dim(snps_bio_) %>% print

    # Merge the biomart result with the GWAS SNP list 
    merge_multi = function(x,y) { merge(x,y,by='rsid',all.x=T) }
    #snps_merge = merge(snps_,snps_bio_,by='rsid',all.x=TRUE)
    colnames(ldlink_)[2] = 'rsid'
    snps_li = list(
        snps_,
        ldlink_,
        snps_hg19_bio_,
        snps_bio_
    )
    snps_merge = Reduce(merge_multi,snps_li)
    f_name1 = paste0(out,'/gwas_biomart.tsv')
    paste0('  Merged table\t\t= ') %>% cat; dim(snps_merge) %>% print
    write.table(snps_merge,f_name1,row.names=F,quote=F,sep='\t')
    paste0('Write file:\t',f_name1,'\n') %>% cat
}

ldlink_dn = function(
    snp_path = NULL,   # gwassnp_summ: 'filter' result file path
    out      = 'data', # out folder path
    popul    = NULL,   # population filter option for LDlink
    debug    = F
) {
    # Function specific library
    suppressMessages(library(LDlinkR))

    # Download from LDlink
    paste0('\n** Run function ldlink_dn... ') %>% cat
    snps = read.delim(snp_path)
    rsid = snps$rsid %>% unique
    paste0(rsid%>%length,'.. ') %>% cat
    token = '669e9dc0b428' # Seungsoo Kim's personal token
    LDproxy_batch(snp=rsid, pop=popul, r2d='d', token=token, append=F)
    paste0('done\n') %>% cat
    
    # Rename downloaded file
    f_name  = paste0(rsid,'.txt')
    f_name1 = paste0(out,'/',f_name)
    file.rename(f_name,f_name1)
    paste0('  Files are moved to target folder:\t',out,'\n') %>% cat
}

gwas_ldlink = function(
    args = NULL
) {
    if(length(args$help)>0) {  help    = args$help
    } else                     help    = FALSE
    if(help)                   cat(help_message)
    
    if(length(args$base)>0)    b_path  = args$base
    if(length(args$out)>0)     out     = args$out
    if(length(args$debug)>0) { debug   = args$debug
    } else                     debug   = FALSE
    
    if(length(args$popul)>0)   popul   = args$popul
    if(length(args$r2d)>0)     r2d     = args$r2d
    
    source('src/pdtime.r'); t0=Sys.time()
    if(args$ldlink == 'dn') {
        ldlink_dn(b_path,out,popul,debug)
    } else if(args$ldlink == 'fl') {
        ldlink_fl(b_path[1],b_path[2],out,r2d,debug)
    } else if(args$ldlink == 'bed') {
        ldlink_bed(b_path,out,debug)
    } else {
        paste0('[Error] There is no such function in gwas_ldlink: ',
            paste0(args$ldlink,collapse=', '),'\n') %>% cat
    }
    paste0(pdtime(t0,1),'\n') %>% cat
}