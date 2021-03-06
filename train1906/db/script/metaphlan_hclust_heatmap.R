#!/usr/bin/env Rscript
# Copyright 2016-2019 Yong-Xin Liu <metagenome@126.com>
# Turn off warning
# options(warn = -1) 

# 1. 分析前准备：帮助、参数、依赖包和读取文件

# 命令行运行为当前目录；Rstudio手动运行脚本前需要设置工作目录，使用 Ctrl+Shift+H 或 Session - Set Work Directory - Choose Directory / To Source File Location 设置工作目录


# 1.1 程序功能描述和主要步骤

# 程序功能：绘制物种组成热图
# 主要步骤: 
# - 读取Metaphlan2物种组表 result/metaphlan2/taxonomy.spf(己标准化为100)
# - 物种组成按丰度均值排序
# - 筛选Top N个物种绘制热图

# # 程序使用示例USAGE
# # 显示脚本帮助 help
# Rscript db/script/metaphlan_hclust_heatmap.R -h
# # 默认读取result/metaphlan2/taxonomy.spf，按指定列合并、排序并取Top25种绘制热图，输出至输入目录
# Rscript db/script/metaphlan_hclust_heatmap.R
# # 完整参数：-i输入Metaphlan2文件；
# # -t 分类级别，可选Kingdom/Phylum/Class/Order/Family/Genus/Species/Strain，界门纲目科属种株，推荐门，目，属
# # -n 输出物种数量，默认为25，最大为合并后的数量
# # -o输出图表前缀，默认根据输入文件、物种级别和数量自动生成；
# Rscript db/script/metaphlan_hclust_heatmap.R \
#   -i result/metaphlan2/taxonomy.spf \
#   -t Species \
#   -n 25 \
#   -o result/metaphlan2/heatmap_Species


# 1.2 解析命令行
# 设置清华源加速下载
site="https://mirrors.tuna.tsinghua.edu.cn/CRAN"
# 判断命令行解析是否安装，安装并加载
if (!suppressWarnings(suppressMessages(require("optparse", character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)))) {
  install.packages("optparse", repos=site)
  require("optparse",character.only=T) 
}


# if (!interactive() || length(find.package("optparse", NULL, TRUE))) {
#   
#   optionparser <- optparse::OptionParser(option_list = list(
# 
#     optparse::make_option(opt_str = c("-h", "--help"), action = "store_true",
#                           help = "Show this help message, then exit [default: %default]",
#                           default = FALSE),
#     optparse::make_option(opt_str = c("-i", "--input"), type = "character",
#                         help = paste0("Metaphlan2 [default %default]"),
#                         metavar = "FILE", default = "result/metaphlan2/taxonomy.spf"),
#   optparse::make_option(opt_str = c("-n", "--TopN"), type = "numeric",
#                           help = paste0("Top taxonomy 25 [default %default]"),
#                           metavar = "NUMBER", default = 25),
#   optparse::make_option(opt_str = c("-o", "--output"), type = "character",
#                           help = paste0("heatmap+taxonomy [default %default]"),
#                           metavar = "FILE", default = ""),
#   optparse::make_option(opt_str = c("-t", "--taxonomy"), type = "character",
#                           help = paste0("[default %default]"),
#                           metavar = "NAME", default = "Species")
# 
#   ), add_help_option = FALSE, prog = "metaphlan_hclust_heatmap.R",
#   usage = "%prog [options] input output ...", description = "
#   %prog: Plotting top taxonomy heatmap, version 1.0.1",
#   epilogue = "
# FREQUENTLY NEEDED OPTIONS:
# 
# -i\tInput Metaphlan2 taxonomy file, include Kingdom to Strains level and RA abundance.
# -o\tOutput heatmap figure and related table
# 
# USE OF DATA TYPES:
# 
# EXAMPLES:
# 
# # 'i' to input file 'taxonomy.tsv' (which must contain taxonomy and relative abundance):
# '%prog -i taxonomy.tsv -t Species -o taxonomy.pdf'
# 
# "
#   )
#   
#   invisible(list2env(optparse::parse_args(optionparser,
#                                           commandArgs(TRUE), TRUE, TRUE), environment()))
#   
#   if (length(args) && !options$help) {
#     options$infiles <- args
#     options$help <- NULL
#     names(options) <- chartr("-", ".", names(options))
#   } else {
#     optparse::print_help(optionparser)
#     if (interactive()) {
#       rm(optionparser, options, args)
#       message("
# ********************************************************************************
# Apparently this script is running in interactive mode. You could now generate
# result files by setting some 'infiles' variable to a vector of file names and then
# calling:
# 
# metaphlan_hclust_heatmap(infiles)
# ********************************************************************************
#       ")
#     } else {
#       quit("no", 1L)
#     }
#   }
# }


