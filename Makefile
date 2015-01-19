# Names of Runs - would be nice to automate this with info from the server
# These were the runs from the paper...
RUNS = 121203 121205 121207 130125 130211 130220 130306 130401 130403 130417 130422

# The 24 fastq files that come with each run
F_FASTQS = Mock1_S1_L001_R1_001.fastq Mock2_S2_L001_R1_001.fastq \
	Mock3_S3_L001_R1_001.fastq Human1_S7_L001_R1_001.fastq \
	Human2_S8_L001_R1_001.fastq Human3_S9_L001_R1_001.fastq \
	Mouse1_S10_L001_R1_001.fastq Mouse2_S11_L001_R1_001.fastq \
	Mouse3_S12_L001_R1_001.fastq Soil1_S4_L001_R1_001.fastq \
	Soil2_S5_L001_R1_001.fastq Soil3_S6_L001_R1_001.fastq

R_FASTQS = Mock1_S1_L001_R2_001.fastq Mock2_S2_L001_R2_001.fastq \
	Mock3_S3_L001_R2_001.fastq Human1_S7_L001_R2_001.fastq \
	Human2_S8_L001_R2_001.fastq Human3_S9_L001_R2_001.fastq \
	Mouse1_S10_L001_R2_001.fastq Mouse2_S11_L001_R2_001.fastq \
	Mouse3_S12_L001_R2_001.fastq Soil1_S4_L001_R2_001.fastq \
	Soil2_S5_L001_R2_001.fastq Soil3_S6_L001_R2_001.fastq

FASTQS = $(F_FASTQS) $(R_FASTQS)

# Location of raw runs' data on local machine
RAW_DATA = data/raw/
RAW_RUNSPATH = $(addprefix $(RAW_DATA),$(RUNS))

# Location of processed runs' data on local machine
PROC_DATA = data/process/
PROC_RUNSPATH = $(addprefix $(PROC_DATA),$(RUNS))

# Location of references
REFS = data/references/

# Utility function
print-%:
	@echo '$*=$($*)'


# Let's get ready to rumble...




################################################################################
#
#	Part 1: Get the reference files
#
#	Here we give instructions on how to get the necessary reference files that
#	are used throughout the rest of the analysis. These are used to calculate
#	error rates, generate alignments, and classify sequences. We will pull down
#	the mock community reference (HMP_MOCK.fasta), the silva reference alignment
#	(silva.bacteria.align), and the RDP training set data (trainset9_032012).
#	Finally, we use the HMP_MOCK.align to get the alignment coordinates for the
#	V3-V4, V4, and V4-V5 data. These data will be stored in the data/references/
#	folder.
#
#	The targets in this part are all used as dependencies in other rules
#
################################################################################

#Location of reference files
REFS = data/references/

#get the silva reference alignment
$(REFS)silva.bacteria.align :
	wget -N -P $(REFS) http://www.mothur.org/w/images/9/98/Silva.bacteria.zip; \
	unzip -o $(REFS)Silva.bacteria.zip -d $(REFS) silva.bacteria/silva.bacteria.fasta; \
	mv $(REFS)silva.bacteria/silva.bacteria.fasta $(REFS)silva.bacteria.align; \
	rm -rf $(REFS)silva.bacteria

#get the mock community reference sequences
$(REFS)HMP_MOCK.fasta :
	wget -N -P $(REFS) http://www.mothur.org/MiSeqDevelopmentData/HMP_MOCK.fasta

#align the mock community reference sequeces
$(REFS)HMP_MOCK.align : $(REFS)HMP_MOCK.fasta $(REFS)silva.bacteria.align
	mothur "#align.seqs(fasta=$(REFS)HMP_MOCK.fasta, reference=$(REFS)silva.bacteria.align)"

#get the rdp training set data
$(REFS)trainset9_032012.pds.tax $(REFS)trainset9_032012.pds.fasta :
	wget -N -P $(REFS) http://www.mothur.org/w/images/5/59/Trainset9_032012.pds.zip;
	unzip -o $(REFS)Trainset9_032012.pds.zip -d $(REFS)

