// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title HEART
/// @notice Farm and vault token. Total supply capped at 1 billion. Only the farm can mint.
contract HEART is ERC20 {
    address public immutable farm;
    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether; // 1 billion

    constructor(address _farm) ERC20("HEART", "HEART") {
        farm = _farm;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == farm, "Only farm");
        require(totalSupply() + amount <= MAX_SUPPLY, "Cap");
        _mint(to, amount);
    }

    /// @notice Burns HEART from the caller's balance. Used by SeriesVault for early-withdrawal penalties.
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
