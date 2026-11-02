# FactoryX: owner-drawn caption repaint regression tests for Delphi XE7.
from pathlib import Path
import argparse,subprocess

parser=argparse.ArgumentParser()
parser.add_argument('--heos-controls',required=True,type=Path)
parser.add_argument('--delphi-root',type=Path,default=Path(r'C:\Program Files (x86)\Embarcadero\Studio\15.0'))
parser.add_argument('--output-root',type=Path)
args=parser.parse_args()
controls=Path(__file__).resolve().parent.parent
output=args.output_root or controls.parent/'Build/ButtonCaptionTests'
for platform in ['win32','win64']:
    out=output/platform;out.mkdir(parents=True,exist_ok=True)
    paths=[args.heos_controls,controls,args.delphi_root/'lib'/platform/'release']
    command=[str(args.delphi_root/'bin'/('dcc32.exe' if platform=='win32' else 'dcc64.exe')),
             '-B','-Q','-NSSystem;Winapi;Vcl;System.Win',
             '-U'+';'.join(map(str,paths)),'-N0'+str(out),'-E'+str(out),
             str(controls/'Tests/ButtonCaptionTests.dpr')]
    built=subprocess.run(command,cwd=controls/'Tests',capture_output=True,text=True)
    print(platform,built.stdout,built.stderr,flush=True)
    assert built.returncode==0
    run=subprocess.run([str(out/'ButtonCaptionTests.exe'),str(out)+'\\'],
                       capture_output=True,text=True,timeout=20)
    print(platform,run.stdout,run.stderr,flush=True)
    assert run.returncode==0
