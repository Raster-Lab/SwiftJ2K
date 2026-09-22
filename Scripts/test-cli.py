#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Black-box CLI and staged binary/manual installation regression checks."""
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile
from pathlib import Path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True,help='New evidence directory')
    args=parser.parse_args();binary=args.binary.resolve();out=args.output.resolve()
    if out.exists():parser.error('Use a fresh output directory')
    out.mkdir(parents=True)
    repo=Path(__file__).resolve().parent.parent
    tool=binary.name;version=(repo/'VERSION').read_text().strip();manual=repo/'ManPages'/(tool+'.1')
    if not manual.is_file():parser.error('Binary name must match this repository manual')
    report={'binary':str(binary),'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),
            'installer_sha256':hashlib.sha256((repo/'Scripts/install-cli.sh').read_bytes()).hexdigest(),
            'test_runner_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
            'version':version,'manual_sha256':hashlib.sha256(manual.read_bytes()).hexdigest(),'commands':[],'status':'running'}
    def save(): (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    def run(argv,expected=0,**kwargs):
        r=subprocess.run([str(x) for x in argv],capture_output=True,text=True,timeout=30,**kwargs)
        report['commands'].append({'argv':[str(x) for x in argv],'exit_code':r.returncode,'expected_exit_code':expected,
                                   'stdout':r.stdout,'stderr':r.stderr})
        save();assert r.returncode==expected,(argv,r.returncode,r.stderr);return r
    def cli(*values,expected=0):return run([binary,*values],expected)
    def document(r):
        d=json.loads(r.stdout);assert d['version']==version and d['minimumAppleOS']=='26.0'
        assert d['canEncode'] is True and d['canDecode'] is True and d['canInspect'] is True and d['formats']==['jpeg2000-codestream']
        return d
    try:
        root=cli('--help');assert 'USAGE:' in root.stdout and 'unavailable' in root.stdout and not root.stderr
        for form in [[],['-h'],['help']]:assert cli(*form).stdout==root.stdout
        command=cli('capabilities','--help').stdout
        assert cli('help','capabilities').stdout==command and cli('capabilities','-h').stdout==command
        assert '--json' in command and 'EXIT STATUS' in command
        for form in [['--version'],['version'],['--version','--quiet']]:assert cli(*form).stdout==tool+' '+version+'\n'
        baseline=document(cli('capabilities','--json'))
        for level in range(1,6):
            for form in [['-'+'v'*level],['-v']*level,['--verbose',str(level)],['--verbose='+str(level)],
                         ['-verbose:',str(level)],['-verbose:'+str(level)],['--verbose','+'*level],['--verbose='+'+'*level]]:
                r=cli('capabilities','--json',*form);assert document(r)==baseline
                assert len(r.stderr.splitlines())==level,(form,r.stderr)
                assert all(f'[{i}]' in r.stderr for i in range(1,level+1))
        for form in [['--verbose'],['-verbose']]:assert len(cli(*form,'capabilities','--json').stderr.splitlines())==1
        assert len(cli('capabilities','-v','--verbose','2','-v').stderr.splitlines())==3
        assert len(cli('capabilities','-vv','-vvv').stderr.splitlines())==5
        quiet=cli('capabilities','--json','--quiet');assert not quiet.stderr and document(quiet)==baseline
        assert cli('--help','--quiet').stdout==root.stdout
        for invalid in ['0','6','10','99999999999999999999999999999','abc','++++++','+2','١','']:
            r=cli('capabilities','--verbose='+invalid,expected=2);assert not r.stdout and r.stderr
        for form in [['--verbose=5','-v'],['-vvvvvv'],['-v','--quiet'],['--quiet','--verbose=1'],['--quiet','--verbose=0'],
                     ['--unknown'],['bogus'],['help','bogus'],['capabilities','extra'],['--verbose:'],['--json'],
                     ['--input','some-path'],['capabilities','--output','x'],['capabilities','--version'],['--input']]:
            r=cli(*form,expected=2);assert not r.stdout and r.stderr
        with tempfile.TemporaryDirectory(prefix='cli stage spaces ',dir=out) as temp:
            temp=Path(temp);payload=temp/'private image λ.raw';payload.write_bytes(b'unchanged')
            for verb in ['encode','decode','inspect','validate']:
                assert 'USAGE:' in cli(verb,'--help').stdout and 'UNAVAILABLE' not in cli(verb,'--help').stdout
            assert 'UNAVAILABLE:' in cli('transcode','--help').stdout
            r=cli('transcode','--input','-','--output',str(payload),'-vvvvv',expected=4)
            assert not r.stdout and str(payload) not in r.stderr and payload.read_bytes()==b'unchanged'
            # Codec verbs on the repository fixtures (CLI-02, CLI-03, CLI-04).
            fixtures=repo/'Tests/SwiftJ2KTests/Fixtures/Lossless'
            manifest=json.loads((fixtures/'manifest.json').read_text())
            def pgm_samples(path):
                d=path.read_bytes();parts=[];i=0
                while len(parts)<4:
                    while d[i:i+1].isspace():i+=1
                    if d[i:i+1]==b'#':
                        while d[i:i+1]!=b'\n':i+=1
                        continue
                    j=i
                    while not d[j:j+1].isspace():j+=1
                    parts.append(d[i:j]);i=j
                body=d[i+1:];w,h,mx=int(parts[1]),int(parts[2]),int(parts[3])
                return w,h,(list(body[:w*h]) if mx<=255 else [int.from_bytes(body[k:k+2],'big') for k in range(0,w*h*2,2)])
            def nrrd_samples(data):
                i=data.index(b'\n\n')+2;header=data[:i].decode();body=data[i:]
                fields=dict(l.split(': ',1) for l in header.splitlines() if ': ' in l and not l.startswith('#'))
                keys=dict(l.split(':=',1) for l in header.splitlines() if ':=' in l)
                assert fields['type']=='uint16' and fields['dimension']=='2' and fields['encoding']=='raw' and fields['endian']=='little'
                w,h=map(int,fields['sizes'].split());assert len(body)==w*h*2
                return w,h,int(keys['swiftj2k.meaningfulbits']),[int.from_bytes(body[k:k+2],'little') for k in range(0,len(body),2)]
            for entry in manifest['fixtures']:
                if entry['name'] not in ('g12_129x67_gradient','g16_17x9_alternating','g08_37x23_random'):continue
                w,h,samples=pgm_samples(fixtures/(entry['name']+'.pgm'))
                stream=fixtures/entry['codestreams'][0]['file']
                info=json.loads(cli('inspect','-i',stream,'--json').stdout)
                assert info['width']==w and info['height']==h and info['meaningfulBits']==entry['meaningfulBits'] and info['format']=='jpeg2000-codestream'
                text=cli('inspect','-i',stream).stdout;assert f'width: {w}' in text and f'meaningful bits: {entry["meaningfulBits"]}' in text
                valid=json.loads(cli('validate','-i',stream,'--json').stdout);assert valid['valid'] is True and valid['width']==w
                assert cli('validate','-i',stream).stdout.startswith('valid: ')
                decoded=temp/(entry['name']+' decoded.nrrd')
                r=cli('decode','-i',stream,'-o',decoded,'--json');assert not r.stdout
                dreport=json.loads(r.stderr);assert dreport['command']=='decode' and dreport['copyEvents']==0 and dreport['fidelity']=='exactSamples'
                nw,nh,bits,nsamples=nrrd_samples(decoded.read_bytes());assert (nw,nh,bits)==(w,h,entry['meaningfulBits']) and nsamples==samples
                cli('decode','-i',stream,'-o',decoded,expected=6);assert nrrd_samples(decoded.read_bytes())[3]==samples
                cli('decode','-i',stream,'-o',decoded,'--overwrite','--input-format','j2k','--output-format','nrrd','--copy-policy','allow-copy')
                encoded=temp/(entry['name']+' re-encoded.j2k')
                r=cli('encode','-i',decoded,'-o',encoded,'--json','--levels','2','--code-block','32x32');ereport=json.loads(r.stderr)
                assert not r.stdout and ereport['format']=='jpeg2000-codestream' and ereport['meaningfulBits']==entry['meaningfulBits'] and ereport['outputBytes']==encoded.stat().st_size
                back=json.loads(cli('validate','-i',encoded,'--json').stdout);assert back['width']==w and back['height']==h
                piped=subprocess.run(f'"{binary}" decode -i - -o - < "{stream}" | "{binary}" encode -i - --input-format nrrd -o - | "{binary}" decode -i - -o -',shell=True,capture_output=True,timeout=60)
                report['commands'].append({'argv':['sh','-c','decode | encode | decode'],'exit_code':piped.returncode,'expected_exit_code':0,'stderr':piped.stderr.decode(errors='replace')});save()
                assert piped.returncode==0 and nrrd_samples(piped.stdout)[3]==samples
                assert not [f for f in temp.iterdir() if f.name.endswith('.tmp')]
            # Exit statuses: 2 usage, 3 malformed, 4 unsupported format/feature, 5 limit/deadline, 6 I/O.
            good=fixtures/'g16_64x64_random.opj.j2k';nine=fixtures/'g16_64x64_random.irreversible97.j2k'
            for form in [['encode'],['decode','-i',good],['inspect','-i',good,'-o','x'],['validate','-i',good,'--output','x'],
                         ['decode','-i',good,'-o','x','--input-format','tiff'],['encode','-i',good,'-o','x','--precision','17'],
                         ['encode','-i',good,'-o','x','--code-block','3x3'],['encode','-i',good,'-o','x','--levels','40'],
                         ['validate','-i',good,'--threads','9'],['validate','-i',good,'--timeout','-1'],['validate','-i',good,'-i',good]]:
                r=cli(*form,expected=2);assert not r.stdout and r.stderr
            truncated=temp/'truncated.j2k';truncated.write_bytes(good.read_bytes()[:100])
            for form,code in [(['validate','-i',nine],4),(['validate','-i',truncated],3),(['validate','-i',payload],4),
                              (['encode','-i',good,'-o',temp/'x.j2k'],4),(['decode','-i',good,'-o',temp/'x.nrrd','--input-format','nrrd'],4),
                              (['decode','-i',good,'-o',temp/'x.nrrd','--mode','lossy'],4),(['decode','-i',good,'-o',temp/'x.nrrd','--backend','metal'],4),
                              (['validate','-i',fixtures/'g16_256x256_smooth.opj.j2k','--timeout','0.000001'],5),
                              (['validate','-i',fixtures/'g16_256x256_smooth.opj.j2k','--max-memory','1000'],5),
                              (['validate','-i',temp/'missing.j2k'],6),(['decode','-i',good,'-o',temp/'no such dir'/'x.nrrd'],6)]:
                r=cli(*form,expected=code);assert not r.stdout and r.stderr,(form,r.stderr)
                assert not (temp/'x.j2k').exists() and not (temp/'x.nrrd').exists()
            # A rejected NRRD profile field never reaches the encoder.
            detached=temp/'detached.nrrd';detached.write_bytes(b'NRRD0004\ntype: uint16\ndimension: 2\nsizes: 2 2\nencoding: raw\nendian: little\ndata file: other.raw\n\n'+bytes(8))
            cli('encode','-i',detached,'-o',temp/'x.j2k',expected=4);assert not (temp/'x.j2k').exists()
            gzipped=temp/'gzip.nrrd';gzipped.write_bytes(b'NRRD0004\ntype: uint16\ndimension: 2\nsizes: 2 2\nencoding: gzip\nendian: little\n\n'+bytes(8))
            cli('encode','-i',gzipped,'-o',temp/'x.j2k',expected=4)
            short=temp/'short.nrrd';short.write_bytes(b'NRRD0004\ntype: uint16\ndimension: 2\nsizes: 2 2\nencoding: raw\nendian: little\n\n'+bytes(6))
            cli('encode','-i',short,'-o',temp/'x.j2k',expected=3)
            # SIGINT before the payload arrives: the interrupt is remembered and the
            # operation cancels cooperatively before decoding starts (exit 130, no output).
            import signal,time
            proc=subprocess.Popen([str(binary),'decode','-i','-','-o',str(temp/'interrupted.nrrd')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
            time.sleep(0.3);proc.send_signal(signal.SIGINT);time.sleep(0.05)
            o,e=proc.communicate(input=(fixtures/'g10_300x200_gradient.opj_n1.j2k').read_bytes(),timeout=30)
            report['commands'].append({'argv':['decode','-i','-','(SIGINT while waiting for stdin)'],'exit_code':proc.returncode,'expected_exit_code':130,'stderr':e.decode(errors='replace')});save()
            assert proc.returncode==130 and not o and not (temp/'interrupted.nrrd').exists(),(proc.returncode,e)
        report['status']='passed';report['checks']=len(report['commands']);save()
        print(f'{tool}: {len(report["commands"])} process checks passed');return 0
    except Exception as error:
        report['status']='failed';report['failure']=str(error);save();raise
if __name__=='__main__':sys.exit(main())
