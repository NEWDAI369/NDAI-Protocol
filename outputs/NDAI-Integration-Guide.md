# NDAI Integration Guide

## Minting
Call `mintWithPdai` on the NDAI contract. The user pays pDAI. The contract:
- Swaps a portion of pDAI for bridged DAI and locks it permanently
- Uses another portion to add pDAI/PLSX liquidity that is locked permanently
- Mints NDAI to the user

NDAI is not redeemable for DAI.

Minting is disabled until December 25, 2026. The contract reverts with `LaunchPending` before that date. After December 25, 2026 minting becomes available. The date is set at deployment and cannot be changed.

## Staking
1. Approve NDAI to the staking contract.
2. Call `createStake(amount, lengthInDays)`.
3. Longer stakes receive a higher multiplier (1× to 3×).
4. Call `extractNEW(stakeId, newTokenAddress)` to mint NEW tokens for accrued yield without ending the stake. The NEW token’s maturity day must match the stake’s end day.
5. After the end day, call `endStake(stakeId)` to receive principal plus any remaining yield.

## NEW tokens
NEW is an ERC-20. After its maturity day, holders can call `redeem` to burn NEW and receive NDAI 1:1.

## Launch
Minting opens on December 25, 2026. Before that date calls to `mintWithPdai` revert with `LaunchPending`. Staking day counting starts from the same timestamp set at deployment.
