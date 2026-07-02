# Contributing to Trackled

Thanks for your interest in improving Trackled! This is a small project, so the
process is intentionally lightweight.

## Reporting bugs & requesting features

Please [open an issue](https://github.com/somsomers/trackled/issues) and include:

- what you expected to happen and what actually happened;
- your macOS version;
- steps to reproduce (for bugs).

## Development setup

```sh
git clone https://github.com/somsomers/trackled.git
cd trackled
swift build
swift run
```

To test features that need a real app bundle (e.g. *Launch at login*), build the
bundle instead:

```sh
./make_app.sh
open build/Trackled.app
```

## Pull requests

1. Fork the repo and create a branch off `main`.
2. Keep changes focused; match the existing code style (SwiftUI, small views,
   comments where intent isn't obvious).
3. Make sure `swift build` succeeds with no warnings.
4. Describe *what* changed and *why* in the PR description.

## Commit messages

Write clear, present-tense messages that explain the change, e.g.
`Add idle-timeout setting` rather than `fix stuff`.

## Code of conduct

By participating you agree to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).