# Find the start/end coordinates for each region within the alignment space
$(REFS)start_stop.positions : code/get_region_coordinates.sh $(REFS)HMP_MOCK.align
	bash code/get_region_coordinates.sh



################################################################################
#
#	Part 2: Get the raw sequence data
#
#	Here we will pull down the fastq files generated by the sequencer that are
#	stored on our public server. We will also go ahead and decompress the *.gz
#	files and run them through fastq.info in mothur to generate separate
#	*.fasta and *.qual files that can be used in subsequent analyses. All of
#	these data are stored in the data/raw folder.
#
#	The targets in this part are all used as dependencies in other rules
#
################################################################################

# Download all of the fastq files
ALL_FASTQ = $(foreach R, $(RAW_RUNSPATH), $(foreach F, $(FASTQS), $(R)/$(F)))

$(ALL_FASTQ) :
	wget -N -P $(dir $@) http://www.mothur.org/MiSeqDevelopmentData/$(patsubst data/raw/%/,%, $(dir $@)).tar
	tar xvf $(dir $@)*.tar -C $(dir $@); \
	bunzip2 -f $(dir $@)*bz2; \
	rm $(dir $@)*.tar


# Let's open up all of the fastq files by running them through fastq.info
RAW_FASTA = $(subst fastq,fasta,$(ALL_FASTQ))
RAW_QUAL = $(subst fastq,qual,$(ALL_FASTQ))

.SECONDEXPANSION:
$(RAW_FASTA) : $$(subst fasta,fastq,$$@)
	mothur "#fastq.info(fastq=$(subst fasta,fastq,$@))"

.SECONDEXPANSION:
$(RAW_QUAL) : $$(subst qual,fastq,$$@)
	mothur "#fastq.info(fastq=$(subst qual,fastq,$@))"



################################################################################
#
#	Part 3: Analyze the error rates for the single sequence reads
#
#	Here we take the forward and reverse sequence read data and assess the error
#	rate and the type of errors that occur in the read. This analysis is only
#	performed on the Mock community sequence data. These data will be used to
#	generate Figure 2 and Table 1 in the paper
#
#	need to do:
#		make single_read_analysis
#
################################################################################

# The mock community fastq files
MOCK_FQ = Mock1_S1_L001_R1_001.fastq Mock1_S1_L001_R2_001.fastq \
		Mock2_S2_L001_R1_001.fastq Mock2_S2_L001_R2_001.fastq \
		Mock3_S3_L001_R1_001.fastq Mock3_S3_L001_R2_001.fastq

# Get the names of the Mock community fastq files
RAW_MOCK_FQ = $(foreach R, $(RAW_RUNSPATH), $(foreach F, $(MOCK_FQ), $(R)/$(F)))
RAW_MOCK_FA = $(subst fastq,fasta,$(RAW_MOCK_FQ))


# We want to get the error data for the individual Mock community sequence reads
# from each sequencing run
PROC_MOCK_TEMP = $(subst R2_001,R2_001.rc, $(subst raw,process,$(RAW_MOCK_FA)))
ERR_MATRIX = $(subst fasta,filter.error.matrix,$(PROC_MOCK_TEMP))
ERR_FORWARD = $(subst fasta,filter.error.seq.forward,$(PROC_MOCK_TEMP))
ERR_REVERSE = $(subst fasta,filter.error.seq.reverse,$(PROC_MOCK_TEMP))
ERR_QUAL = $(subst fasta,filter.error.quality,$(PROC_MOCK_TEMP))

# We want to find the start / end position for each pair of reads
# ALIGN_SUMMARY = $(subst fasta,summary,$(PROC_MOCK_TEMP))


# Here we make sure we have the substitution matrix to characterize the types
# of errors
.SECONDEXPANSION:
$(ERR_MATRIX) : $(REFS)HMP_MOCK.align code/single_read_analysis.sh \
					$$(subst .rc,,$$(subst filter.error.matrix,fasta,$$(subst process,raw, $$@))) \
					$$(subst .rc,,$$(subst filter.error.matrix,qual,$$(subst process,raw, $$@)))
	$(eval FASTA=$(subst .rc,,$(subst filter.error.matrix,fasta,$(subst process,raw, $@)))) \
	bash code/single_read_analysis.sh $(FASTA)


