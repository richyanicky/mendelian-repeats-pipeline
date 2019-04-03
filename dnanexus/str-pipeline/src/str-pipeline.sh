#!/bin/bash
# str-toolkit 0.0.1
# Generated by dx-app-wizard.
#
# Basic execution pattern: Your app will run on a single machine from
# beginning to end.
#
# Your job's input variables (if any) will be loaded as environment
# variables before this script runs.  Any array inputs will be loaded
# as bash arrays.
#
# Any code outside of main() (or any entry point you may add) is
# ALWAYS executed, followed by running the entry point itself.
#
# See https://wiki.dnanexus.com/Developer-Portal for tutorials on how
# to modify this file.

# TODO Need these inputs in the json:
# bams: array of files
# reffasta: file
# regionfile: file
# strinfo : file
# famfile: file
# outprefix: string
# TODO Add other numerical input options later
# TODO how to index BAM files?
# TODO in future add to resources (instead of user inputs): reffa, strinfo, regionfile
main() {
    ### Download the user inputs to /data folder ###
    mkdir /data
    mkdir -p out/vcfs

    # BAM files
    bamsfiles=""
    for i in ${!bams[@]}
    do
        dx download "${bams[$i]}" -o /data/bams-$i.bam
	bamfiles="${bamfiles},/data/bams-$i.bam"
	dx-docker run -v /data/:/data quay.io/ucsc_cgl/samtools index /data/bams-$i.bam
    done
    bamfiles=$(echo $bamfiles | sed 's/,//')

    # Reference fasta file
    dx download "$reffasta" -o /data/ref.fa
    chroms=$(grep ">" /data/ref.fa | sed 's/^>//' | cut -f 1 -d' ')
    dx-docker run -v /data/:/data quay.io/ucsc_cgl/samtools faidx /data/ref.fa
    
    # Regions file
    dx download "$regionfile" -o /data/regions.bed

    # STR info
    dx download "$strinfo" -o /data/strinfo.bed

    # Fam file
    dx download "$famfile" -o /data/famfile.fam
    
    ### Construct the config file ###
    CONFIGFILE="/data/config.txt"
    echo "BAMS=${bamfiles}" > ${CONFIGFILE}
    echo "REFFA=/data/ref.fa" >> ${CONFIGFILE}
    echo "REGIONS=/data/regions.bed" >> ${CONFIGFILE}
    echo "STRINFO=/data/strinfo.bed" >> ${CONFIGFILE}
    echo "FAMFILE=/data/famfile.fam" >> ${CONFIGFILE}
    echo "CHROMS=${chroms}" >> ${CONFIGFILE}
    
    # Write output files to /results
    mkdir /data/results
    echo "OUTPREFIX=/data/results/${outprefix}" >> ${CONFIGFILE}
    
    # Use hard coded numbers for now.
    echo "MINCOV=20" >> ${CONFIGFILE}
    echo "MAXCOV=1000" >> ${CONFIGFILE}
    echo "EXPHET=0" >> ${CONFIGFILE}
    echo "AFFECMINHET=0.8" >> ${CONFIGFILE}
    echo "UNAFFMAXTOT=0.2" >> ${CONFIGFILE}
    echo "THREADS=1" >> ${CONFIGFILE} # TODO can we change this?

    ### Run the docker ###
    dx-docker run -v /data:/data gymreklab/gangstr-pipeline-2.4 ./run.sh ${CONFIGFILE}
    
    ### Upload the outputs to DNA Nexus ###
    for chrom in $chroms; do
	vcffile=/data/results/${outprefix}.${chrom}.filtered.sorted.vcf.gz
	vcfindex=${vcffile}.tbi
	id=$(dx upload ${vcffile} --brief)
	dx-jobutil-add-output vcfs "$id" --class=array:file
    done
}
