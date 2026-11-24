# Deployment Notes

Anyone may compile and deploy these contracts without permission from the original author.

## Responsibility
Each deployment is independent. The deployer is fully responsible for:
- Reviewing the source
- Testing before mainnet
- Choosing the correct constructor arguments
- Any bugs, losses, misconfiguration, or other outcomes of the deployed instance

The original author has no control over and accepts no responsibility for any deployed contracts.

## Launch time
Pass the desired `LAUNCH_TIME` (Unix timestamp) in the NDAI constructor.
Minting reverts with `LaunchPending` until that timestamp. The value is immutable after deployment.

Example for December 25, 2026 00:00:00 UTC: `1766620800`

## After deployment
- Call `setStakingContract` once (only the owner can do this, and only once).
- Permanent locks have no withdrawal functions.
- There is no upgrade mechanism.

Use at your own risk.