# Here we make sure we have the error rate for the first read along its length;
# will be used in Figure 2
.SECONDEXPANSION:
$(ERR_FORWARD) : $(REFS)HMP_MOCK.align code/single_read_analysis.sh \
					$$(subst .rc,,$$(subst filter.error.seq.forward,fasta,$$(subst process,raw, $$@))) \
					$$(subst .rc,,$$(subst filter.error.seq.forward,qual,$$(subst process,raw, $$@)))
	$(eval FASTA=$(subst .rc,,$(subst filter.error.seq.forward,fasta,$(subst process,raw, $@)))) \
	bash code/single_read_analysis.sh $(FASTA)

# Here we make sure we have the error rate for the second read along its length;
# will be used in Figure 2
.SECONDEXPANSION:
$(ERR_REVERSE) : $(REFS)HMP_MOCK.align code/single_read_analysis.sh \
					$(subst .rc,,$$(subst filter.error.seq.reverse,fasta,$$(subst process,raw, $$@))) \
					$(subst .rc,,$$(subst filter.error.seq.reverse,qual,$$(subst process,raw, $$@)))
	$(eval FASTA=$(subst .rc,,$(subst filter.error.seq.reverse,fasta,$(subst process,raw, $@)))) \
	bash code/single_read_analysis.sh $(FASTA)


# Here we get the quality scores associated with each error type; will be used
# in Figure 1
.SECONDEXPANSION:
$(ERR_QUAL) : $(REFS)HMP_MOCK.align code/single_read_analysis.sh \
					$$(subst .rc,,$$(subst filter.error.quality,fasta,$$(subst process,raw, $$@))) \
					$$(subst .rc,,$$(subst filter.error.quality,qual,$$(subst process,raw, $$@)))
	$(eval FASTA=$(subst .rc,,$(subst filter.error.quality,fasta,$(subst process,raw, $@)))) \
	bash code/single_read_analysis.sh $(FASTA)


# Here we get the alignment coordinates for the aligned individual reads; not
# sure this is actually needed
# .SECONDEXPANSION:
# (ALIGN_SUMMARY) : $(REFS)HMP_MOCK.align code/single_read_analysis.sh \
#					$$(subst .rc,,$$(subst summary,fasta,$$(subst process,raw, $$@))) \
#					$$(subst .rc,,$$(subst summary,qual,$$(subst process,raw, $$@)))
#	$(eval FASTA=$(subst .rc,,$(subst summary,fasta,$(subst process,raw, $@)))) \
#	bash code/single_read_analysis.sh $(FASTA)



# Let's build a copy of Figure 2 from each of the runs...
FIGURE2 = $(addprefix results/figures/, $(addsuffix .figure2.png, $(RUNS)))

build_figure2 :

$(FIGURE2) : code/paper_figure2.R \
		$(addprefix data/process/,$(addsuffix /Mock1_S1_L001_R1_001.filter.error.seq.forward,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock2_S2_L001_R1_001.filter.error.seq.forward,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock3_S3_L001_R1_001.filter.error.seq.forward,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock1_S1_L001_R2_001.rc.filter.error.seq.reverse,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock2_S2_L001_R2_001.rc.filter.error.seq.reverse,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock3_S3_L001_R2_001.rc.filter.error.seq.reverse,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock1_S1_L001_R1_001.filter.error.quality,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock2_S2_L001_R1_001.filter.error.quality,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock3_S3_L001_R1_001.filter.error.quality,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock1_S1_L001_R2_001.rc.filter.error.quality,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock2_S2_L001_R2_001.rc.filter.error.quality,$(patsubst results/figures/%.figure2.png,%, $@))) \
		$(addprefix data/process/,$(addsuffix /Mock3_S3_L001_R2_001.rc.filter.error.quality,$(patsubst results/figures/%.figure2.png,%, $@)))
	R -e "source('code/paper_figure2.R');make.figure2('$(patsubst results/figures/%.figure2.png,%, $@)')"



