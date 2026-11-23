// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {HEART} from "./HEART.sol";

/// @title HEARTFarm
/// @notice Fixed 7-pool farm for NDAI/NEW-1000 through NDAI/NEW-7000.
/// @notice Declining emission over 4 years. Weights shift toward longer series each year.
/// @notice No admin after deployment. Emissions stop after 4 years or when 1B HEART is minted.
contract HEARTFarm is ReentrancyGuard {
    using SafeERC20 for IERC20;

    HEART public immutable heart;

    uint256 public constant TOTAL_EMISSION = 1_000_000_000 ether;
    uint256 public constant YEAR = 365 days;
    uint256 public immutable startTime;
    uint256 public immutable endTime;

    // Yearly emission amounts (ether)
    uint256[4] public emissionSchedule = [
        350_000_000 ether,
        300_000_000 ether,
        200_000_000 ether,
        150_000_000 ether
    ];

    // Weights per year (sum = 100). Index 0 = NEW-1000 ... Index 6 = NEW-7000
    uint8[7][4] public weightSchedule = [
        [8, 10, 12, 14, 16, 18, 22], // Year 1
        [6,  8, 10, 13, 16, 20, 27], // Year 2
        [5,  6,  8, 11, 15, 22, 33], // Year 3
        [4,  5,  6,  9, 13, 24, 39]  // Year 4
    ];

    struct Pool {
        IERC20 lpToken;
        uint256 lastRewardTime;
        uint256 accHeartPerShare;
    }

    Pool[7] public pools;

    mapping(uint256 => mapping(address => uint256)) public userInfo;   // pid => user => amount
    mapping(uint256 => mapping(address => uint256)) public rewardDebt; // pid => user => rewardDebt

    event Deposited(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvested(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(address[7] memory lpTokens, uint256 _startTime) {
        require(_startTime > 0, "Invalid start");
        heart = new HEART(address(this));
        startTime = _startTime;
        endTime = _startTime + (4 * YEAR);

        for (uint256 i; i < 7; ++i) {
            require(lpTokens[i] != address(0), "Zero LP");
            pools[i] = Pool({
                lpToken: IERC20(lpTokens[i]),
                lastRewardTime: _startTime,
                accHeartPerShare: 0
            });
        }
    }

    function currentYear() public view returns (uint256) {
        if (block.timestamp < startTime) return 0;
        uint256 elapsed = block.timestamp - startTime;
        uint256 y = elapsed / YEAR;
        return y > 3 ? 3 : y;
    }

    function _weight(uint256 pid, uint256 year) internal view returns (uint256) {
        return weightSchedule[year][pid];
    }

    function _emissionPerSecond(uint256 year) internal view returns (uint256) {
        return emissionSchedule[year] / YEAR;
    }

    function _updatePool(uint256 pid) internal {
        Pool storage pool = pools[pid];
        uint256 currentTime = block.timestamp > endTime ? endTime : block.timestamp;
        if (currentTime <= pool.lastRewardTime) return;

        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardTime = currentTime;
            return;
        }

        uint256 reward = _calculateReward(pool.lastRewardTime, currentTime, pid);
        if (reward > 0) {
            pool.accHeartPerShare += (reward * 1e18) / lpSupply;
        }
        pool.lastRewardTime = currentTime;
    }

    function _calculateReward(uint256 from, uint256 to, uint256 pid) internal view returns (uint256) {
        uint256 reward;
        uint256 cursor = from;

        while (cursor < to) {
            uint256 year = (cursor - startTime) / YEAR;
            if (year > 3) break;

            uint256 yearEnd = startTime + ((year + 1) * YEAR);
            uint256 segmentEnd = to < yearEnd ? to : yearEnd;
            if (segmentEnd > endTime) segmentEnd = endTime;

            uint256 duration = segmentEnd - cursor;
            if (duration > 0) {
                uint256 weight = _weight(pid, year);
                uint256 totalWeight = 100;
                reward += (duration * _emissionPerSecond(year) * weight) / totalWeight;
            }
            cursor = segmentEnd;
        }
        return reward;
    }

    function deposit(uint256 pid, uint256 amount) external nonReentrant {
        require(pid < 7, "Invalid pid");
        Pool storage pool = pools[pid];
        _updatePool(pid);

        if (userInfo[pid][msg.sender] > 0) {
            uint256 pending = (userInfo[pid][msg.sender] * pool.accHeartPerShare) / 1e18 - rewardDebt[pid][msg.sender];
            if (pending > 0) {
                heart.mint(msg.sender, pending);
                emit Harvested(msg.sender, pid, pending);
            }
        }

        if (amount > 0) {
            pool.lpToken.safeTransferFrom(msg.sender, address(this), amount);
            userInfo[pid][msg.sender] += amount;
        }

        rewardDebt[pid][msg.sender] = (userInfo[pid][msg.sender] * pool.accHeartPerShare) / 1e18;
        emit Deposited(msg.sender, pid, amount);
    }

    function withdraw(uint256 pid, uint256 amount) external nonReentrant {
        require(pid < 7, "Invalid pid");
        require(userInfo[pid][msg.sender] >= amount, "Insufficient");
        Pool storage pool = pools[pid];
        _updatePool(pid);

        uint256 pending = (userInfo[pid][msg.sender] * pool.accHeartPerShare) / 1e18 - rewardDebt[pid][msg.sender];
        if (pending > 0) {
            heart.mint(msg.sender, pending);
            emit Harvested(msg.sender, pid, pending);
        }

        if (amount > 0) {
            userInfo[pid][msg.sender] -= amount;
            pool.lpToken.safeTransfer(msg.sender, amount);
        }

        rewardDebt[pid][msg.sender] = (userInfo[pid][msg.sender] * pool.accHeartPerShare) / 1e18;
        emit Withdrawn(msg.sender, pid, amount);
    }

    function pendingHeart(uint256 pid, address user) external view returns (uint256) {
        if (pid >= 7) return 0;
        Pool storage pool = pools[pid];
        uint256 acc = pool.accHeartPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));

        if (block.timestamp > pool.lastRewardTime && lpSupply > 0) {
            uint256 currentTime = block.timestamp > endTime ? endTime : block.timestamp;
            uint256 reward = _calculateReward(pool.lastRewardTime, currentTime, pid);
            acc += (reward * 1e18) / lpSupply;
        }

        return (userInfo[pid][user] * acc) / 1e18 - rewardDebt[pid][user];
    }

    function poolLength() external pure returns (uint256) {
        return 7;
    }
}
