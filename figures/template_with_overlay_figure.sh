
#!/bin/bash
# Author: Saül Pascual-Diaz
# mail: spascual@ub.edu
# Department: Pain and Emotion Neuroscience Laboratory (PENLab)
# Version: 1.0
# Date: January 9, 2023

# Print the version information if the --version option is specified
if [[ $1 == "--version" || $1 == "-v" ]]; then
    echo "Version 1.0"
    exit 0
fi

# Print the help information if the --help option is specified
if [[ $1 == "--help" || $1 == "-h" || -z "${1}" ]]; then
    printf "This script takes a neuroimaging template (e.g. an MNI volume) and a folder containing overlay masks as inputs, and generates a series of slice captures showing the overlaying masks under the template image. The resulting images are stored in the output folder as PNG files.\n\n"
    echo "Usage:"
    printf "\tbash ${0} [--version, -v] [--help, -h] template_file input_path output_path coordinate_0 coordinate_f increment axis\n\n"
    echo "Arguments:"
    printf "\t- template_file: Path to the template image file (in nii or nii.gz formats).\n"
    printf "\t- input_path: Path to the input folder containing the overlay masks (in nii format).\n"
    printf "\t- output_path: Path to the output image files (in png format).\n"
    printf "\t- coordinate_0: Starting coordinate for the slice captures.\n"
    printf "\t- coordinate_f: Ending coordinate for the slice captures.\n"
    printf "\t- increment: Number of slices between captures.\n"
    printf "\t- axis: 0 for sagittal, 1 for coronal and 2 for axial.\n\n"
    echo "Requirements:"
    printf "\t- mrtrix3 (https://mrtrix.readthedocs.io/en/latest/)\n"
    printf "\t- imagemagick (https://imagemagick.org/)\n\n"
    echo "Examples:"
    printf "\tbash ${0} --version\n"
    printf "\tbash ${0} /usr/local/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz input_path output_path -66 66 10 0\n"
    exit 0
fi

if [[ $# -lt 7 ]]; then
    echo "This script requires 7 input parameters to run. To view the usage instructions, use the --help or -h option."
    exit 0
fi

if [[ ! -d $3 ]]; then
    mkdir -p $3
fi

transparency_gen () {
    # check that the required software is installed
    command -v convert >/dev/null 2>&1 || { echo >&2 "This script requires the 'convert' command from the ImageMagick suite, but it is not installed. Aborting."; exit 1; }

    # check that an input file was specified
    if [ $# -lt 1 ]; then
        echo "Usage: $0 input_file"
        exit 1
    fi

    # assign input file to a variable
    input_file=$1

    # check that the input file exists
    if [ ! -f "$input_file" ]; then
        echo "Error: the input file does not exist."
        exit 1
    fi

    # create output file name
    output_file=$(echo "$input_file" | sed -e "s/\.[^.]*$/.png/")

    # remove the color black from the input file and save as a transparent PNG
    convert "$input_file" -fuzz 10% -transparent black "$output_file"

    echo "Successfully removed black from $input_file and saved as $output_file"
}

slices_gen () {
    b_name=$(basename $(echo $2 | cut -d '.' -f1))
    cnt=0
    for i in $(seq $4 $6 $5); do

        if [ $cnt -lt 10 ]
        then
            label="0${cnt}"
        else 
            label="${cnt}"
        fi

        if [ ${7} -eq 0 ]; then
            mrview $1 -fov 245 -plane ${7}\
                -focus ${i},-18,18\
                -overlay.load $2 -overlay.colourmap 1\
                -overlay.threshold_min 0.00000001 \
                -overlay.load $2 -overlay.colourmap 2\
                -overlay.threshold_max -0.00000001 \
                -overlay.opacity 0.7 \
                -noannotations\
                -capture.folder $3 \
                -capture.prefix "${b_name}_slice_${label}-"\
                -capture.grab\
                -exit
                cnt=$(( cnt + 1 ))
        fi
        if [ ${7} -eq 1 ]; then
            mrview $1 -fov 245 -plane ${7}\
                -focus -1,${i},18\
                -overlay.load $2 -overlay.colourmap 1\
                -overlay.threshold_min 0.00000001 \
                -overlay.load $2 -overlay.colourmap 2\
                -overlay.threshold_max -0.00000001 \
                -overlay.opacity 0.7 \
                -noannotations\
                -capture.folder $3 \
                -capture.prefix "${b_name}_slice_${label}-"\
                -capture.grab\
                -exit
                cnt=$(( cnt + 1 ))
        fi
        if [ ${7} -eq 2 ]; then
            mrview $1 -fov 245 -plane ${7}\
                -focus -1,-18,${i}\
                -overlay.load $2 -overlay.colourmap 1\
                -overlay.threshold_min 0.00000001 \
                -overlay.load $2 -overlay.colourmap 2\
                -overlay.threshold_max -0.00000001 \
                -overlay.opacity 0.7 \
                -noannotations\
                -capture.folder $3 \
                -capture.prefix "${b_name}_slice_${label}-"\
                -capture.grab\
                -exit
                cnt=$(( cnt + 1 ))
        fi
        output_file="${3}/${b_name}_slice_${label}-0000.png"
        expected_output=${output_file::${#output_file}-9}
        $(set -x; mv $output_file "$expected_output.png")
    done
}

for mask_file in $(ls ${2}); do
    overlay_basename=$(echo ${mask_file} | cut -d "." -f1)
    input_overlay="${2}/${overlay_basename}.nii"

    # Run function
    slices_gen ${1} $input_overlay ${3} ${4} ${5} ${6} ${7}

    for in_file in $(ls ${3}); do
        echo "Removing the background for file ${3}/$in_file"
        transparency_gen ${3}/$in_file
    done

    file_list=""
    for in_file in $(ls ${3} | grep ${overlay_basename}); do
        file_list="$file_list ${3}/$in_file"
    done

    $(set -x; magick $file_list -background none -gravity Center +smush -30 ${3}/${overlay_basename}_merged.png)
done