# The one rule that is needed to get everything for Part 3
# * $(FIGURE2): builds Figure 2, which describes the different types of errors
# * $(ERR_MATRIX): Needed in Rmd file to describe the types and frequencies of
#	errors that are seen
# * $(ERR_QUAL): The quality scores that are observed for each type. Used in
#	regression analysis

single_read_analysis :  $(FIGURE2) $(ERR_MATRIX) $(ERR_QUAL)




################################################################################
#
#	Part 4: Analyze the error rates for the contigs with different delta Q
#	values
#
#	Here we take the forward and reverse sequence read data and make contigs
#	between them using different deltaQ values as a threshold to pick a basecall
#	when there is a discrepancy between them. We then calculate the error
#	rate for the assembled contigs. This analysis is only performed on the Mock
#	community sequence data. These data will be used to generate Figure 3,
# 	parts of Table 2, and analyses within the paper.
#
#	need to do:
#		make deltaq_analysis
#
#
################################################################################


# We want to build contigs with between 0 and 10 quality score differences using
# the mock community libraries

DIFFS =  0 1 2 3 4 5 6 7 8 9 10
FOR_MOCK_FQ = Mock1_S1_L001_R1_001.fastq Mock2_S2_L001_R1_001.fastq Mock3_S3_L001_R1_001.fastq
FILE_STUB = $(subst fastq,,$(FOR_MOCK_FQ))

QDIFF_CONTIG_FA = $(addsuffix .contigs.fasta,$(foreach P, $(PROC_RUNSPATH), $(foreach F, $(FILE_STUB), $(foreach D, $(DIFFS), $(P)/$(F)$(D)))))


# Assemble reads into contigs by altering the deltaQ parameter in make.contigs
.SECONDEXPANSION:
$(QDIFF_CONTIG_FA) : $$(addsuffix .fastq,$$(basename $$(subst .contigs.fasta,, $$(subst process,raw,$$@)))) \
					$$(addsuffix .fastq,$$(subst R1,R2,$$(basename $$(subst .contigs.fasta,, $$(subst process,raw,$$@))))) \
					code/titrate_deltaq.sh
	$(eval FFASTQ=$(basename $(subst .contigs.fasta, , $(subst process,raw,$@))).fastq) \
	$(eval RFASTQ=$(subst R1,R2,$(basename $(subst .contigs.fasta, , $(subst process,raw,$@)))).fastq) \
	$(eval QDEL=$(subst .,,$(suffix $(subst .contigs.fasta, , $(subst process,raw,$@))))) \
	bash code/titrate_deltaq.sh $(FFASTQ) $(RFASTQ) $(QDEL)


# Now we want to take those contigs and get their alignment positions in the
# reference alignment space and quantify the error rate
CONTIG_ALIGN_SUMMARY = $(subst fasta,summary,$(QDIFF_CONTIG_FA))
CONTIG_ERROR_SUMMARY = $(subst fasta,filter.error.summary,$(QDIFF_CONTIG_FA))

.SECONDEXPANSION:
$(CONTIG_ALIGN_SUMMARY) : $$(subst summary,fasta,$$@) code/contig_error_analysis.sh
	bash code/contig_error_analysis.sh $(subst summary,fasta,$@)

.SECONDEXPANSION:
$(CONTIG_ERROR_SUMMARY) : $$(subst error.summary,fasta,$$@) code/contig_error_analysis.sh
	bash code/contig_error_analysis.sh $(subst filter.error.summary,fasta,$@)


# Now we need to get the region that each contig belongs to...
CONTIG_V34_ACCNOS = $(subst summary,v34.accnos,$(CONTIG_ALIGN_SUMMARY))
CONTIG_V4_ACCNOS = $(subst summary,v4.accnos,$(CONTIG_ALIGN_SUMMARY))
CONTIG_V45_ACCNOS = $(subst summary,v45.accnos,$(CONTIG_ALIGN_SUMMARY))

CONTIG_REGION = $(subst summary,region,$(CONTIG_ALIGN_SUMMARY))
CONTIG_ACCNOS = $(CONTIG_V34_ACCNOS) $(CONTIG_V4_ACCNOS) $(CONTIG_V45_ACCNOS)

