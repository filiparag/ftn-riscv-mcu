#!/usr/bin/env python
# encoding: utf-8

###############################################################################

import os
import waflib

###############################################################################

location = os.path.abspath(os.path.dirname(__file__))

###############################################################################
# Global help.

def __exec_command2(self, cmd, **kw):
	# Log output while running command.
	kw['stdout'] = None
	kw['stderr'] = None
	ret = self.exec_command(cmd, **kw)
	if ret != 0:
		waflib.Logs.error('Command "{}" returned {}'.format(cmd, ret))
	return ret
setattr(waflib.Context.Context, 'exec_command2', __exec_command2)
setattr(waflib.Task.Task, 'exec_command2', __exec_command2)

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
