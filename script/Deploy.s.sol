// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {NDAI} from "../src/NDAI.sol";
import {NDAIStaking} from "../src/NDAIStaking.sol";
import {HEARTFarm} from "../src/HEARTFarm.sol";

/// @notice Minimal deployment script. Anyone may use or modify it.
/// @notice Deployer is fully responsible for the resulting contracts.
contract Deploy is Script {
    // PulseChain PulseX router
    address constant PULSEX_ROUTER = 0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02;

    // Example: December 25, 2026 00:00:00 UTC
    uint256 constant EXAMPLE_LAUNCH_TIME = 1766620800;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 launchTime = vm.envOr("LAUNCH_TIME", EXAMPLE_LAUNCH_TIME);

        vm.startBroadcast(deployerPrivateKey);

        NDAI ndai = new NDAI(PULSEX_ROUTER, launchTime);
        console2.log("NDAI:", address(ndai));

        NDAIStaking staking = new NDAIStaking(address(ndai), launchTime);
        console2.log("NDAIStaking:", address(staking));

        // HEARTFarm requires 7 LP token addresses (NDAI/NEW-1000 through NDAI/NEW-7000).
        // Replace the zeros with real pair addresses after the NEW series and pairs exist.
        address[7] memory lpTokens;
        // lpTokens[0] = NDAI_NEW_1000_PAIR;
        // ... fill the rest before calling

        HEARTFarm farm = new HEARTFarm(lpTokens, launchTime);
        console2.log("HEARTFarm:", address(farm));
        console2.log("HEART:", address(farm.heart()));

        // One-time registration (only the NDAI owner can call this, and only once)
        ndai.setStakingContract(address(staking));
        console2.log("setStakingContract called");

        vm.stopBroadcast();
    }
}