get_contig_region : $(CONTIG_REGION) $(CONTIG_ACCNOS)

.SECONDEXPANSION:
$(CONTIG_REGION) : code/split_error_summary.R $$(subst region,summary, $$@)
	R -e 'source("code/split_error_summary.R"); contig_split("$(strip $(subst region,summary, $@))")'

.SECONDEXPANSION:
$(CONTIG_ACCNOS) : code/split_error_summary.R $$(subst accnos,summary, $$@)
	R -e 'source("code/split_error_summary.R"); contig_split("$(strip $(subst accnos,summary, $@))")'


# Let's summarize the error rates and % of reads remaining for each deltaQ
# value. These tables will be useful for synthesizing them together to make
# Table 2 and Figure 3
DELTAQ_ERROR = $(addsuffix /deltaq.error.summary, $(PROC_RUNSPATH))

.SECONDEXPANSION:
$(DELTAQ_ERROR) : code/summarize_error_deltaQ.R \
					$$(filter $$(addsuffix  /%, $$(dir $$@)),$$(CONTIG_ERROR_SUMMARY)) \
					$$(filter $$(addsuffix  /%, $$(dir $$@)),$$(CONTIG_REGION))
	$(eval RUN=$(subst data/process/,,$(subst /deltaq.error.summary,,$@))) \
	R -e "source('code/summarize_error_deltaQ.R'); get.summary($(RUN))"


# Let's build Figure 3...
FIGURE3 = $(addsuffix .figure3.png,$(addprefix results/figures/, $(RUNS)))

results/figures/%.figure3.png : code/paper_figure3.R data/process/%/deltaq.error.summary
		$(eval RUN=$(patsubst results/figures/%.figure3.png,%,$@)) \
		R -e "source('code/paper_figure3.R'); make.figure2($(RUN))";



deltaq_analysis: $(FIGURE3)




################################################################################
#
#	Part 5: Determine the number of OTUs that are observed for the various
#	regions and in the different samples under varyious conditions
#
#	Here we form contigs using a deltaQ of 6 for the 12 libraries and then
#	run them through the standard mothur pipeline to do several things...
#
#	1.	Determine the number of OTUs we'd get from the mock commmunity with no
#		sequencing error and perfect chimera removal
#	2.	Determine the number of OTUs we'd get from the mock community with
#		perfect chimera removal.
#	3.	Determine the number of OTUs we'd get with the use of UCHIME to remove
#		chimeras.
#	4.	Calculate the error rate for the mock community after applying the
#		pre-cluster denoising algorithm.
#
#	These data will be used for parts of Table 2 and analyses within the paper.
#
#	need to do:
#		make otu_analysis
#
#
################################################################################


# Now we want to make sure we have all of the contigs for the 12 libraries using
# a qdel of 6...
DELTA_Q = 6
FINAL_CONTIGS = $(strip $(foreach P, $(PROC_RUNSPATH), $(foreach F, $(subst fastq,6.contigs.fasta, $(F_FASTQS)), $P/$F)))

build_all_contigs : $(FINAL_CONTIGS) code/build_final_contigs.sh

# excluding the Mocks, which we have a rule for above...
.SECONDEXPANSION:
$(filter-out $(QDIFF_CONTIG_FA),$(FINAL_CONTIGS)) : code/build_final_contigs.sh \
				$$(subst R1_001.6.contigs.fasta,R1_001.fastq, $$(subst process,raw, $$@)) \
				$$(subst R1_001.6.contigs.fasta,R2_001.fastq, $$(subst process,raw, $$@))
	bash code/build_final_contigs.sh $(DELTA_Q)  \
		$(subst R1_001.6.contigs.fasta,R1_001.fastq, $(subst process,raw, $@)) \
		$(subst R1_001.6.contigs.fasta,R2_001.fastq, $(subst process,raw, $@))



