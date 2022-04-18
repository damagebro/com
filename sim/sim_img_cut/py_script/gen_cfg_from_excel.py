'''
*usage: python gen_cfg_from_excel.py [case_num=2] [fn_cfg="./img_cut.cfg"]
*example:
python gen_cfg_from_excel.py 2
python gen_cfg_from_excel.py 10 ./img_cut.cfg
*function: gen config file from excel
'''
import os, sys, re
import openpyxl

def get_dict_cfg():
    'func: return col_idx in excel, {"cfgname" : ui_col_idx}'
    dict_cfg = {}
    dict_cfg["pic_width"   ] = 2
    dict_cfg["pic_heigh"   ] = 3
    dict_cfg["pixel_bitlen"] = 4
    dict_cfg["cut_rd_xpos" ] = 5
    dict_cfg["cut_rd_ypos" ] = 6
    dict_cfg["cut_rd_width"] = 7
    dict_cfg["cut_rd_heigh"] = 8

    return dict_cfg

def gen_cfgfile( case_num=2, fn_cfg="img_cut.cfg" ):
    filename = "./img_cut_testlist.xlsx"
    wb = openpyxl.load_workbook(filename)
    ws = wb["direct_test"]
    dict_cfg = get_dict_cfg()

    str_wr = ''
    str_wr+= '#File I/O\n'
    str_wr+= 'CaseDir : "./tmp/"\n'
    str_wr+= '\n'*1
    str_wr+= '#config\n'
    for key in dict_cfg:
        col_idx = dict_cfg[key]
        val = str( ws.cell(row=case_num+1, column=col_idx).value )
        str_wr += '{:30s}:{:>20s}\n'.format( key, val )

    fp = open(fn_cfg,'wt')
    fp.write(str_wr)
    fp.close()


if __name__ == '__main__':
    fn_cfg = "./img_cut.cfg"
    case_num = 2
    if( len(sys.argv)==1 ):
        print(__doc__)
    elif( len(sys.argv)>1 ):
        case_num = int(sys.argv[1])
    if( len(sys.argv)>2 ):
        fn_cfg = sys.argv[2]

    gen_cfgfile( case_num, fn_cfg )
    print( "the case_num:{} is generated successfully".format(case_num) )