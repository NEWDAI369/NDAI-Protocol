> [!WARNING]
> **This project is no longer maintained and will not receive updates.**
>
> The contracts have known, unfixed bugs. **Do not deploy or use them as-is.** Anyone who deploys must fix these issues first:
>
> 1. **Staking rewards are not funded.** `NDAIStaking.endStake` and `NEW.redeem` pay rewards with `ndai.safeTransfer` from the staking contract's own NDAI balance, which is other stakers' principal. Nothing is minted for rewards, so the last stakers to exit can be left short. Rewards should be minted (for example through `NDAI.mintYield`) or paid from a separately funded pool.
> 2. **Reward shares can be gamed.** Each stake's reward is computed from the *current* `totalWeight` multiplied by all days elapsed, so past rewards are repriced whenever stakes start or end. Users can time extracts or `endStake` to take more than their share. Use a reward-per-weight accumulator that checkpoints on every stake change.
> 3. **No tests cover the staking reward logic.** Add tests and an independent audit before any deployment.
>
> Once deployed, contracts cannot be changed, so these fixes must land **before** anyone runs `script/Deploy.s.sol`.

# NDAI Protocol

**Anyone may compile and deploy these contracts without permission from the original author.**

Each deployment is independent. The original author has no control over, and accepts no responsibility for, any deployed instance (bugs, losses, misconfiguration, or any other outcome).

**Use at your own risk.** You are solely responsible for reviewing and testing before deploying or interacting. You can lose all assets you commit. There is no peg, no DAI redemption right, and yield is not guaranteed.

NDAI is a PulseChain token (chain ID 369). Users mint NDAI by paying pDAI. The protocol permanently locks a matching amount of bridged DAI in a non-withdrawable reserve and adds pDAI/PLSX liquidity that is also locked forever. NDAI cannot be redeemed for DAI and has no dollar peg.

### Important
The DAI locked during minting cannot be withdrawn by anyone. It serves only as a public display of mint volume. NDAI has no claim on the reserve.

### Launch
Minting is disabled until December 25, 2026. The contract reverts with `LaunchPending` before that date. After December 25, 2026 minting becomes available. The date is set at deployment and cannot be changed.

### How Minting Works
1. You call `mintWithPdai` and send pDAI.
2. The contract swaps most of the pDAI for bridged DAI and locks that DAI forever.
3. It uses an extra 10% of the pDAI cost for liquidity:
   - 5% is swapped for PLSX
   - 5% stays as pDAI
   - Both are added as permanent pDAI/PLSX LP (locked forever)
4. You receive newly minted NDAI equal to the amount of DAI that was locked.

Example: To mint 100 NDAI, the contract locks ~100 DAI and also locks permanent LP made from ~5% pDAI + 5% PLSX.

### Staking
After you have NDAI you can stake it:

- You choose any length (in days).
- Longer and larger stakes earn more (weighted by amount × length multiplier, 1× up to 3×).
- Total yearly reward pool is 0.369% of all minted NDAI, distributed pro-rata by stake weight.
- Example: 1,000,000 NDAI minted → 3,690 NDAI available for all stakers combined that year.
- You can extract the accrued reward early as **NEW** tokens without ending the stake.
- When the stake matures you can end it and receive your principal plus any remaining reward.
- The rate is fixed at deployment and cannot be changed. Day count uses block.timestamp only.

### NEW Tokens
NEW is a transferable ERC-20 time-claim token.

- You extract NEW against the reward your stake has earned.
- The NEW token’s maturity day matches the end day of your stake.
- On or after that day, anyone holding the NEW can redeem it 1:1 for NDAI.

### HEART, Vaults, and Farms
- **HEART** is the farm and vault token. Total supply is capped at 1 billion. Only the farm contract can mint it.
- Deposit HEART into a series vault (one per NEW maturity) to earn a pro-rata share of NEW fees from that series. 90-day lock with linear early-withdrawal burn penalty.
- HEARTFarm is fixed for exactly 7 pools: NDAI/NEW-1000 through NDAI/NEW-7000.
- Emission schedule over 4 years (total 1 billion HEART):
  - Year 1: 350M
  - Year 2: 300M
  - Year 3: 200M
  - Year 4: 150M
- Weights shift toward longer series each year. All 7 series stay active for the full 4 years.
- No admin functions after deployment. Emissions stop after 4 years or when 1B HEART is minted.

### Key Rules
- Permanent hard-locked DAI reserve on every mint
- Permanent hard-locked pDAI/PLSX LP on every mint
- No admin keys that can withdraw the locked assets
- No dollar peg and no redemption for DAI
- Longer and larger stakes earn more
- Reward pool is 0.369% of total minted NDAI per year
- Extract reward as NEW without ending the stake
- HEART capped at 1 billion, farm-only mint
- Farm is fixed at 7 series with declining emission and yearly weight shifts
- Minting opens on December 25, 2026

### Risks
- NDAI has no peg and cannot be redeemed for DAI
- The locked DAI and LP can never be withdrawn
- Smart-contract risk, market risk, and liquidity risk apply
- Yield is not guaranteed
- Use at your own risk

### Contracts
- `src/NDAI.sol` — minting
- `src/NDAIStaking.sol` — staking and NEW tokens
- `src/HEART.sol` — HEART token (1 billion cap, farm-only mint)
- `src/SeriesVault.sol` — per-series vault for HEART deposits earning NEW fees (90-day lock)
- `src/HEARTFarm.sol` — fixed 7-series farm with 4-year declining emission

### Documentation
- [Risk disclosure](outputs/NDAI-Risk-Disclosure.md)
- [Integration guide](outputs/NDAI-Integration-Guide.md)
- [Deployment notes](DEPLOYMENT.md)
- [Deployment script](script/Deploy.s.sol)

Anyone may deploy. See the MIT LICENSE for full terms. The original author is not liable for any deployed instance. Review and test before use.
