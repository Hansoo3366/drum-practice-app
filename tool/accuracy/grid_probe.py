"""Isolated Audiveris GRID experiments; never edit the service or source book.

Run on the OMR host. SOURCE is an existing QA job's processed PDF. Outputs
are diagnostic candidates, not production scores or accuracy measurements.
"""
import argparse
import json
import os
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--chunk', type=float, default=1.2)
    parser.add_argument('--step', choices=('GRID', 'PAGE'), default='GRID')
    args = parser.parse_args()
    if args.output.exists():
        parser.error('output must be new')
    args.output.mkdir(parents=True)
    logback = args.output / 'logback.xml'
    logback.write_text('''<configuration>
<appender name="stdout" class="ch.qos.logback.core.ConsoleAppender">
<encoder><pattern>%level %logger{1} %msg%n</pattern></encoder></appender>
<logger name="org.audiveris.omr.sheet.grid.StaffProjector" level="DEBUG"/>
<logger name="org.audiveris.omr.sheet.grid.BarsRetriever" level="DEBUG"/>
<logger name="org.audiveris.omr.sig.SigReducer" level="DEBUG"/>
<logger name="org.audiveris.omr.sheet.rhythm.MeasuresBuilder" level="DEBUG"/>
<root level="WARN"><appender-ref ref="stdout"/></root></configuration>''')
    env = dict(os.environ, JAVA_TOOL_OPTIONS=f'-Xmx2g -Dlogback.configurationFile={logback}',
               TESSDATA_PREFIX='/opt/omr/tessdata')
    cmd = ['xvfb-run', '-a', '/opt/audiveris/bin/Audiveris', '-batch', '-step', args.step,
           '-output', str(args.output),
           '-constant', 'org.audiveris.omr.image.ImageLoading.pdfResolution=300',
           '-constant', f'org.audiveris.omr.sheet.grid.StaffProjector.chunkThreshold={args.chunk}',
           '-constant', 'org.audiveris.omr.sheet.ProcessingSwitches.indentations=false',
           '-constant', 'org.audiveris.omr.sheet.ProcessingSwitches.dynamicsAboveStaff=false',
           '-constant', 'org.audiveris.omr.sheet.ProcessingSwitches.dynamicsBelowStaff=false',
           '-constant', 'org.audiveris.omr.text.Language.defaultSpecification=eng+kor',
           '--', str(args.source)]
    if args.step == 'PAGE':
        cmd.insert(4, '-export')
    (args.output / 'command.json').write_text(json.dumps(cmd))
    with (args.output / 'grid.log').open('w') as log:
        subprocess.run(cmd, env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
    print(args.output)


if __name__ == '__main__':
    main()