# 解析参数-h显示帮助信息
# 此版本参数在windows中报错显示3，无法正常运行
if (TRUE){
  option_list = list(
    make_option(c("-i", "--input"), type="character", default="result/metaphlan2/taxonomy.spf", help="Metaphlan2 [default %default]"),
    make_option(c("-t", "--taxonomy"), type="character", default="Species", help="Taxonomy level [default %default]"),
    make_option(c("-n", "--TopN"), type="numeric", default="25", help="Number of taxonomy showing [default %default]"),
    make_option(c("-o", "--output"), type="character", default="", help="Output heatmap filename [default %default]")
  )
  opts = parse_args(OptionParser(option_list=option_list))

  # 调置如果无调设置输出，根据其它参数设置默认输出
  prefix = gsub("taxonomy.spf$", "", opts$input, perl = T)
  if (opts$output==""){opts$output=paste0(prefix, "Heatmap", opts$taxonomy, opts$TopN)}

  # 显示输入输出确认是否正确
  # Metaphlan2物种组成表
  print(paste("The input file: ", opts$input,  sep = ""))
  # 绘制的分类级别, 默认为种
  print(paste("Taxonomy level: ", opts$taxonomy, ". Default if Species", sep = ""))
  # 选择绘制高丰度物种数量，默认30，最大为物种级别非冗余条目数量
  print(paste("Number of taxonomy showing: ", opts$TopN,  sep = ""))
  # 输出文件名，不填则为输入目录+heatmap+taxonomy
  print(paste("Output heatmap filename: ", opts$output, sep = ""))
}


# 1.3 安装CRAN来源常用包
# 依赖包列表：参数解析、数据变换、绘图和开发包安装、安装依赖、ggplot主题
package_list = c("pheatmap","ggplot2","dplyr")
# 判断R包加载是否成功来决定是否安装后再加载
for(p in package_list){
  if(!suppressWarnings(suppressMessages(require(p, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)))){
    install.packages(p, repos=site)
    suppressWarnings(suppressMessages(library(p, character.only = TRUE, quietly = TRUE, warn.conflicts = FALSE)))
  }
}


# 1.4 读取输入文件

# 读取metaphlan2文件
# 默认的quote会跳过2/3的数据，导致行减少产生NA，改默认值为空
taxonomy = read.table(opts$input, header=T, sep="\t", quote = "", row.names=NULL, comment.char="")
print(paste0("All taxonomy annotations are ", dim(taxonomy)[1], " lines!"))
# 去除NA，否则无法计算
taxonomy = na.omit(taxonomy)
# 显示样本总数据，有冗余
# colSums(taxonomy)



# 2. 计算过程

## 2.1 按指定组合并

grp = taxonomy[, opts$taxonomy, drop=F]
abu = taxonomy[,9:dim(taxonomy)[2]]
merge = cbind(abu, grp)
# group_by传变量，前面加".dots="
mergeTax = merge %>% group_by(.dots=opts$taxonomy) %>% summarise_all(sum)
# 合并后表格转换为数据框
mergeTax = as.data.frame(mergeTax)
# 按丰度排序
idx = order(rowMeans(mergeTax[,2:dim(mergeTax)[2]]), decreasing = T)
mergeTax = mergeTax[idx,]
# 添加行名
rownames(mergeTax)=mergeTax[,1]

## 2.1 筛选TopN绘图

# remove rownames line
Top = mergeTax[,-1]
# normalization to percentage 100
Top = as.data.frame(t(t(Top)/colSums(Top,na=T) * 100)) 
# Select TopN line for plotting
Top = head(Top, n=opts$TopN)

pheatmap(Top)

# 3. 结果输出

# 保存表格
write.table(mergeTax, file=paste(opts$output, ".txt", sep = ""), append = FALSE, sep="\t", quote=F, row.names=F, col.names=T)


# 保存图片
pheatmap(Top,
         filename = paste0(opts$output, ".pdf"),
         main = paste("Top", opts$TopN, opts$taxonomy, sep=" "))


# width=dim(Top)[2], height=dim(Top)[1]/4, 
# scale = "row",
# cutree_rows=2,cutree_cols = 2,
# annotation_col = anno_col, annotation_row = anno_row,
# annotation_names_row= T,annotation_names_col=T,
# show_rownames=F,show_colnames=T,
# ,
# fontsize=7,display_numbers=F