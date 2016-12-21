#!/bin/bash -l

#. /usr/share/Modules/init/bash
###This wrapper script validates the input arguments and creates the job-control.txt file which is needed to submit the qsub array job to the cluster.###

while getopts :f:r:o: option
do
    case $option in
        f) fastq_list=$OPTARG;;
        r) allDB_dir=$OPTARG;;
        o) output_dir=$OPTARG;;
    esac
done

###Check if fastq file list and reference database directory arguments were given and if they exist###
if [[ ! -z "$fastq_list" ]]
then
    if [[ -s "$fastq_list" ]]
    then
	fastq_list=$(echo "$fastq_list" | sed 's/\/$//g')
	echo "The fastq file list is in the following location: $fastq_list"
    else
	echo "This fastq file list is not in the correct format or doesn't exist."
	echo "Make sure you provide the full directory path (/root/path/file.txt)."
exit 1
    fi
else
    echo "No fastq file list argument given."
    exit 1
fi

if [[ ! -z "$allDB_dir" ]]
then
    if [[ -d "$allDB_dir" ]]
    then
	allDB_dir=$(echo "$allDB_dir" | sed 's/\/$//g')
	echo "The references directory is in the following location: $allDB_dir"
    else
	echo "This reference directory is not in the correct format or doesn't exist."
	echo "Make sure you provide the full directory path (/root/path/reference_directory)."
exit 1
    fi
else
    echo "No reference database directory path argument given."
    exit 1
fi

###Check if the output directory argument has been given. If yes, create the 'SPN_Typing_Output' and 'qsub_files' folders within the output dir###
###If no, output the results into a subdirectory of '~/GBS_Typing_Analysis'. The subdirectory name is extracted from the batch sequence full path###
if [[ -z "$output_dir" ]]
then
    echo "The files will be output into the default directory 'SPN_Typing_Analysis'."
    if [[ ! -d ~/SPN_Typing_Analysis ]]
    then
        mkdir ~/SPN_Typing_Analysis
        out_dir="~/GBS_Typing_Analysis"
        eval out_dir=$out_dir
        echo "The output directory has been created: $out_dir"
    else
        out_dir="~/SPN_Typing_Analysis"
        eval out_dir=$out_dir
    fi
    batch_name=$(echo "$batch_dir" | awk -F"/" '{print $(NF-3)}')
    out_analysis="${out_dir}"/"${batch_name}"/SPN_Typing_Output
    out_qsub="${out_dir}"/"${batch_name}"/qsub_files/
    out_jobCntrl="${out_dir}/${batch_name}/"
    eval out_analysis=$out_analysis
    eval out_qsub=$out_qsub
    eval out_jobCntrl=$out_jobCntrl
    mkdir -p "$out_analysis"
    mkdir -p "$out_qsub"
elif [[ ! -d "$output_dir" ]]
then
    output_dir=$(echo "$output_dir" | sed 's/\/$//g')
    mkdir "$output_dir"
    out_dir="$output_dir"
    eval out_dir=$out_dir
    echo "The output directory has been created: $out_dir"
    out_analysis="${out_dir}"/SPN_Typing_Output
    out_qsub="${out_dir}"/qsub_files/
    out_jobCntrl="${out_dir}/"
    eval out_analysis=$out_analysis
    eval out_qsub=$out_qsub
    eval out_jobCntrl=$out_jobCntrl
    mkdir -p "$out_analysis"
    mkdir -p "$out_qsub"
else
    output_dir=$(echo "$output_dir" | sed 's/\/$//g')
    out_dir="$output_dir"
    eval out_dir=$out_dir
    out_analysis="${out_dir}"/SPN_Typing_Output
    out_qsub="${out_dir}"/qsub_files/
    out_jobCntrl="${out_dir}/"
    eval out_analysis=$out_analysis
    eval out_qsub=$out_qsub
    eval out_jobCntrl=$out_jobCntrl
    mkdir -p "$out_analysis"
    mkdir -p "$out_qsub"
fi




###Start Doing Stuff###
#batch_dir=$(basename "$fastq_list" | sed 's/\..*//g')
#printf "Sample\tSerotype\tST\taroe\tgdh_\tgki_\trecP\tspi_\txpt_\tddl_\tPBP_Code(1A:2B:2X)\tMisc_Resistance\tGen_Resistance\tPlasmid_Target\n" >> "$out_analysis"/TABLE_SPN_"$batch_dir"_Typing_Results.txt

