#!/usr/bin/env python3
# -*- coding: utf-8 -*-

###############################################################################

import os
import sys
import re
import common_waf
from common_waf import show

###############################################################################

def prerequisites(ctx):
	user = common_waf.common_prerequisites(ctx)
	ctx.to_log('Adding user "{}" to group "dialout"...\n'.format(user))
	ctx.exec_command2('sudo usermod -a -G dialout ' + user)
	ctx.to_log('Installing Arduino...\n')
	d = os.path.dirname(os.path.realpath(__file__))
	s = os.path.join(d, 'install_arduino.sh')
	ctx.exec_command2(s + ' basic')
	
	#TODO arduino-cli on ARDUINO_LIBS

###############################################################################


def parse_arduino_cfg(fn):
	fn = str(fn)
	cfg = {}
	with open(fn) as f:
		for line in f.readlines():
			line2 = line.rstrip() # Remove new line.

			# Skip comment
			if line2.startswith('#'):
				continue
			# Empty line.
			if line2 == '':
				continue

			m = re.match('([\w\.]+)=(.*)', line2)
			key_path = m.group(1)
			raw_value = m.group(2).lstrip().rstrip()

			if raw_value == '':
				value = None
			elif raw_value in ['true', 'false']:
				value = bool(raw_value)
			else:
				try:
					value = int(raw_value)
				except ValueError:
					value = raw_value
			cfg[key_path] = value
	return cfg

def parse_arduino_board_cfg(fn):
	boards_cfg = {}
	cfg = parse_arduino_cfg(fn)
	for key, value in cfg.items():
		m = re.match('(.+)\.name', key)
		if m:
			board_key = m.group(1)
			board_cfg = {}
			board_name = None
			for key2, value2 in cfg.items():
				if key2.startswith(board_key):
					key_rest = key2[len(board_key)+1:]
					board_cfg[key_rest] = value2
					if key_rest == 'name':
						board_name = value2
			boards_cfg[board_name] = board_cfg
	return boards_cfg


def _search_for_libs(ctx):
	std_libs = []
	zip_libs = []
	if ctx.env.ARDUINO_LIBS:
		std_libs_d = ctx.root.find_node(
			ctx.env.ARDUINO_HW
		).find_node(
			'../libraries'
		)
		arch_std_libs_d = ctx.root.find_node(
			ctx.env.ARDUINO_CORE
		).find_node(
			'../../libraries'
		)
		ard_settings_d = ctx.root.find_node(
			os.path.join(os.environ['HOME'], '.arduino15')
		)
		zip_libs_d = ard_settings_d.find_node('staging/libraries/')
		for lib in ctx.env.ARDUINO_LIBS:
			l = std_libs_d.find_node(lib)
			if l:
				std_libs.append(l)
				continue
			
			l = arch_std_libs_d.find_node(lib)
			if l:
				std_libs.append(l)
				continue
			
			if zip_libs_d:
				ls = zip_libs_d.ant_glob(lib + '*.zip')
				if len(ls) > 0:
					l = ls[-1]
					zip_libs.append(l)
					continue
			ctx.fatal('No installed lib "{}"!'.format(lib))
	return std_libs, zip_libs
	

