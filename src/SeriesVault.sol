// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IHEART {
    function burn(uint256 amount) external;
}

/// @title SeriesVault
/// @notice Deposit HEART to earn pro-rata NEW fees for a specific maturity series.
/// @notice 90-day lock-up. Any new deposit resets the timer. Early withdrawal burns a linear penalty.
contract SeriesVault is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant LOCK_PERIOD = 90 days;

    IERC20 public immutable heart;
    IERC20 public immutable newToken;
    uint256 public immutable maturityDay;

    uint256 public totalHeartDeposited;
    mapping(address => uint256) public heartBalance;
    mapping(address => uint256) public depositTime; // last deposit time (resets on any new deposit)

    uint256 public accNewPerShare;
    mapping(address => uint256) public rewardDebt;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 burned);
    event FeeNotified(uint256 amount);
    event Harvested(address indexed user, uint256 amount);

    constructor(address _heart, address _newToken, uint256 _maturityDay) {
        heart = IERC20(_heart);
        newToken = IERC20(_newToken);
        maturityDay = _maturityDay;
    }

    function deposit(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        _harvest(msg.sender);
        heart.safeTransferFrom(msg.sender, address(this), amount);
        heartBalance[msg.sender] += amount;
        totalHeartDeposited += amount;
        depositTime[msg.sender] = block.timestamp; // reset lock timer on any deposit
        rewardDebt[msg.sender] = (heartBalance[msg.sender] * accNewPerShare) / 1e18;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Zero amount");
        require(heartBalance[msg.sender] >= amount, "Insufficient");
        _harvest(msg.sender);

        uint256 servedTime = block.timestamp - depositTime[msg.sender];
        uint256 toUser = amount;
        uint256 toBurn = 0;

        if (servedTime < LOCK_PERIOD) {
            // Linear penalty: 100% at day 0 → 0% at day 90
            toUser = amount * servedTime / LOCK_PERIOD;
            toBurn = amount - toUser;
        }

        heartBalance[msg.sender] -= amount;
        totalHeartDeposited -= amount;

        if (toBurn > 0) {
            IHEART(address(heart)).burn(toBurn);
        }
        if (toUser > 0) {
            heart.safeTransfer(msg.sender, toUser);
        }

        rewardDebt[msg.sender] = (heartBalance[msg.sender] * accNewPerShare) / 1e18;
        emit Withdrawn(msg.sender, toUser, toBurn);
    }

    /// @notice Called when 1% NEW fee is sent to this vault.
    function notifyFee(uint256 newFeeAmount) external {
        if (totalHeartDeposited == 0) return; // fee waived
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

    function timeUntilUnlock(address user) external view returns (uint256) {
        if (depositTime[user] == 0) return 0;
        uint256 unlock = depositTime[user] + LOCK_PERIOD;
        if (block.timestamp >= unlock) return 0;
        return unlock - block.timestamp;
    }
}
