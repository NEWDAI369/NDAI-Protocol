# Deployment Notes

Anyone may compile and deploy these contracts without permission from the original author.

## Responsibility
Each deployment is independent. The deployer is fully responsible for:
- Reviewing the source
- Testing before mainnet
- Choosing the correct constructor arguments
- Any bugs, losses, misconfiguration, or other outcomes of the deployed instance

The original author has no control over and accepts no responsibility for any deployed contracts.

## Prerequisites
- Foundry installed
- PulseChain RPC and a funded deployer key
- OpenZeppelin Contracts 5.0.2 (see `remappings.txt` if present, or install via `forge install`)

## Launch time
Pass the desired `LAUNCH_TIME` (Unix timestamp) in the NDAI constructor.
Minting reverts with `LaunchPending` until that timestamp. The value is immutable after deployment.

Example for December 25, 2026 00:00:00 UTC: `1766620800`

## Using the script
```bash
# Optional: set a custom launch time
export LAUNCH_TIME=1766620800
export PRIVATE_KEY=0x...

forge script script/Deploy.s.sol --rpc-url <pulsechain-rpc> --broadcast
```

The script deploys NDAI, NDAIStaking, and HEARTFarm, then calls `setStakingContract` once.

**Note:** HEARTFarm requires 7 LP token addresses (NDAI/NEW-1000 through NDAI/NEW-7000). Update the `lpTokens` array in the script with the real pair addresses before running.

## Manual constructor arguments (if not using the script)
- NDAI: `(IPulseXRouter router, uint256 launchTime)`
  - Router: `0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02`
- NDAIStaking: `(address ndai, uint256 launchTime)`
- HEARTFarm: `(address[7] lpTokens, uint256 startTime)`

## After deployment checklist
- Confirm `LAUNCH_TIME` matches the intended date
- Confirm permanent lock addresses have no withdrawal functions
- Confirm `setStakingContract` was called exactly once
- Confirm HEARTFarm pools point to the correct LP tokens
- Verify source on the PulseChain explorer if desired

## Testing before mainnet
```bash
forge test
```

Use at your own risk.
