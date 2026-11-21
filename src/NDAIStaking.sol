// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface INDAI {
    function totalSupply() external view returns (uint256);
}

/// @title NDAIStaking
/// @notice Stake NDAI. Rewards are a share of a 0.03% yearly pool of total minted NDAI.
/// @notice Longer and larger stakes earn more (amount × length multiplier).
/// @notice Rate is fixed and cannot be changed. Day count uses block.timestamp only.
/// @notice NEW tokens are redeemable 1:1 for NDAI on or after the stake's end day.
contract NDAIStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable ndai;
    uint256 public immutable launchTime;

    // 0.03% per year of total minted NDAI, distributed to weighted stakers
    uint256 public constant YEARLY_RATE_BPS = 3; // 0.03% = 3 basis points

    struct StakeInstance {
        uint256 principal;
        uint256 startDay;
        uint256 endDay;
        uint256 extracted;
        uint256 weight; // principal * multiplier
        bool active;
    }

    mapping(address => StakeInstance[]) public stakeInstances;
    uint256 public totalWeight;

    event StakeCreated(address indexed user, uint256 stakeId, uint256 amount, uint256 endDay, uint256 weight);
    event YieldExtracted(address indexed user, uint256 stakeId, uint256 newAmount);
    event StakeEnded(address indexed user, uint256 stakeId, uint256 payout);

    constructor(address _ndai, uint256 _launchTime) {
        ndai = IERC20(_ndai);
        launchTime = _launchTime;
    }

    function currentDay() public view returns (uint256) {
        if (block.timestamp < launchTime) return 0;
        return (block.timestamp - launchTime) / 1 days;
    }

    /// @notice Length multiplier: 1x up to 3x.
    function getMultiplier(uint256 lengthInDays) public pure returns (uint256) {
        if (lengthInDays <= 1) return 1e18;
        uint256 bonus = ((lengthInDays - 1) * 1e18) / 1820;
        if (bonus > 2e18) bonus = 2e18;
        return 1e18 + bonus;
    }

    function createStake(uint256 amount, uint256 lengthInDays) external nonReentrant {
        require(amount > 0 && lengthInDays >= 1, "Invalid");
        ndai.safeTransferFrom(msg.sender, address(this), amount);

        uint256 multiplier = getMultiplier(lengthInDays);
        uint256 weight = (amount * multiplier) / 1e18;

        uint256 start = currentDay();
        stakeInstances[msg.sender].push(StakeInstance({
            principal: amount,
            startDay: start,
            endDay: start + lengthInDays,
            extracted: 0,
            weight: weight,
            active: true
        }));

        totalWeight += weight;

        emit StakeCreated(msg.sender, stakeInstances[msg.sender].length - 1, amount, start + lengthInDays, weight);
    }

    function extractNEW(uint256 stakeId, address newToken) external nonReentrant {
        StakeInstance storage s = stakeInstances[msg.sender][stakeId];
        require(s.active, "Inactive");
        require(NEW(newToken).staking() == address(this), "Invalid NEW");
        require(NEW(newToken).maturityDay() == s.endDay, "Maturity mismatch");

        uint256 dayNow = currentDay();
        uint256 effectiveDay = dayNow > s.endDay ? s.endDay : dayNow;
        uint256 daysElapsed = effectiveDay > s.startDay ? effectiveDay - s.startDay : 0;

        uint256 totalMinted = INDAI(address(ndai)).totalSupply();
        uint256 yearlyPool = (totalMinted * YEARLY_RATE_BPS) / 10000;
        uint256 dailyPool = yearlyPool / 365;

        uint256 userShare = totalWeight == 0 ? 0 : (dailyPool * s.weight) / totalWeight;
        uint256 accrued = userShare * daysElapsed;
        uint256 available = accrued > s.extracted ? accrued - s.extracted : 0;
        require(available > 0, "Nothing");

        s.extracted += available;
        NEW(newToken).mint(msg.sender, available);

        emit YieldExtracted(msg.sender, stakeId, available);
    }

    function endStake(uint256 stakeId) external nonReentrant {
        StakeInstance storage s = stakeInstances[msg.sender][stakeId];
        require(s.active, "Inactive");
        require(currentDay() >= s.endDay, "Not matured");

        uint256 daysElapsed = s.endDay - s.startDay;

        uint256 totalMinted = INDAI(address(ndai)).totalSupply();
        uint256 yearlyPool = (totalMinted * YEARLY_RATE_BPS) / 10000;
        uint256 dailyPool = yearlyPool / 365;

        uint256 userShare = totalWeight == 0 ? 0 : (dailyPool * s.weight) / totalWeight;
        uint256 totalYield = userShare * daysElapsed;
        uint256 remainingYield = totalYield > s.extracted ? totalYield - s.extracted : 0;

        totalWeight -= s.weight;
        s.active = false;

        uint256 payout = s.principal + remainingYield;
        ndai.safeTransfer(msg.sender, payout);

        emit StakeEnded(msg.sender, stakeId, payout);
    }
}

contract NEW is ERC20 {
    address public immutable staking;
    uint256 public immutable maturityDay;

    constructor(address _staking, uint256 _maturityDay, string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        staking = _staking;
        maturityDay = _maturityDay;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == staking, "Only staking");
        _mint(to, amount);
    }

    function redeem(uint256 amount) external {
        require(NDAIStaking(staking).currentDay() >= maturityDay, "Early");
        _burn(msg.sender, amount);
        IERC20(NDAIStaking(staking).ndai()).transfer(msg.sender, amount);
    }
}
