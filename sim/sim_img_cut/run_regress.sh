CASE_NUM_BEGIN=$1
CASE_NUM_END=$2

python ./py_script/run_regress.py $CASE_NUM_BEGIN $CASE_NUM_END

# STR_LOGFILE="./regress.log"

# if [ -z "$CASE_NUM_BEGIN" ]
# then
#     let CASE_NUM_BEGIN=1
#     echo "no CASE_NUM_BEGIN input, CASE_NUM_BEGIN assign=${CASE_NUM_BEGIN}"
# fi
# if [ -z "$CASE_NUM_END" ]
# then
#     let CASE_NUM_END=${CASE_NUM_BEGIN}+1
#     echo "no CASE_NUM_END   input, CASE_NUM_END   assign=${CASE_NUM_END}"
# fi


# # rm ${STR_LOGFILE}
# echo "start  regress from ${CASE_NUM_BEGIN} to ${CASE_NUM_END}-----------------------" >>${STR_LOGFILE}
# date +date=%Y/%m/%d-%H:%M:%S>>${STR_LOGFILE}
# case_num=${CASE_NUM_BEGIN}
# echo ${case_num}

# make com
# while [ ${case_num} != ${CASE_NUM_END} ]
# do
#   ./run_one.sh ${case_num}
#   let case_num=$case_num+1
# done
# echo "finish regress from ${CASE_NUM_BEGIN} to ${CASE_NUM_END}-----------------------" >>${STR_LOGFILE}