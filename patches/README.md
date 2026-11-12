# Kernel patches

Keep this directory empty until a concrete BubbleOS kernel change is justified.

Every patch must:
- apply cleanly to the pinned upstream commit;
- have a clear rationale and upstream status;
- be as small as practical;
- include tests or a documented validation procedure;
- avoid changing unrelated driver behavior;
- be removable independently.

Prefer upstreaming generally useful fixes instead of maintaining permanent private forks.
