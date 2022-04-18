'''
*usage: python run_regress.py <case_num_begin=1> [case_num_end]
*example:
python run_regress.py 2
python run_regress.py 1 10
*function: run_regress
'''
import os, sys, re
import datetime

g_fn_log = './regress.log'

def run_regress( case_begin, case_end ):
    str_wr = ''
    fn = g_fn_log
    fp = open(fn,'at')

    str_wr = 'start  regress from {} to {}-----------------------\n'.format( case_begin, case_end )
    str_date = datetime.datetime.now().strftime("%Y/%m/%d-%H:%M:%S\n")
    str_wr+= str_date
    fp.write(str_wr)
    fp.flush()

    str_cmd = 'rm ./bin/*.log'
    os.system( str_cmd )
    str_cmd = 'source ./ENV.sh; make com'
    os.system( str_cmd )
    for case_idx in range(case_begin,case_end):
        str_cmd = './run_one.sh {}'.format( case_idx )
        os.system( str_cmd )
        print( '{} run finished'.format( str_cmd ) )
    str_wr = 'finish regress from {} to {}-----------------------\n'.format( case_begin, case_end )
    fp.write(str_wr)

    fp.close()

if __name__ == '__main__':
    case_begin = 1
    case_end = case_begin+1
    if( len(sys.argv)==1 ):
        print(__doc__)
    elif( len(sys.argv)>1 ):
        case_begin = int(sys.argv[1])
        case_end = case_begin+1
    if( len(sys.argv)>2 ):
        case_end = int(sys.argv[2])

    run_regress( case_begin,case_end )
    # print( 'the regress from {} to {} is finished'.format( case_begin,case_end )

