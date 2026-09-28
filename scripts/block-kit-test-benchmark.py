#!/usr/bin/env python3
"""Manual sequential Block Kit measurement; run from the repository root.

Leaves logs and run-owned caches in the printed temporary directory for inspection.
The C shim observes successful runs; it is not a signal-forwarding process supervisor.
"""
import os, pathlib, subprocess, tempfile, time, json, shutil, platform, hashlib
root=pathlib.Path.cwd()
p=pathlib.Path(tempfile.mkdtemp(prefix='block-kit-final-benchmark-')).resolve()
real=shutil.which('crystal')
(p/'bin').mkdir()
(p/'trace.c').write_text(r'''
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <time.h>
#include <errno.h>
int main(int argc, char **argv) {
  struct timespec a,b; clock_gettime(CLOCK_MONOTONIC,&a);
  pid_t pid=fork(); if(pid<0) return 125;
  if(pid==0) { argv[0]=getenv("BLOCK_KIT_REAL_CRYSTAL");
    execv(argv[0],argv); _exit(127); }
  int s; while(waitpid(pid,&s,0)<0) { if(errno!=EINTR) return 125; }
  clock_gettime(CLOCK_MONOTONIC,&b);
  int code=WIFEXITED(s)?WEXITSTATUS(s):128+WTERMSIG(s);
  FILE *f=fopen(getenv("BLOCK_KIT_CHILD_LOG"),"a");
  if(f) { fprintf(f,"%.9f\t%d",b.tv_sec-a.tv_sec+(b.tv_nsec-a.tv_nsec)/1e9,code);
    for(int i=1;i<argc;i++) fprintf(f,"\t%s",argv[i]);
    fprintf(f,"\n"); fclose(f); }
  return code;
}
''')
subprocess.run(['cc','-O2',str(p/'trace.c'),'-o',str(p/'bin/crystal')],check=True)
env={k:v for k,v in os.environ.items() if not k.startswith('SLACK_') and k not in ('OAUTH_REDIRECT_URL','SIGN_IN_REDIRECT_URL')}
env.update(CRYSTAL_CACHE_DIR=str(p/'cache'),PATH=str(p/'bin')+os.pathsep+env['PATH'],BLOCK_KIT_REAL_CRYSTAL=real)
metadata={'commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'source_diff_sha256':hashlib.sha256(subprocess.check_output(['git','diff','HEAD','--','*.cr'])).hexdigest(),'crystal':subprocess.check_output([real,'--version'],text=True).strip(),'platform':platform.platform(),'shard_lock_sha256':hashlib.sha256((root/'shard.lock').read_bytes()).hexdigest(),'cache':'empty initially, retained between runs; native wrapper owns a fresh child cache','tracing':'same compiled shim for both full runs; outer compiler invoked directly','directory':str(p),'runs':[]}
print('Evidence directory:',p,flush=True)
for state in ('cold','repeat'):
    env['BLOCK_KIT_CHILD_LOG']=str(p/(state+'-children.tsv'))
    cmd=[real,'spec','--stats','--no-color','--profile','--junit_output',str(p/(state+'.xml'))]
    start=time.perf_counter()
    with (p/(state+'.log')).open('w') as out:
        result=subprocess.run(cmd,cwd=root,env=env,stdout=out,stderr=subprocess.STDOUT)
    row={'state':state,'wall_seconds':time.perf_counter()-start,'status':result.returncode,'command':cmd}
    metadata['runs'].append(row)
    (p/'metadata.json').write_text(json.dumps(metadata,indent=2)+'\n')
    print(json.dumps(row),flush=True)
    if result.returncode:raise SystemExit(result.returncode)
