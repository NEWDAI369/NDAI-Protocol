# NDAI Protocol

NDAI is a PulseChain token (chain ID 369). Users mint NDAI by paying pDAI. The protocol permanently locks a matching amount of bridged DAI in a non-withdrawable reserve and adds pDAI/PLSX liquidity that is also locked forever. NDAI cannot be redeemed for DAI and has no dollar peg.

**Use at your own risk.** You can lose all assets you commit. There is no peg, no DAI redemption right, and yield is not guaranteed.

### Important
The DAI locked during minting cannot be withdrawn by anyone. It serves only as a public display of mint volume. NDAI has no claim on the reserve.

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
- Total yearly reward pool is 0.03% of all minted NDAI, distributed pro-rata by stake weight.
- Example: 1,000,000 NDAI minted → 300 NDAI available for all stakers combined that year.
- You can extract the accrued reward early as **NEW** tokens without ending the stake.
- When the stake matures you can end it and receive your principal plus any remaining reward.
- The rate is fixed at deployment and cannot be changed. Day count uses block.timestamp only.

### NEW Tokens
NEW is a transferable ERC-20 time-claim token.

- You extract NEW against the reward your stake has earned.
- The NEW token’s maturity day matches the end day of your stake.
- On or after that day, anyone holding the NEW can redeem it 1:1 for NDAI.

### Key Rules
- Permanent hard-locked DAI reserve on every mint
- Permanent hard-locked pDAI/PLSX LP on every mint
- No admin keys that can withdraw the locked assets
- No dollar peg and no redemption for DAI
- Longer and larger stakes earn more
- Reward pool is 0.03% of total minted NDAI per year
- Extract reward as NEW without ending the stake

### Risks
- NDAI has no peg and cannot be redeemed for DAI
- The locked DAI and LP can never be withdrawn
- Smart-contract risk, market risk, and liquidity risk apply
- Yield is not guaranteed
- Use at your own risk

### Contracts
- `src/NDAI.sol` — minting
- `src/NDAIStaking.sol` — staking and NEW tokens

### Documentation
- [Risk disclosure](outputs/NDAI-Risk-Disclosure.md)
- [Integration guide](outputs/NDAI-Integration-Guide.md)
