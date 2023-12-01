#!/usr/bin/env python
# -*- coding: utf-8 -*-

###############################################################################

from waflib.Configure import conf
from waflib import Task
from waflib.TaskGen import feature, after_method, extension

import os

###############################################################################

asm_over_gcc = True

def find_bare_metal_gcc_tools(cfg):
	def fp(name):
		pl = os.path.dirname(cfg.env.CROSS_COMPILE)
		prefix = os.path.basename(cfg.env.CROSS_COMPILE)
		return cfg.find_program(
			[prefix + name],
			path_list = pl
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
	
	if asm_over_gcc:
		cfg.env.ASM_NAME = 'gcc'
		cfg.env.AS = cc
		cfg.env.ASFLAGS = ['-c']
		cfg.env.AS_TGT_F = '-o'
	else:
		#TODO Problem with hard and soft float
		cfg.env.ASM_NAME = 'as'
		cfg.env.AS = fp('as')
		cfg.env.ASFLAGS = []
		cfg.env.AS_TGT_F = '-o'

	cfg.env.AR = fp('ar')
	cfg.env.ARFLAGS = 'rcs'
	cfg.env.OBJCOPY = fp('objcopy')
	cfg.env.OBJDUMP = fp('objdump')
	cfg.env.SIZE = fp('size')
	cfg.env.NM = fp('nm')
	#prog = fp('ld')
	#cfg.env.LD = prog
	#cfg.env.LINK_CC = prog
	#cfg.env.LINK_CXX = prog

def bare_metal_gcc_common_flags(cfg):
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
	v['LINKFLAGS_cxxstlib'] = ['-Wl,-Bstatic1']
	v['cstlib_PATTERN'] = 'lib%s.a'
	v['cxxstlib_PATTERN'] = 'lib%s.a'

	# Flags.
	f = [
		'-ffreestanding',
	]
	cfg.env.CFLAGS += f
	cfg.env.CXXFLAGS += f
	if asm_over_gcc:
		cfg.env.ASFLAGS += f
	cfg.env.LINKFLAGS += ['-nostdlib']

	
def configure(cfg):
	cfg.find_bare_metal_gcc_tools()
	cfg.bare_metal_gcc_common_flags()
	cfg.cc_load_tools()
	cfg.cxx_load_tools()
	cfg.cc_add_flags()
	cfg.cxx_add_flags()
	cfg.link_add_flags()
	cfg.load('asm')


conf(find_bare_metal_gcc_tools)
conf(bare_metal_gcc_common_flags)

###############################################################################

class make_hex(Task.Task):
	def run(self):
		cmd = []
		#TODO use script
		cmd += self.env.OBJCOPY
		cmd += '-O ihex'.split()
		cmd.append(self.inputs[0].relpath())
		cmd.append(self.outputs[0].relpath())
		self.exec_command(cmd)

@feature('hex')
@after_method('apply_link')
def bare_metal_gcc_objcopy_tskgen(tgen):
	if not hasattr(tgen, 'link_task') or not tgen.link_task:
		return []
		#tgen.env.fatal("There must be a link task to process")

	if not tgen.link_task.outputs[0].name.endswith('.elf'):
		return []
		#tgen.env.fatal("Link task must end with .elf")

	#out_eep = tgen.link_task.outputs[0].change_ext('.eep')
	#tsk_eep = tgen.create_task('make_eep', tgen.link_task.outputs[0], out_eep)

	out_hex = tgen.link_task.outputs[0].change_ext('.hex')
	tsk_hex = tgen.create_task('make_hex', tgen.link_task.outputs[0], out_hex)
	#return [tsk_eep, tsk_hex]
	return [tsk_hex]



class bare_metal_gcc_size(Task.Task):
	def run(self):
		for src in self.inputs:
			cmd = self.env.SIZE
			#TODO cmd.append('--format=avr')
			cmd.append(src.relpath())
			ret = self.exec_command2(cmd)
			if ret:
				return ret

	def runnable_status(self):
		ret = super(bare_metal_gcc_size, self).runnable_status()
		if ret == Task.SKIP_ME:
			return Task.RUN_ME
		return ret
	
@feature('bare_metal_gcc_size')
def bare_metal_gcc_size_feature(tg):
	t = tg.create_task('bare_metal_gcc_size', None, None)
	t.always_run = True

@extension('.elf')
def bare_metal_gcc_elf_hook(tg, node):
	t = tg.create_task('bare_metal_gcc_size', node, None)
	

###############################################################################
