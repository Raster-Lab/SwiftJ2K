# Independent public consumer

This separate Swift 6.2 package depends only on the current SwiftJ2K checkout.
It uses a plain public import, forwards a retained storage owner through an
adapter across an asynchronous suspension, checks known 12-in-16 and full 16-bit
samples in padded rows, and checks truthful unsupported encoder and native
transcoder behaviour.

From the repository root:

```sh
swift run --package-path Examples/StandaloneConsumer StandaloneConsumer
```

The local path selects this repository for pre-publication testing. It never
discovers a sibling codec or imports internal/test targets. This is an API and
ownership experiment, not JPEG/JPEG XL compression or reconstruction. A fresh
URL-based consumer remains a separate packaging gate once a reviewable revision
has been published.
