#!/bin/bash
# Author: Haohao Zhang <haohaozhang@whut.edu.cn>
# Date: Jul 10, 2019

# Default
MIRROR="tuna"

# getopts
while getopts "d:" opt; do
    case $opt in
        d)
            CONDA_PREFIX=$OPTARG
            ;;
        m)
            MIRROR=$OPTARG
            ;;
        \?)
            echo "./hiblupInstaller.sh [-d <conda_prefix>] [-m 'tuna'|'official']"
            ;;
    esac
done

# Define
if [[ ${MIRROR} == "tuna" ]]; then
    CONDA_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/anaconda/miniconda
    CRAN_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/CRAN/
elif [[ ${MIRROR} == "official" ]]; then
    CONDA_MIRROR=https://repo.continuum.io/miniconda
    CRAN_MIRROR=http://cran.rstudio.com
else
    echo "Error: Unknow MIRROR."
    exit 1
fi


# OS
if [[ "$(uname)" == "Darwin" ]]; then
    CONDA_INSTALLER="Miniconda3-latest-MacOSX-x86_64.sh"
    HIBLUP_PACKAGE="hiblup_1.2.0_R_3.5.1_community_x86_64_macOS.tar.gz"
    R_VERSION="r-base=3.5.1"
    PROFILE="${HOME}/.bash_profile"
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
    CONDA_INSTALLER="Miniconda3-latest-Linux-x86_64.sh"
    HIBLUP_PACKAGE="hiblup_1.2.0_R_3.5.1_community_x86_64_Linux.tar.gz"
    R_VERSION="mro-base=3.5.1"
    PROFILE="~/.bashrc"
else
    echo "Error: Unknow OS."
    exit 1
fi

# Workdir
DIR=$(pwd)
TMP_DIR=$(mktemp -d -t hiblup-XXXXXXXX)
cd $TMP_DIR

# Install Miniconda3
if [[ ! $(command -v conda) ]]; then
    if [[ -z "${CONDA_PREFIX}" ]]; then
        CONDA_PREFIX=~/miniconda3
    fi
    echo "Warning: conda is not installed." >&2
    echo "Installing miniconda3 into ${CONDA_PREFIX}..."
    curl -O ${CONDA_MIRROR}/${CONDA_INSTALLER}
    bash ${CONDA_INSTALLER} -b -p ${CONDA_PREFIX}

    export PATH="${CONDA_PREFIX}/bin:$PATH"
    
    conda init bash
    conda config --set auto_activate_base false

    if [[ ${MIRROR} == "tuna" ]]; then
        conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/free/
        conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
        conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r/
        conda config --set show_channel_urls yes
    fi
fi

# hiblup command
HIBLUP_COMMAND="
hiblup () {
    source ${PROFILE}
    if [[ ! \$(command -v conda) ]]; then
        exit 1
    fi

    conda activate hiblup
    if [[ "\$\#" -lt 1 ]]; then
        R
    else
        Rscript \$@
    fi
    conda deactivate
}"

if [[ ! -z $(grep -Fxq "hiblup () {" ${PROFILE}) ]]; then
    # code if found
    echo "Warning: old hiblup function found."
else
    # code if not found
    echo "${HIBLUP_COMMAND}" >> ${PROFILE}
fi

conda init bash
source ${PROFILE}

# check conda
if [[ ! $(command -v conda) ]]; then
    echo "Error: command 'conda' not found"
    exit 1
fi

# Create or update conda env
conda create -n hiblup ${R_VERSION} r-essentials r-rcpp r-rcpparmadillo -y
conda activate hiblup

# Install hiblup
echo ""
echo "Downloading HIBLUP from https://raw.githubusercontent.com/hiblup/hiblup/master/${HIBLUP_PACKAGE} ..."
curl -O https://raw.githubusercontent.com/hiblup/hiblup/master/${HIBLUP_PACKAGE}

echo ""
echo "Installing HIBLUP ..."
Rscript -e "install.packages('bigmemory', repos='${CRAN_MIRROR}')"
Rscript -e "install.packages('${HIBLUP_PACKAGE}', repos=NULL)"

# R startup script
echo ".First <- function(){
  suppressMessages(library(hiblup))
  if('hiblup' %in% (.packages())) {
    # cat('hiblup has been loaded.')
    # cat('\\nWelcome at', date(), '\\n')
  } else {
    cat('Warning: library(hiblup) failed.\\n')
  }
}" > ${CONDA_PREFIX}/lib/R/etc/Rprofile.site


echo ""
echo "hiblup shortcut command has been installed to ${PROFILE}"
echo "Load it with the following command:"
echo "    source ${PROFILE}"
echo ""
echo "Usage:"
echo "$ hiblup"
echo "$ hiblup my_script.R"
echo ""

conda deactivate
cd ${DIR}
rm -rf ${TMP_DIR}