// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title SeriesVault
/// @notice Deposit HEART to earn pro-rata NEW fees for a specific maturity series.
contract SeriesVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable heart;
    IERC20 public immutable newToken;
    uint256 public immutable maturityDay;

    uint256 public totalHeartDeposited;
    mapping(address => uint256) public heartBalance;
    uint256 public accNewPerShare;
    mapping(address => uint256) public rewardDebt;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event FeeNotified(uint256 amount);
    event Harvested(address indexed user, uint256 amount);

    constructor(address _heart, address _newToken, uint256 _maturityDay) {
        heart = IERC20(_heart);
        newToken = IERC20(_newToken);
        maturityDay = _maturityDay;
    }

    function deposit(uint256 amount) external nonReentrant {
        _harvest(msg.sender);
        heart.safeTransferFrom(msg.sender, address(this), amount);
        heartBalance[msg.sender] += amount;
        totalHeartDeposited += amount;
        rewardDebt[msg.sender] = (heartBalance[msg.sender] * accNewPerShare) / 1e18;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(heartBalance[msg.sender] >= amount, "Insufficient");
        _harvest(msg.sender);
        heartBalance[msg.sender] -= amount;
        totalHeartDeposited -= amount;
        heart.safeTransfer(msg.sender, amount);
        rewardDebt[msg.sender] = (heartBalance[msg.sender] * accNewPerShare) / 1e18;
        emit Withdrawn(msg.sender, amount);
    }

    /// @notice Called when 1% NEW fee is sent to this vault.
    function notifyFee(uint256 newFeeAmount) external {
        if (totalHeartDeposited == 0) return; // fee waived
        // NEW tokens must be transferred in by the caller before or with this call
        accNewPerShare += (newFeeAmount * 1e18) / totalHeartDeposited;
        emit FeeNotified(newFeeAmount);
    }

    function _harvest(address user) internal {
        uint256 pending = (heartBalance[user] * accNewPerShare) / 1e18 - rewardDebt[user];
        if (pending > 0) {
            newToken.safeTransfer(user, pending);
            emit Harvested(user, pending);
        }
    }

    function pendingFees(address user) external view returns (uint256) {
        return (heartBalance[user] * accNewPerShare) / 1e18 - rewardDebt[user];
    }
}
