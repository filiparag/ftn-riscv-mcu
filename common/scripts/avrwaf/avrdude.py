#!/usr/bin/env python3
# -*- coding: utf-8 -*-

###############################################################################

from waflib.TaskGen import extension, feature
from waflib.Task import Task

import waflib #TODO

import os
import sys
import common_waf
from common_waf import show

###############################################################################

def prerequisites(ctx):
	user = common_waf.common_prerequisites(ctx)
	ctx.to_log('Adding user "{}" to group "dialout"...\n'.format(user))
	ctx.exec_command2('sudo usermod -a -G dialout ' + user)
	ctx.to_log('Installing avrdude...\n')
	ctx.exec_command2('sudo apt -y install avrdude')
	#TODO For AVR Dragon programmer.
	#with open('/etc/udev/rules.d/50-avrdragon.rules', 'w') as f:
	#	f.write('SUBSYSTEM=="usb", ATTR{idVendor}=="03eb", ATTR{idProduct}=="2107", MODE="0660", GROUP="plugdev"')
	#ctx.exec_command('/etc/init.d/udev restart')

###############################################################################

def configure(cfg):
	pl = cfg.env.AVR_PATH + cfg.environ.get('PATH', '').split(os.pathsep)
	cfg.find_program(
		'avrdude',
		path_list = pl,
		var = 'AVRDUDE'
	)
	mcu = cfg.env.MCU
	if mcu == 'attiny13a':
		mcu = 'attiny13'
	cfg.env.append_value(
		'AVRDUDEFLAGS',
		[
			'-p', mcu,
		]
	)

def gen_programmer_cmd(ctx):
	flags = []
	if ctx.env.PROGRAMMER:
		if ctx.env.PROGRAMMER == 'arduino_as_isp':
			p = 'stk500v1'
			ctx.env.PROGRAMMER_SPEED = 19200
			
			#TODO Take ctx.env.FREQ in consideration.
			#freq_kHz = 100
			#FIXME Need long time and MCU stay in reset.
			#if ctx.env.PROGRAMMER == 'dragon_jtag':
			#	# With this it exists without error.
			#	flags += ['-B', '{}kHz'.format(freq_kHz)]
		else:
			p = ctx.env.PROGRAMMER
		flags += ['-c', p]
		
	if ctx.env.PROGRAMMER_SPEED:
		flags += ['-b', str(ctx.env.PROGRAMMER_SPEED)]

	if not ctx.env.PROGRAMMER_PORT:
		if ctx.env.PROGRAMMER == 'arduino':
			if sys.platform.startswith('linux'):
				ctx.env.PROGRAMMER_PORT = '/dev/ttyUSB0'
			else:
				ctx.env.PROGRAMMER_PORT = 'COM2'
	if ctx.env.PROGRAMMER_PORT:
		flags += ['-P', ctx.env.PROGRAMMER_PORT]

	#flags += ['-vv']

	cmd = ctx.env.AVRDUDE
	cmd += ctx.env.AVRDUDEFLAGS
	cmd += flags
	
	return cmd
	

class avrdude_read_fuses(Task):
	def run(self):
		cmd = gen_programmer_cmd(self)
		#TODO Pipe it. Parse it. Process nice.
		#cmd.append('-Uhfuse:r:-:b')
		#cmd.append('-Ulfuse:r:-:b')
		ret = self.exec_command2(cmd)
		if ret:
			return ret

@feature('avrdude_read_fuses')
def avrdude_read_fuses__feature(tg):
	t = tg.create_task('avrdude_read_fuses', None, None)
	t.always_run = True


class avrdude_write_fuses(Task):
	before = 'avrdude_upload'
	always_run = True
	color = 'BLUE'
	def run(self):
		if not(
			self.env.LOCK or
			self.env.LFUSE or
			self.env.HFUSE or
			self.env.EFUSE
		):
			print('No fuse to write!')
			return 0
			
		cmd = gen_programmer_cmd(self)
		if self.erase_chip:
			cmd.append('-e')
		if self.env.LOCK:
			cmd.append('-Ulock:w:0x{:x}:m'.format(self.env.LOCK))
		if self.env.LFUSE:
			cmd.append('-Ulfuse:w:0x{:x}:m'.format(self.env.LFUSE))
		if self.env.HFUSE:
			cmd.append('-Uhfuse:w:0x{:x}:m'.format(self.env.HFUSE))
		if self.env.EFUSE:
			cmd.append('-Uefuse:w:0x{:x}:m'.format(self.env.EFUSE))
		ret = self.exec_command2(cmd)
		if ret:
			return ret

@feature('avrdude_write_fuses')
def avrdude_write_fuses__feature(tg):
	t = tg.create_task('avrdude_write_fuses', None, None)
	for a in ['erase_chip']:
		if hasattr(tg, a):
			setattr(t, a, getattr(tg, a))



class avrdude_upload(Task):
	always_run = True
	ignore_error = False
	verify_only = False
	LOCK = None
	def run(self):
		for src in self.inputs:
			cmd = gen_programmer_cmd(self)
			if self.verify_only:
				u = 'v'
			else:
				u = 'w'
			cmd.append('-Uflash:{}:{}:i'.format(u, src))
			if self.LOCK:
				cmd.append('-Ulock:w:0x{:x}:m'.format(self.LOCK))
			r = self.exec_command2(cmd)
			if self.ignore_error:
				return 0
			else:
				return r
@extension('.hex')
def avrdude_hex_hook(tg, node):
	t = tg.create_task('avrdude_upload', node, None)
	for a in ['ignore_error', 'verify_only', 'LOCK']:
		if hasattr(tg, a):
			setattr(t, a, getattr(tg, a))

class pre_avrdude_upload(Task):
	before = 'avrdude_upload'
	always_run = True
	color = 'BLUE'
	def run(self):
		return self.exec_command2(self.cmd)
@feature('pre_avrdude_upload')
def pre_avrdude_upload__feature(self):
	t = self.create_task('pre_avrdude_upload')
	t.cmd = self.cmd

class post_avrdude_upload(Task):
	after = 'avrdude_upload'
	always_run = True
	color = 'BLUE'
	def run(self):
		return self.exec_command2(self.cmd)
@feature('post_avrdude_upload')
def post_avrdude_upload__feature(self):
	t = self.create_task('post_avrdude_upload')
	t.cmd = self.cmd

###############################################################################
