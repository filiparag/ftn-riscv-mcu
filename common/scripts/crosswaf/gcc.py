#!/usr/bin/env python
# -*- coding: utf-8 -*-

###############################################################################

from waflib.Configure import conf
from waflib import Task
from waflib.TaskGen import feature, after_method, extension

import os

###############################################################################

def find_gcc_tools(cfg):
	def fp(name):
		dir = os.path.dirname(cfg.env.CROSS_COMPILE)
		prefix = os.path.basename(cfg.env.CROSS_COMPILE)
		return cfg.find_program(
			[prefix + name],
			path_list = dir
		)
	cc = fp('gcc')
	cc = cfg.cmd_to_list(cc)
	cfg.get_cc_version(cc, gcc = True)
	cfg.env.CC_NAME = 'gcc'
	cfg.env.CC = cc
	
	cxx = fp('g++')
	cxx = cfg.cmd_to_list(cxx)
	cfg.get_cc_version(cxx, gcc = True)
	cfg.env.CXX_NAME = 'g++'
	cfg.env.CXX = cxx
	
	cfg.env.AR = fp('ar')
	cfg.env.ARFLAGS = 'rcs'
	cfg.env.OBJDUMP = fp('objdump')
	cfg.env.OBJCOPY = fp('objcopy')
	cfg.env.SIZE = fp('size')
	cfg.env.NM = fp('nm')
	prog = fp('ld')
	cfg.env.LD = prog
	cfg.env.LINK_CC = prog
	cfg.env.LINK_CXX = prog

def gcc_common_flags(cfg):
	v = cfg.env
	v['CC_SRC_F'] = []
	v['CC_TGT_F'] = ['-c','-o']
	v['CXX_SRC_F'] = []
	v['CXX_TGT_F'] = ['-c','-o']
	if not v['LINK_CC']:
			v['LINK_CC'] = v['CC']
	if not v['LINK_CXX']:
		v['LINK_CXX'] = v['CXX']
	v['CCLNK_SRC_F'] = []
	v['CCLNK_TGT_F'] = ['-o']
	v['CXXLNK_SRC_F'] = []
	v['CXXLNK_TGT_F'] = ['-o']
	v['CPPPATH_ST'] = '-I%s'
	v['DEFINES_ST'] = '-D%s'
	v['LIB_ST'] = '-l%s'
	v['LIBPATH_ST'] = '-L%s'
	v['STLIB_ST'] = '-l%s'
	v['STLIBPATH_ST'] = '-L%s'
	v['RPATH_ST'] = '-Wl,-rpath,%s'
	v['SONAME_ST'] = '-Wl,-h,%s'
	v['SHLIB_MARKER'] = '-Wl,-Bdynamic'
	v['STLIB_MARKER'] = '-Wl,-Bstatic' # '-Wl,--gc-sections'
	v['cprogram_PATTERN'] = '%s'
	v['cxxprogram_PATTERN'] = '%s'
	v['CFLAGS_cshlib'] = ['-fPIC']
	v['CXXFLAGS_cxxshlib'] = ['-fPIC']
	v['LINKFLAGS_cshlib'] = ['-shared']
	v['LINKFLAGS_cxxshlib'] = ['-shared']
	v['cshlib_PATTERN'] = 'lib%s.so'
	v['cxxshlib_PATTERN'] = 'lib%s.so'
	v['LINKFLAGS_cstlib'] = ['-Wl,-Bstatic']
	v['LINKFLAGS_cxxstlib'] = ['-Wl,-Bstatic']
	v['cstlib_PATTERN'] = 'lib%s.a'
	v['cxxstlib_PATTERN'] = 'lib%s.a'


	
def configure(cfg):
	cfg.find_gcc_tools()
	cfg.gcc_common_flags()
	cfg.cc_load_tools()
	cfg.cxx_load_tools()
	cfg.cc_add_flags()
	cfg.cxx_add_flags()
	cfg.link_add_flags()


conf(find_gcc_tools)
conf(gcc_common_flags)

###############################################################################