###This loop will read thru the fastq file list and look for read 1 of each paired end file. It will then make sure the 2nd pair also exists and, if so, will print out 
###the required information to the job-control.txt file
while read path
do
    #echo "$path"
    if [[ $path =~ .*_1\.fastq\.gz$ ]]
    then
	#echo "found a read pair 1!!"
	read_1="$path"
	read_2=$(echo "$read_1" | sed 's/_1.fastq.gz$/_2.fastq.gz/g')
	if [ -s "$read_1" -a -s "$read_2" ]
	    then
	        sampl_name=$(basename "$read_1" | sed 's/_1.fastq.gz$//g')
		    sampl_out="${out_analysis}"/"${sampl_name}"
    eval sample_out=$sampl_out
    echo "For sample $sampl_name both forward and reverse read files exist"
    if [[ ! -d "$sampl_out" ]]
	    then
	mkdir "$sampl_out"
	    fi
        echo "$read_1 $read_2 $allDB_dir $out_analysis $sampl_out"
        echo "$read_1 $read_2 $allDB_dir $out_analysis $sampl_out" >> $out_jobCntrl/job-control.txt
	fi
    fi
done < "$fastq_list"

###Send the jobs out on the cluster with each sample running in parallel###
#qsub -sync y -q all.q -t 1-$(cat $out_jobCntrl/job-control.txt | wc -l) -cwd -o "$out_qsub" -e "$out_qsub" /nfs/users/nfs_b/bm17/bjm_bin/Sanger-JanOw_SPN-Typer.sh $out_jobCntrl
#bsub -G team81 -J SPN_Run[1-$(cat $out_jobCntrl/job-control.txt | wc -l)] -cwd -o ${out_qsub}output.%J -e ${out_qsub}errorfile.%J ./Sanger-JanOw_SPN-Typer.sh $out_jobCntrl
#bsub -G team81 -R"select[mem>10000] rusage[mem=10000]" -M10000 -J SPN_Run[1-2] -o ${out_qsub}output.%J.%I -e ${out_qsub}errorfile.%J.%I "sh Sanger-JanOw_SPN-Typer.sh $out_jobCntrl"

bsub -G team81 -R"select[mem>10000] rusage[mem=10000]" -M10000 -J SPN_Run[1-$(cat $out_jobCntrl/job-control.txt | wc -l)] -o ${out_qsub}output.%J.%I -e ${out_qsub}errorfile.%J.%I "sh Sanger-JanOw_SPN-Typer.sh $out_jobCntrl"
sleep 30

while [[ $(bjobs -noheader | wc -l) -ne 0 ]]
do
    jobNum=$(bjobs -noheader | wc -l)
    echo "Jobs are still running | $jobNum"
    sleep 120
done

###Output the emm type/MLST/drug resistance data for this sample to it's results output file###
batch_name=$(head -n1 $out_jobCntrl/job-control.txt | awk -F" " '{print $5}' | awk -F"/" '{print $(NF-2)}')
#printf "Sample\tSerotype\tST\taroe\tgdh_\tgki_\trecP\tspi_\txpt_\tddl_\tPBP_Code(1A:2B:2X)\tMisc_Resistance\tGen_Resistance\tPlasmid_Target\n" >> "$out_analysis"/TABLE_SPN_"$batch_name"_Typing_Results.txt
printf "Sample\tPBP_Code(1A:2B:2X)\tMisc_Resistance\n" >> "$out_analysis"/TABLE_SPN_"$batch_name"_Typing_Results.txt
while read -r line
do
    batch_name=$(echo $line | awk -F" " '{print $5}' | awk -F"/" '{print $(NF-2)}')
    final_outDir=$(echo $line | awk -F" " '{print $5}')
    final_result_Dir=$(echo $line | awk -F" " '{print $4}')
    #cat $final_outDir/SAMPLE_Isolate__Typing_Results.txt >> $final_result_Dir/SAMPL_SPN_"$batch_name"_Typing_Results.txt
    cat $final_outDir/TABLE_Isolate_Typing_results.txt >> $final_result_Dir/TABLE_SPN_"$batch_name"_Typing_Results.txt
    if [[ -e $final_outDir/TEMP_newPBP_allele_info.txt ]]
    then
	cat $final_outDir/TEMP_newPBP_allele_info.txt >> $final_result_Dir/UPDATR_SPN_"$batch_name"_Typing_Results.txt
    fi
done < $out_jobCntrl/job-control.txt