# Now we want to split the files into the three different regions using
# screen.seqs and the positions that we determined earlier in
# [$(REFS)start_stop.positions] and run the resulting contigs through the basic
# mothur pipeline where we...
# 	* align
# 	* screen.seqs
# 	* filter (v=T, t=.)
# 	* unique
# 	* precluster
# 	* chimera.uchime
# 	* remove.seqs
# 	* dist.seqs
# 	* cluster
# 	* rarefy
# There are a ton of files produced here, but we will only keep a subset and we
# will make the *.ave-std.summary file created for each region the only target.
# We also only really want to run this on our final set of contigs - those with
# qdel == 6, which are stored in $(FINAL_CONTIGS).
#
# So that we can calculate the error rate of the preclustered data, we will
# break the pipeline into two parts


# First, we'll go from contigs through the pre-cluster step
PRECLUSTER_FASTA = $(subst fasta,v34.filter.unique.precluster.fasta,$(FINAL_CONTIGS)) \
		$(subst fasta,v4.filter.unique.precluster.fasta,$(FINAL_CONTIGS)) \
		$(subst fasta,v45.filter.unique.precluster.fasta,$(FINAL_CONTIGS))
PRECLUSTER_NAMES = $(subst fasta,names,$(PRECLUSTER_FASTA))

.SECONDEXPANSION:
$(PRECLUSTER_FASTA) : $$(addsuffix .fasta, $$(basename $$(subst .filter.unique.precluster.fasta,,$$@))) code/split_big_contigs.sh
	bash code/split_big_contigs.sh $<

.SECONDEXPANSION:
$(PRECLUSTER_NAMES) : $$(addsuffix .fasta, $$(basename $$(subst .filter.unique.precluster.names,,$$@))) code/split_big_contigs.sh
	bash code/split_big_contigs.sh $<

# Now let's get the error rate of the pre-clustered data for the Mock
# community libraries
MOCK_PC_ERROR = $(addsuffix .filter.unique.precluster.error.summary,$(foreach R,v34 v4 v45,$(foreach P, $(PROC_RUNSPATH),$(foreach F, $(FILE_STUB),$(P)/$(F)6.contigs.$(R)))))

.SECONDEXPANSION:
$(MOCK_PC_ERROR) : data/references/HMP_MOCK.fasta $$(subst error.summary,fasta,$$@) $$(subst error.summary,names,$$@)
	$(eval FASTA=$(subst error.summary,fasta,$@)) \
	$(eval NAMES=$(subst error.summary,names,$@)) \
	mothur "#seq.error(fasta=$(FASTA), name=$(NAMES), reference=data/references/HMP_MOCK.fasta, aligned=F, processors=12)"



# Next, we'll take the pre-clustered data all the way through the rest of the
# pipeline and we'll rarefy the number of OTUs to 5000 reads per library
FULL_SUMMARY = $(subst fasta,v4.filter.unique.precluster.pick.an.ave-std.summary,$(FINAL_CONTIGS)) \
		$(subst fasta,v34.filter.unique.precluster.pick.an.ave-std.summary,$(FINAL_CONTIGS)) \
		$(subst fasta,v45.filter.unique.precluster.pick.an.ave-std.summary,$(FINAL_CONTIGS))

.SECONDEXPANSION:
$(FULL_SUMMARY) : $$(subst .pick.an.ave-std.summary,.fasta,$$@) $$(subst .pick.an.ave-std.summary,.names,$$@)  code/get_summary_from_precluster.sh
	bash code/get_summary_from_precluster.sh $(subst .pick.an.ave-std.summary,.fasta,$@) $(subst .pick.an.ave-std.summary,.names,$@)



# Now we'll find the numbrer of OTUs that we'd get out if we were perfect in our
# ability to remove chimeras using the Mock community data
NO_CHIMERAS_AVE_SUMMARY = $(subst error.summary,perfect.an.ave-std.summary, $(MOCK_PC_ERROR))

.SECONDEXPANSION:
$(NO_CHIMERAS_AVE_SUMMARY) :  $$(subst perfect.an.ave-std.summary,error.summary, $$@) $$(subst perfect.an.ave-std.summary,fasta, $$@) $$(subst perfect.an.ave-std.summary,names, $$@) code/get_sobs_nochimera.sh
	bash code/get_sobs_nochimera.sh $(subst perfect.an.ave-std.summary,error.summary, $@)



