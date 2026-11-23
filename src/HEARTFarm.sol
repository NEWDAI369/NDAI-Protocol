// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {HEART} from "./HEART.sol";

/// @title HEARTFarm
/// @notice Deposit NDAI/NEW-XXXX LP tokens to earn HEART. Weights fixed at deployment.
/// @notice Only this contract can mint HEART (capped at 1 billion).
contract HEARTFarm is ReentrancyGuard {
    using SafeERC20 for IERC20;

    HEART public immutable heart;

    struct Pool {
        IERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accHeartPerShare;
    }

    Pool[] public pools;
    uint256 public totalAllocPoint;
    uint256 public heartPerBlock;
    uint256 public startBlock;

    mapping(uint256 => mapping(address => uint256)) public userInfo; // poolId => user => amount
    mapping(uint256 => mapping(address => uint256)) public rewardDebt;

    event PoolAdded(uint256 indexed pid, address lpToken, uint256 allocPoint);
    event Deposited(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdrawn(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvested(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(uint256 _heartPerBlock, uint256 _startBlock) {
        heart = new HEART(address(this));
        heartPerBlock = _heartPerBlock;
        startBlock = _startBlock;
    }

    function addPool(IERC20 lpToken, uint256 allocPoint) external {
        // In production this should be restricted or called only once at deployment.
        // For this version it is open so pools can be added before launch.
        pools.push(Pool({
            lpToken: lpToken,
            allocPoint: allocPoint,
            lastRewardBlock: block.number > startBlock ? block.number : startBlock,
            accHeartPerShare: 0
        }));
        totalAllocPoint += allocPoint;
        emit PoolAdded(pools.length - 1, address(lpToken), allocPoint);
    }

    function deposit(uint256 pid, uint256 amount) external nonReentrant {
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

    function _updatePool(uint256 pid) internal {
        Pool storage pool = pools[pid];
        if (block.number <= pool.lastRewardBlock) return;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || totalAllocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - pool.lastRewardBlock;
        uint256 heartReward = (multiplier * heartPerBlock * pool.allocPoint) / totalAllocPoint;
        pool.accHeartPerShare += (heartReward * 1e18) / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    function poolLength() external view returns (uint256) {
        return pools.length;
    }
}
