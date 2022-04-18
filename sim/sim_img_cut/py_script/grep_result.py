'''
*usage: python grep_result.py [case_num=2] [fn_log="./bin/run.log"]
*example:
python grep_result.py 2
python grep_result.py 10 ./bin/run.log
*function: grep case result from logfile
'''
import os, sys, re
import datetime

g_anchor = '###compare'

def grep_from_log( fn_log ):
    'ret: str=pass/fail/timeout/unknown'
    str_ret = 'unknown'

    fp = open(fn_log,'rt')
    if( fp==0 ):
        print( "NOTICE(), no such file or directory:%s\n", fn_log )
        return str_ret

    for s1 in fp.readlines():
        if( len(re.findall(g_anchor,s1,flags=0)) ):
            if( len(re.findall('pass',s1,flags=0)) ):
                str_ret = 'pass'
            elif( len(re.findall('fail',s1,flags=0)) ):
                str_ret = 'fail'
            elif( len(re.findall('time_out',s1,flags=0)) ):
                str_ret = 'time_out'
            else:
                str_ret = 'unknown'
            break
    fp.close()
    return str_ret

def write_regress_log( fn, case_num, str_result ):
    str_date = datetime.datetime.now().strftime("%Y/%m/%d-%H:%M:%S")
    str_wr = 'case{idx}, {result}, {date}\n'.format( idx='%-3d'%(case_num), result='{:10s}'.format(str_result), date=str_date )

    fp = open(fn,'at')
    fp.write(str_wr)
    fp.close()

if __name__ == '__main__':
    case_num = 1
    fn_log = "./bin/run.log"
    if( len(sys.argv)==1 ):
        print(__doc__)
    elif( len(sys.argv)>1 ):
        case_num = int(sys.argv[1])
    if( len(sys.argv)>2 ):
        fn_log = sys.argv[2]

    str_result = grep_from_log( fn_log )
    print( "the case_num:{} test result is ###{}###".format(case_num, str_result) )
    write_regress_log( "./regress.log", case_num, str_result )