# Let's see how many OTUs there would be without any sequencing errors or
# chimeras...
$(MOCK_PERFECT_SOBS) : code/noseq_error_analysis.sh
	bash code/noseq_error_analysis.sh




otu_analysis : $(MOCK_PC_ERROR) $(FULL_SUMMARY) $(NO_CHIMERAS_AVE_SUMMARY) $(MOCK_PERFECT_SOBS)



# Finally, let's synthesize the results of Parts 4 and 5 to generate Table 2
results/tables/table_2.tsv : $(DELTAQ_ERROR) $(MOCK_PERFECT_SOBS) \
							$(NO_CHIMERAS_AVE_SUMMARY) $(FULL_SUMMARY) \
							$(MOCK_PC_ERROR) code/build_table2.R
	R -e 'source("code/build_table2.R")'





################################################################################
#
#	Part 6: Case study application to samples collected by Schloss et al.
#
#	Here we run the new MiSeq SOP on samples that were previously generated and
#	published by Schloss et al. in Gut Microbes. This culminates in an
#	ordination of the mouse data as well as a calculation of the observed error
#	rate.
#
#	need to do:
#		make stability_analysis
#
#
################################################################################



# Let's get the raw data
data/raw/no_metag/no_metag.files : code/get_contigsfile.R
	wget -N -P data/raw/no_metag http://www.mothur.org/MiSeqDevelopmentData/StabilityNoMetaG.tar; \
	tar xvf data/raw/no_metag/StabilityNoMetaG.tar -C data/raw/no_metag/; \
	gunzip -f data/raw/no_metag/*gz; \
	rm data/raw/no_metag/StabilityNoMetaG.tar; \
	R -e 'source("code/get_contigsfile.R");get_contigsfile("data/raw/no_metag")'

data/raw/w_metag/w_metag.files : code/get_contigsfile.R
	wget -N -P data/raw/w_metag http://www.mothur.org/MiSeqDevelopmentData/StabilityWMetaG.tar; \
	tar xvf data/raw/w_metag/StabilityWMetaG.tar -C data/raw/w_metag/; \
	gunzip -f data/raw/w_metag/*gz; \
	rm data/raw/w_metag/StabilityWMetaG.tar; \
	R -e 'source("code/get_contigsfile.R");get_contigsfile("data/raw/w_metag")'


# first we'll run hte sequences through the chimera checking, classification,
# and contaminant removal...
data/process/no_metag/no_metag.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.fasta : code/get_good_seqs_mice.sh data/raw/no_metag/no_metag.files
	bash code/get_good_seqs_mice.sh data/raw/no_metag/no_metag.files

data/process/w_metag/w_metag.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.fasta : code/get_good_seqs_mice.sh data/raw/no_metag/no_metag.files
	bash code/get_good_seqs_mice.sh data/raw/w_metag/w_metag.files

data/process/no_metag/no_metag.trim.contigs.good.unique.good.filter.unique.precluster.uchime.pick.pick.count_table : code/get_good_seqs_mice.sh data/raw/no_metag/no_metag.files
	bash code/get_good_seqs_mice.sh data/raw/no_metag/no_metag.files

data/process/w_metag/w_metag.trim.contigs.good.unique.good.filter.unique.precluster.uchime.pick.pick.count_table : code/get_good_seqs_mice.sh data/raw/no_metag/no_metag.files
	bash code/get_good_seqs_mice.sh data/raw/w_metag/w_metag.files

data/process/no_metag/no_metag.trim.contigs.good.unique.good.filter.unique.precluster.pick.pds.wang.pick.taxonomy : code/get_good_seqs_mice.sh data/raw/no_metag/no_metag.files
	bash code/get_good_seqs_mice.sh data/raw/no_metag/no_metag.files

data/process/w_metag/w_metag.trim.contigs.good.unique.good.filter.unique.precluster.pick.pds.wang.pick.taxonomy : code/get_good_seqs_mice.sh data/raw/no_metag/no_metag.files
	bash code/get_good_seqs_mice.sh data/raw/w_metag/w_metag.files


# now we'll get the shared and cons.taxonomy file
%.pick.pick.pick.an.unique_list.shared : %.pick.pick.fasta %.uchime.pick.pick.count_table %.pick.pds.wang.pick.taxonomy code/get_shared_mice.sh
	$(eval FASTA=$(patsubst %.pick.pick.pick.an.unique_list.shared,%.pick.pick.fasta,$@)) \
	$(eval COUNT=$(patsubst %.pick.pick.pick.an.unique_list.shared,%.uchime.pick.pick.count_table,$@)) \
	$(eval TAXONOMY=$(patsubst %.pick.pick.pick.an.unique_list.shared,%.pick.pds.wang.pick.taxonomy,$@)) \
	bash code/get_shared_mice.sh $(FASTA) $(COUNT) $(TAXONOMY)

%.pick.pick.pick.an.unique_list.0.03.cons.taxonomy : %.pick.pick.fasta %.uchime.pick.pick.count_table %.pick.pds.wang.pick.taxonomy code/get_shared_mice.sh
	$(eval FASTA=$(patsubst %.pick.pick.pick.an.unique_list.0.03.cons.taxonomy,%.pick.pick.fasta,$@)) \
	$(eval COUNT=$(patsubst %.pick.pick.pick.an.unique_list.0.03.cons.taxonomy,%.uchime.pick.pick.count_table,$@)) \
	$(eval TAXONOMY=$(patsubst %.pick.pick.pick.an.unique_list.0.03.cons.taxonomy,%.pick.pds.wang.pick.taxonomy,$@)) \
	bash code/get_shared_mice.sh $(FASTA) $(COUNT) $(TAXONOMY)


# now we'll get the rarefied distance file
%.thetayc.0.03.lt.ave.dist : %.shared
	$(eval STUB=$(patsubst %.thetayc.0.03.lt.ave.dist,%,$@)) \
	mothur "#dist.shared(shared=$(STUB).shared, calc=thetayc, subsample=3000, iters=100, processors=8);" \
	rm $(STUB).thetayc.0.03.lt.dist \
	rm $(STUB).thetayc.0.03.lt.std.dist


# now we'll get the nmds axes files
%.nmds.axes : %.dist
	$(eval STUB=$(patsubst %.nmds.axes,%,$@)) \
	mothur "#nmds(phylip=$(STUB).dist, maxdim=2);" \
	rm $(STUB).nmds.iters \
	rm $(STUB).nmds.stress


# now we'll plot the nmds axes file
get_figure4 : results/figures/no_metag.figure4.png results/figures/w_metag.figure4.png

results/figures/no_metag.figure4.png : data/process/no_metag/no_metag.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.an.unique_list.thetayc.0.03.lt.ave.nmds.axes code/plot_nmds.R
	R -e 'source("code/plot_nmds.R"); plot_nmds("$<")'

results/figures/w_metag.figure4.png : data/process/w_metag/w_metag.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.pick.an.unique_list.thetayc.0.03.lt.ave.nmds.axes code/plot_nmds.R
	R -e 'source("code/plot_nmds.R"); plot_nmds("$<")'


# finally, we'll get the error rate from the mock community samples
get_mice_error : data/process/no_metag/no_metag.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.mock.error.summary \
				data/process/w_metag/w_metag.trim.contigs.good.unique.good.filter.unique.precluster.pick.pick.mock.error.summary

%.pick.pick.mock.error.summary : %.pick.pick.fasta %.uchime.pick.pick.count_table code/get_error_mice.sh
	$(eval FASTA=$(patsubst %.pick.pick.mock.error.summary,%.pick.pick.fasta,$@)) \
	$(eval COUNT=$(patsubst %.pick.pick.mock.error.summary,%.uchime.pick.pick.count_table,$@)) \
	bash code/get_error_mice.sh $(FASTA) $(COUNT)

stability_analysis : get_figure4 get_mice_error


# To do:
# * Generate Table S2


write.paper : single_read_analysis \
	 			deltaq_analysis \
				otu_analysis \
				stability_analysis \
				data/references/run_data.tsv \
				results/pictures/figure1.png \
				results/tables/table_2.tsv \
				Kozich_AEM_2013.Rmd
	R -e 'library("knitr");knit2html("Kozich_AEM_2013.Rmd")'
