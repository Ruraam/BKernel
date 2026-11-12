# Kernel configuration

Configuration fragments will be introduced only after the upstream Linux baseline and target profile are pinned.

Rules:
- begin with the upstream x86_64 default configuration;
- preserve broad hardware support rather than tailoring to one development PC;
- split BubbleOS-specific options into a small, documented fragment;
- validate the merged configuration with the upstream Kconfig tools;
- archive the final effective `.config` for every build.

Do not add a generated `.config` until it can be tied to an exact kernel source revision.
