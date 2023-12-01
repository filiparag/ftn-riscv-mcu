#!/usr/bin/env python3
# -*- coding: utf-8 -*-

###############################################################################

from waflib.Configure import conf
from waflib import Task
from waflib.TaskGen import feature, after_method, extension

import os
import common_waf

###############################################################################

def prerequisites(ctx):
	common_waf.common_prerequisites(ctx)
	ctx.to_log('Installing AVR toolchain...\n')
	ctx.exec_command2('sudo apt -y install gcc-avr avr-libc')


###############################################################################

def find_avr_tools(cfg):
	pl = cfg.env.AVR_PATH + cfg.environ.get('PATH', '').split(os.pathsep)
	def fp(name):
		return cfg.find_program(
			[name],
			path_list = pl
		)
	cc = fp('avr-gcc')
	cc = cfg.cmd_to_list(cc)
	cfg.get_cc_version(cc, gcc = True)
	cfg.env.CC_NAME = 'avr-gcc'
	cfg.env.CC = cc

	cxx = fp('avr-g++')
	cxx = cfg.cmd_to_list(cxx)
	cfg.get_cc_version(cxx, gcc = True)
	cfg.env.CXX_NAME = 'avr-g++'
	cfg.env.CXX = cxx

	cfg.env.AR = fp('avr-ar')
	cfg.env.ARFLAGS = 'rcs'
	cfg.env.OBJCOPY = fp('avr-objcopy')
	cfg.env.OBJDUMP = fp('avr-objdump')
	cfg.env.SIZE = fp('avr-size')
	cfg.env.NM = fp('avr-nm')
	#prog = fp('avr-ld')
	#cfg.env.LD = prog
	#cfg.env.LINK_CC = prog
	#cfg.env.LINK_CXX = prog

def avr_common_flags(cfg):
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

	# Flags.
	mcu_flag = '-mmcu={}'.format(cfg.env.MCU)
	if not cfg.env.OPT:
		cfg.env.OPT = '-Os'
	f = [
		mcu_flag,
		'-DF_CPU={}'.format(cfg.env.FREQ),
		cfg.env.OPT,
		'-g',
		'-Wall',
		#'-MMD',
		#'-ffunction-sections', '-fdata-sections',
		#'-fno-exceptions', '-fno-strict-aliasing'
	]
	cfg.env.CFLAGS += f
	cfg.env.CXXFLAGS += f
	cfg.env.LINKFLAGS += [mcu_flag, cfg.env.OPT, '-lm']
	cfg.env.append_value('CXXFLAGS', '-std=c++11')
	if 'COMMON' in os.environ:
		c = os.environ['COMMON']
		cfg.env.append_value('CPPFLAGS', '-I{}/FW'.format(c))


def configure(cfg):
	cfg.find_avr_tools()
	cfg.avr_common_flags()
	cfg.cc_load_tools()
	cfg.cxx_load_tools()
	cfg.cc_add_flags()
	cfg.cxx_add_flags()
	cfg.link_add_flags()


conf(find_avr_tools)
conf(avr_common_flags)

###############################################################################

class make_eep(Task.Task):
	def run(self):
		#TODO Not working.
		cmd = []
		cmd += self.env.OBJCOPY
		cmd += '-O ihex -j .eeprom'.split()
		cmd += '--set-section-flags=.eeprom=alloc,load'.split()
		cmd += '--no-change-warnings --change-section-lma .eeprom=0 '.split()
		cmd.append(self.inputs[0].relpath())
		cmd.append(self.outputs[0].relpath())
		self.exec_command(cmd)

class make_hex(Task.Task):
	def run(self):
		cmd = []
		cmd += self.env.OBJCOPY
		cmd += '-O ihex'.split()
		cmd.append(self.inputs[0].relpath())
		cmd.append(self.outputs[0].relpath())
		self.exec_command(cmd)

@feature('avr-hex')
@after_method('apply_link')
def avr_objcopy_tskgen(tgen):
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



class avr_size(Task.Task):
	def run(self):
		for src in self.inputs:
			cmd = self.env.SIZE
			cmd.append('--format=avr')
			cmd.append('--mcu={}'.format(self.env.MCU))
			cmd.append(src.relpath())
			ret = self.exec_command2(cmd)
			if ret:
				return ret

	def runnable_status(self):
		ret = super(avr_size, self).runnable_status()
		if ret == Task.SKIP_ME:
			return Task.RUN_ME
		return ret

@feature('avr_size')
def avr_size_feature(tg):
	t = tg.create_task('avr_size', None, None)
	t.always_run = True

@extension('.elf')
def avr_elf_hook(tg, node):
	t = tg.create_task('avr_size', node, None)


###############################################################################
