#!/usr/bin/env python3
"""Provenance/field audit only: this is NOT a JSON Schema or SHACL validator."""
from pathlib import Path
from collections import defaultdict
import hashlib, json
ROOT = Path(__file__).resolve().parent
CANDIDATE = ROOT.parent / 'candidate'
rows = []
for name in ('SwiftJ2K', 'SwiftJLS', 'SwiftJXL', 'SwiftJLI'):
    directory = CANDIDATE / name
    report = json.loads((directory/'report.json').read_text())
    commit = report['source_commit']
    digests = {entry['path']: entry['sha256'] for entry in report.get('sboms', [])}
    if len(digests) != 2:
        raise RuntimeError(f'{name}: expected both final build-associated SBOMs, found {len(digests)}')
    for spec in ('spdx', 'cyclonedx'):
        files = sorted((directory/'sboms'/spec).glob('*.json'))
        if len(files) != 1:
            raise RuntimeError(f'{name}: expected one {spec} file')
        path = files[0]
        body = path.read_bytes()
        document = json.loads(body)
        command = next(c for c in report['commands'] if c['label'] == 'sbom-'+spec)
        argv = command['argv']
        row = {'repository':name, 'format':spec, 'path':str(path),
               'sha256':hashlib.sha256(body).hexdigest(), 'candidate_report_status':report['status'],
               'source_commit':commit, 'command_exit':command['exit_code'],
               'build_associated_command': 'build' in argv and 'generate-sbom' not in argv,
               'product_option_matches':argv[argv.index('--product')+1] == name,
               'json_parse':'passed', 'json_schema_validation':'not_executed',
               'semantic_validation':'not_executed', 'findings':[]}
        row['sha256_matches_build_report'] = row['sha256'] == digests[str(path.relative_to(directory))]
        if spec == 'spdx':
            graph=document['@graph']
            packages=[(index,item) for index,item in enumerate(graph) if item.get('type')=='software_Package']
            row['context']=document.get('@context')
            row['packages']=[{'name':item.get('name'),'version':item.get('software_internalVersion'),
                              'id':item.get('spdxId'),'externalUrl':item.get('externalUrl')} for _,item in packages]
            row['package_versions_match_source'] = all(item.get('software_internalVersion','').startswith(commit) for _,item in packages)
            for index,item in enumerate(graph):
                if item.get('type')=='CreationInfo' and item.get('specVersion')!='3.0.1':
                    row['findings'].append({'kind':'specVersion_semantic_mismatch', 'json_pointer':f'/@graph/{index}/specVersion',
                        'value':item.get('specVersion'), 'evidence':'SPDX specVersion describes SPDX specification version, not the generator software version; no whole-document schema execution is claimed.'})
            for index,item in packages:
                if 'externalUrl' in item:
                    row['findings'].append({'kind':'nonstandard_package_property', 'json_pointer':f'/@graph/{index}/externalUrl',
                        'value':item['externalUrl'], 'evidence':'Official SPDX 3.0.1 JSON Schema has no externalUrl property, defines software_packageUrl, and prohibits unevaluated graph-item properties. This is field inspection, not executed full schema validation.'})
            row['sdk_components_present'] = any(item.get('name') in ('Foundation','Synchronization','Swift','MacOSX.sdk','Xcode') for item in graph)
        else:
            row['schema']=document.get('$schema')
            row['spec_version']=document.get('specVersion')
            row['packages']=[{'name':item.get('name'),'version':item.get('version'),'id':item.get('bom-ref'),'purl':item.get('purl')} for item in document['components']]
            row['package_versions_match_source'] = all(item.get('version','').startswith(commit) for item in document['components'])
            locations=defaultdict(list)
            def visit(obj, pointer=''):
                if isinstance(obj, dict):
                    if 'bom-ref' in obj:
                        locations[obj['bom-ref']].append(pointer+'/bom-ref')
                    for key,value in obj.items():
                        visit(value,pointer+'/'+key.replace('~','~0').replace('/','~1'))
                elif isinstance(obj, list):
                    for index,value in enumerate(obj):
                        visit(value,pointer+'/'+str(index))
            visit(document)
            for reference,pointers in locations.items():
                if len(pointers)>1:
                    row['findings'].append({'kind':'duplicate_bom_ref', 'value':reference,'json_pointers':pointers,
                        'evidence':'Official CycloneDX 1.7 component.bom-ref description requires identifiers to be unique across the BOM. This is a directly checked uniqueness finding, not a claim that JSON Schema engines enforce it.'})
            row['sdk_components_present'] = any(item.get('name') in ('Foundation','Synchronization','Swift','MacOSX.sdk','Xcode') for item in document['components'])
            row['declared_dependency_graph']=document.get('dependencies')
            row['core_product_licence_present'] = 'licenses' in document['metadata']['component']
        assert row['build_associated_command'] and row['product_option_matches'] and row['sha256_matches_build_report'] and row['package_versions_match_source']
        rows.append(row)
result = {'audit_scope':'Original final candidate build-associated SBOMs; field/provenance checks only.',
          'schema_validation_status':'open: installed SwiftPM skipped missing schemas; no installed JSON Schema/SHACL validator; direct schema fetching blocked by host DNS restrictions. No dependencies installed.',
          'primary_sources': {
              'spdx_json_schema':'https://spdx.org/schema/3.0.1/spdx-json-schema.json',
              'spdx_json_schema_draft':'2020-12',
              'spdx_semantic_model':'https://spdx.org/rdf/3.0.1/spdx-model.ttl',
              'spdx_validation_requirements':'https://spdx.github.io/spdx-spec/v3.0.1/serializations/',
              'spdx_spec_version_definition':'https://spdx.github.io/spdx-spec/v3.0.1/model/Core/Properties/specVersion/',
              'cyclonedx_json_schema':'https://cyclonedx.org/schema/bom-1.7.schema.json',
              'cyclonedx_json_schema_draft':'draft-07',
              'schema_source_revision':'Versioned official URLs inspected via web 2026-09-19; no locally downloaded bytes/hash are claimed.'},
          'results':rows}
(ROOT/'candidate-audit.json').write_text(json.dumps(result,indent=2)+'\n')
for row in rows:
    print(row['repository'],row['format'],row['sha256'],[finding['kind'] for finding in row['findings']])
print('8 SBOMs audited; original files unchanged; full schema/semantic qualification remains open.')