def configure(cfg):
	cfg.start_msg('Checking for Arduino installation')
	ard_settings_d = cfg.root.find_node(
		os.path.join(os.environ['HOME'], '.arduino15')
	)
	if not ard_settings_d:
		cfg.fatal('Arduino not installed or never started!')
	preferences_fn = ard_settings_d.find_node('preferences.txt')
	preferences = parse_arduino_cfg(preferences_fn)
	for key, value in preferences.items():
		if re.match('last\.ide\.\d+\.\d+\.\d+\.hardwarepath', key):
			cfg.env.ARDUINO_HW = value
	if cfg.env.ARDUINO_HW:
		cfg.end_msg(cfg.env.ARDUINO_HW, 'GREEN')
	else:
		cfg.fatal('Cannot find Arduino installation!')

	platform_txts = []
	hw = cfg.root.find_node(cfg.env.ARDUINO_HW)
	if hw:
		platform_txts += hw.ant_glob('**/platform.txt')
	pkg_dir = ard_settings_d.find_node('packages')
	if pkg_dir:
		platform_txts += pkg_dir.ant_glob('**/platform.txt')
	platforms = []
	for platform_txt in platform_txts:
		dir = platform_txt.find_node('..')
		platform_cfg = parse_arduino_cfg(platform_txt)
		boards_cfg = parse_arduino_board_cfg(
			dir.find_node('boards.txt')
		)
		platforms.append({
			'name' : platform_cfg['name'],
			'dir' : dir,
			'boards' : boards_cfg
		})

	cfg.start_msg(
		"Checking for Arduino board '{}'".format(cfg.env.ARDUINO_BOARD)
	)
	board_cfg = None
	for platform in platforms:
		if cfg.env.ARDUINO_BOARD in platform['boards']:
			board_cfg = platform['boards'][cfg.env.ARDUINO_BOARD]
			platform_dir = platform['dir']
	if board_cfg:
		cfg.end_msg('Found', 'GREEN')
	else:
		s = 'Cannot find board!\n'
		s += 'Possible boards:\n'
		for platform in platforms:
			s += "\t'{}'\n".format(platform['name'])
			for name in platform['boards'].keys():
				s += "\t\t'{}'\n".format(name)
		cfg.fatal(s)

	cfg.start_msg('Checking for Arduino core')
	c = platform_dir.find_node('cores/' + board_cfg['build.core'])
	if c:
		cfg.env.ARDUINO_CORE = str(c)
		cfg.end_msg(cfg.env.ARDUINO_CORE, 'GREEN')
	else:
		cfg.fatal('not found')

	cfg.start_msg('Checking for Arduino variant')
	v = platform_dir.find_node('variants/' + board_cfg['build.variant'])
	if v:
		cfg.env.ARDUINO_VARIANT = str(v)
		cfg.end_msg(cfg.env.ARDUINO_VARIANT, 'GREEN')
	else:
		cfg.fatal('not found')

	def check_opt_get_cfg(name, opt, key):
		cfg.start_msg('Checking for {}'.format(name))
		if opt in vars(cfg.options) and vars(cfg.options)[opt]:
			env = vars(cfg.options)[opt]
		else:
			env = board_cfg[key]
		if env:
			cfg.end_msg(env, 'GREEN')
		else:
			cfg.fatal('not found')
		return env

	cfg.env.MCU = check_opt_get_cfg(
		'Arduino MCU',
		'mcu',
		'build.mcu'
	)
	cfg.env.FREQ = check_opt_get_cfg(
		'Arduino frequency',
		'freq',
		'build.f_cpu'
	)

	assert(board_cfg['upload.tool'] == 'avrdude')
	cfg.env.PROGRAMMER = check_opt_get_cfg(
		'Arduino programmer',
		'programmer',
		'upload.protocol'
	)

	cfg.env.PROGRAMMER_SPEED = check_opt_get_cfg(
		'Arduino programmer speed',
		'programmer_speed',
		'upload.speed'
	)

	# For avr and avrdude configs.
	path = hw.find_node('tools/avr')
	cfg.env.AVR_PATH = [str(path.find_node('bin'))]
	cfg.env.append_value(
		'AVRDUDEFLAGS',
		[
			'-C', str(path.find_node('etc/avrdude.conf'))
		]
	)
	# runtime.ide.version
	m = re.match('.*/arduino-(\d+).(\d+).(\d+)/hardware', cfg.env.ARDUINO_HW)
	runtime_ide_version = '{}{:02}{:02}'.format(
		int(m[1]),
		int(m[2]),
		int(m[3])
	)
	# build.arch
	build_arch = os.path.basename(str(platform_dir)).upper()
	f = [
		'-DARDUINO={}'.format(runtime_ide_version),
		'-DARDUINO_{}'.format(board_cfg['build.board']),
		'-DARDUINO_ARCH_{}'.format(build_arch),
	]
	cfg.env.CXXFLAGS += f
	
	std_libs, zip_libs = _search_for_libs(cfg)
	if len(zip_libs) > 0:
		cfg.start_msg('Unpacking zip libs')
		fail = False
		for zip_fn in zip_libs:
			r = cfg.exec_command2(
				'unzip -o -qq {} -d {}'.format(zip_fn, cfg.bldnode)
			)
			if r:
				cfg.fatal('Fail unpacking "{}"!'.format(zip_fn))
		cfg.end_msg('Done', 'GREEN')
	

def build(bld):
	ard_src_dir = bld.root.find_node(bld.env.ARDUINO_CORE)
	ard_src = ard_src_dir.ant_glob('*.c') + ard_src_dir.ant_glob('*.cpp')
	ard_inc = [
		bld.env.ARDUINO_CORE,
		bld.env.ARDUINO_VARIANT
	]
	std_libs, zip_libs = _search_for_libs(bld)
	for lib_d in std_libs:
		d = lib_d.find_node('src')
		ard_src += d.ant_glob('*.cpp')
		ard_inc.append(str(d))
	for zip_fn in zip_libs:
		b = os.path.basename(str(zip_fn))
		n, ext = os.path.splitext(b)
		d = bld.bldnode.find_node(n)
		ard_src += d.ant_glob('*.cpp')
		ard_inc.append(str(d))
	bld.stlib(
		target = 'Arduino_Core',
		source = ard_src,
		includes = ard_inc,
		export_includes = ard_inc
	)


###############################################################################
