CASE_NUM=$1

echo ${CASE_NUM}

#1.env setup
source ./ENV.sh
#2.gen case.cfg
python ./py_script/gen_cfg_from_excel.py ${CASE_NUM}
#3.run sim
make run
#4.deal result
python ./py_script/grep_result.py ${CASE_NUM}