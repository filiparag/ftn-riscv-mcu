#!/usr/bin/env python3
# encoding: utf-8

'''
@author: Milos Subotic <milos.subotic.sm@gmail.com>
@license: MIT

@brief: Waf script just for distclean and dist commands.
'''

###############################################################################

import os
import sys

sys.path.append('./common/scripts')
import common_waf
from common_waf import *

import shutil

###############################################################################

def prerequisites(ctx):
	ctx.load('arduino', tooldir = avrwaf.location)

def options(opt):
	opt.load('c cxx')
	# Common options.
	opt.add_option(
		'--without-tools',
		dest = 'without_tools',
		action = 'store_true',
		help = 'Do not install tools (1GiB)'
	)


def install_ard_pkg(ctx):
	def copy_and_overwrite(from_path, to_path):
		if os.path.exists(to_path):
			shutil.rmtree(to_path)
		shutil.copytree(from_path, to_path)

	# Set the custom folder path
	ctx.start_msg('Checking for Arduino installation')
	ard_settings_d = ctx.root.find_node(
		os.path.join(os.environ['HOME'], '.arduino15')
	)
	if ard_settings_d:
		#FIXME Hard time with printing.
		ctx.end_msg(ard_settings_d, 'GREEN')
	else:
		ctx.fatal('Arduino not installed or never started!')

	max_d = ard_settings_d.make_node('packages/max1000/')
	os.makedirs(str(max_d), exist_ok = True)

	hw_d = max_d.make_node('hardware/')
	copy_and_overwrite('SW/Arduino_Package/', str(hw_d))

	if not ctx.options.without_tools:
		ctx.to_log('Installing gdown...\n')
		ctx.exec_command2('pip install gdown')
		ctx.to_log('Downloading zip with tools...\n')
		ctx.exec_command2('gdown --fuzzy https://drive.google.com/file/d/1WdH8eOvtVn7LvdUCFHBV0l1jWRTO0HaZ/view?usp=drive_link')
		ctx.to_log('Unpacking and installing tools...\n')
		ctx.exec_command2(f'unzip riscv_im_gcc_ard_tools.zip -d {max_d}')



###############################################################################

APPNAME = os.path.basename(os.getcwd())

def distclean(ctx):
	common_waf.distclean(ctx)

def dist(ctx):
	common_waf.dist(ctx)

###############################################################################
