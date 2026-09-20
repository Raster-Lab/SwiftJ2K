# Candidate SBOM provenance and field audit

All eight original build-associated SBOMs in `work/swift64/candidate/<repository>/sboms/` parse as JSON and match the SHA-256 values in their build reports. Each generating command is `swift build --product <repository>`, exited zero, and identifies the package/product at the recorded source commit plus `-modified`. The exact candidate is pinned by the accompanying source-file hashes; a commit with a dirty suffix alone cannot identify uncommitted bytes. The originals were neither edited nor replaced. `candidate-audit.json` records full paths, hashes, identifiers, commands' dispositions and precise JSON pointers.

The emitted package graphs contain the correct standalone package and its product, without sibling codec packages or other runtime SwiftPM dependencies. SwiftPM records itself as tooling. Native SDK frameworks, the Swift runtime, Xcode and operating-system components are not inventoried as package components. These require the separate toolchain/SDK record; the absence of an external SwiftPM dependency is not absence of native linkage. Core product licence metadata is also absent from the emitted CycloneDX components; the repository MIT/provenance record remains necessary.

## Confirmed field findings in all four candidates

- **SPDX 3.0.1:** a `CreationInfo` associated with the generator has `specVersion: "6.4.0-dev"`, while the document's other creation record says `3.0.1`. That value describes the SPDX specification used to interpret its elements, not the generator version. This is a semantic mismatch based on [SPDX's property definition](https://spdx.github.io/spdx-spec/v3.0.1/model/Core/Properties/specVersion/); it is not an executed whole-document validation result.
- **SPDX 3.0.1:** the package and product objects emit `externalUrl`. The [official schema](https://spdx.org/schema/3.0.1/spdx-json-schema.json) has no such property, defines `software_packageUrl`, and disallows unevaluated graph-item properties. This field inspection identifies a schema incompatibility; a full schema-engine run remains unexecuted.
- **CycloneDX 1.7:** the same product `bom-ref` occurs at `/components/1/bom-ref` and `/metadata/component/bom-ref`. The [official component definition](https://cyclonedx.org/schema/bom-1.7.schema.json) requires identifiers to be unique throughout the BOM. The duplication is directly checked; this does not imply a generic JSON Schema engine enforces cross-document uniqueness.

These findings come from Xcode's SwiftPM generator output, not the codec implementation or the validation wrapper. Preserve the files as evidence and resolve the generator/conformance defects before relying on them as qualified SBOMs. Merely renaming fields or deleting duplicate entries would create a derived document and would need its own provenance and validation; none was done here.

## Validation gate remains open

The installed generator warns that its `SwiftPM_SBOMModel` schema bundle is missing. Its zero exit code proves generation, not schema conformance. Neither the system nor bundled Python contains `jsonschema`, `referencing`, `rdflib` or `pyshacl`; no suitable JSON Schema validator was found in the existing Node/Homebrew runtime paths. Direct schema downloads through the local shell failed DNS resolution. No dependencies were installed and no schema bytes/hash were fabricated.

The versioned official schema URLs were inspected through the web tool on 19 September 2026:

- [SPDX 3.0.1 JSON Schema](https://spdx.org/schema/3.0.1/spdx-json-schema.json): JSON Schema 2020-12.
- [SPDX 3.0.1 OWL/SHACL model](https://spdx.org/rdf/3.0.1/spdx-model.ttl): the separate semantic stage required by the [SPDX validation requirements](https://spdx.github.io/spdx-spec/v3.0.1/serializations/).
- [CycloneDX 1.7 JSON Schema](https://cyclonedx.org/schema/bom-1.7.schema.json): JSON Schema draft-07, with its referenced subschemas.

A future independent validation should capture the exact schema bytes/digests and validator version, validate unchanged emitted files, retain every failure, and separately enforce semantic/reference constraints. Re-run generation and validation against the eventual clean release candidate. Current records intentionally distinguish JSON parsing and field inspection from full schema or semantic validation. This audit does not close the release gate.
