#!/usr/bin/env python3
# -*- coding: utf-8 -*-

###############################################################################

import os
import sys
import re
import inspect
import getpass
import glob
import fnmatch
import shutil
import datetime
import waflib

###############################################################################

location = os.path.abspath(os.path.dirname(__file__))

###############################################################################

def __exec_command2(self, cmd, **kw):
	'''
	Log output while running command.
	'''
	kw['stdout'] = None
	kw['stderr'] = None
	if hasattr(self, 'env'):
		if isinstance(cmd, str):
			cmd2 = waflib.Utils.subst_vars(cmd, self.env)
		else:
			cmd2 = [waflib.Utils.subst_vars(c, self.env) for c in cmd]
	else:
		cmd2 = cmd
	ret = self.exec_command(cmd2, **kw)
	if ret != 0:
		waflib.Logs.error('Command "{}" returned {}'.format(cmd2, ret))
	return ret
setattr(waflib.Context.Context, 'exec_command2', __exec_command2)
setattr(waflib.Task.Task, 'exec_command2', __exec_command2)

###############################################################################
# Debug utils.

# Whole expression.
_showRegex = re.compile(r'\bshow\s*\(\s*(.*)\s*\)')

def show(var):
	varName = ''
	for line in inspect.getframeinfo(inspect.currentframe().f_back)[3]:
		m = _showRegex.search(line)
		if m:
			varName = m.group(1)
			break
	print('{0} = {1}'.format(varName, var))

###############################################################################
# Helper decorators.

def attach_bld_ctx(cmd, fun):
	type(
		cmd + '_BuildContext',
		(waflib.Build.BuildContext,),
		{
			'cmd' : cmd,
			'fun' : fun,
		}
	)
def build_context(cmd):
	n = cmd.__name__
	attach_bld_ctx(n, n)
	return cmd
	
def after_cmd(fun):
	def decorator_after_cmd(cmd):
		def wrapper(*args, **kwargs):
			fun(*args, **kwargs)
			return cmd(*args, **kwargs)
		return wrapper
	return decorator_after_cmd

###############################################################################
# Helper functions.

def common_prerequisites(ctx):
	'''
		@return user
	'''

	if sys.platform.startswith('linux'):
		user = getpass.getuser()
		if user == 'root':
			ctx.fatal('Do not run "./waf prerequisites" with sudo!')
		return user
	else:
		ctx.fatal('Not implemented for platform {}!'.format(sys.platform))


def glob_apps_srcs(
	bld,
	filter_regex = '^\d+_*' # Start with number.
):
	'''
	Collect C/C++ files (by default, starting with a number).
	'''
	apps_srcs = []
	for r in ['*.c', '*.cpp']:
		fs = bld.srcnode.ant_glob(r)
		for f2 in fs:
			f3 = str(f2.relpath())
			if re.match(filter_regex, os.path.basename(f3)):
				apps_srcs.append(f3)
	return apps_srcs

def expand_port(port):
	try:
		# Is it number?
		port_idx = int(port)
	except:
		# It is string.
		return port
	
	if sys.platform == 'win32':
		prefix = 'COM'
	else:
		#TODO glob
		prefix = '/dev/ttyUSB'
	fn = '{}{}'.format(prefix, port_idx)
	return fn


def expand_app(app):
	sufixes = ['', '.exe', '.elf']
	prefixes = ['', 'app_', 'example_', 'test_']
	#TODO Start with number.
	
	programs = []
	for g in glob.glob('build/*'):
		if os.path.isfile(g):
			b= os.path.split(g)[1]
			root, ext = os.path.splitext(b)
			if ext in sufixes:
				programs.append(b)
	
	possible_a = []
	for p in programs:
		for prefix in prefixes:
			if p.startswith(prefix + app):
				#a = p
				a, _ = os.path.splitext(p) # Split elf for AVR
				possible_a.append(a)
	
	if len(possible_a) == 0 or app in possible_a:
		a = app
	else:
		a = possible_a[0]
		
	return a
	ble_a.sort()
	
	if len(possible_a) == 0 or app in possible_a:
		a = app
	else:
		a = possible_a[0]
		
	return a

###############################################################################
# Backup stuff.

def recursive_glob(pattern, directory = '.'):
	for root, dirs, files in os.walk(directory, followlinks = True):
		files_dirs = files + [d + '/' for d in dirs]
		if pattern.startswith('/'):
			if root != directory:
				continue
			else:
				files_dirs = ['./' + fd for fd in files_dirs]
		
		rel_root = os.path.relpath(root, directory)
		for fd in files_dirs:
			for j in [fd, os.path.join(rel_root, fd)]:
				if fnmatch.fnmatch(j, pattern):
					yield os.path.join(root, fd)
					break

def collect_git_ignored_files():
	#TODO Make tree and mark what is for delete, then mark what is not.
	for gitignore in recursive_glob('.gitignore'):
		with open(gitignore) as f:
			base = os.path.dirname(gitignore)
			
			ignore_patterns = []
			not_ignore_patterns = [] # Those starting with !
			for pattern in f.readlines():
				pattern = pattern.rstrip() # Remove new line stuff on line end.
				if pattern.startswith('!'):
					not_ignore_patterns.append(pattern[1:])
				else:
					ignore_patterns.append(pattern)
			
			not_ignore = set([])
			for pattern in not_ignore_patterns:
				for f in recursive_glob(pattern, base):
					not_ignore.add(f)
			for pattern in ignore_patterns:
				for f in recursive_glob(pattern, base):
					if f not in not_ignore:
						yield f


def distclean(ctx):
	for fn in collect_git_ignored_files():
		if os.path.isdir(fn):
			shutil.rmtree(fn)
		else:
			os.remove(fn)

def dist(ctx):
	APPNAME = os.path.basename(os.getcwd())
	now = datetime.datetime.now()
	time_stamp = '{:d}-{:02d}-{:02d}-{:02d}-{:02d}-{:02d}'.format(
		now.year,
		now.month,
		now.day,
		now.hour,
		now.minute,
		now.second
	)
	ctx.arch_name = '../{}-{}.zip'.format(APPNAME, time_stamp)
	ctx.algo = 'zip'
	ctx.base_name = APPNAME
	# Also pack git.
	waflib.Node.exclude_regs = waflib.Node.exclude_regs.replace(
'''
**/.git
**/.git/**
**/.gitignore''', '')
	# Ignore waf's stuff.
	waflib.Node.exclude_regs += '\n**/.waf*'

###############################################################################
