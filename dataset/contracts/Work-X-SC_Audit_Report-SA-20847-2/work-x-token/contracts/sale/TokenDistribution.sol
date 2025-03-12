// SPDX-License-Identifier: MIT

pragma solidity ^0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../work/WorkToken.sol";

//TODO: remove all console.log from contracts
import "hardhat/console.sol";

contract TokenDistribution is Ownable, AccessControl, ReentrancyGuard {
    WorkToken public workToken;

    uint256 public startTime;
    uint256 public constant VESTING_PERIOD1 = 547.5 days;
    uint256 public constant VESTING_PERIOD2 = 365 days;
    uint256 public constant VESTING_PERIOD3 = 273.75 days;
    uint256 public constant VESTING_PERIOD3_CLIFF = 27.375 days;

    event ClaimTokens(address beneficiary, uint256 amount);

    struct Balance {
        uint32 totalBought;
        uint32 bought1;
        uint32 bought2;
        uint32 bought3;
        uint256 totalClaimed;
    }
    mapping(address => Balance) public accountBalance;

    constructor(address _tokenAddress) {
        workToken = WorkToken(_tokenAddress);
        startTime = block.timestamp;
    }

    /****
     **** EXTERNAL WRITE
     ****/

    function claimTokens() external nonReentrant {
        require(block.timestamp >= startTime, "TokenDistribution: The distribution hasn't started yet");
        uint256 availableTokens = _claimableTokens(msg.sender);
        require(availableTokens > 0, "TokenDistribution: You don't have any tokens to claim");
        Balance storage _balance = accountBalance[msg.sender];
        _balance.totalClaimed = _balance.totalClaimed + availableTokens;
        workToken.mint(msg.sender, availableTokens);

        emit ClaimTokens(msg.sender, availableTokens);
    }

    /****
     **** ONLY OWNER
     ****/

    function startDistribution(uint256 _startTime) external onlyOwner {
        require(startTime < block.timestamp, "TokenDistribution: The token distribution has already started");
        startTime = _startTime;
    }

    function setWalletClaimable(
        address[] memory wallet,
        uint32[] memory amount1,
        uint32[] memory amount2,
        uint32[] memory amount3,
        uint32[] memory totalClaimed
    ) external onlyOwner {
        for (uint8 w = 0; w < wallet.length; w++) {
            accountBalance[wallet[w]] = Balance(
                amount1[w] + amount2[w] + amount3[w],
                amount1[w],
                amount2[w],
                amount3[w],
                uint256(totalClaimed[w]) * 10 ** 18
            );
        }
    }

    /****
     **** EXTERNAL VIEW
     ****/

    function claimableTokens(address _account) external view returns (uint256) {
        return _claimableTokens(_account);
    }

    function claimedTokens(address _account) external view returns (uint256) {
        return accountBalance[_account].totalClaimed;
    }

    function vestedTokens(address _account) external view returns (uint256) {
        return _vestedTokens(_account);
    }

    function balance(address _account) external view returns (uint256, uint256, uint256, uint256, uint256) {
        Balance memory _balance = accountBalance[_account];
        return (
            _balance.totalBought * 10 ** 18,
            _balance.totalClaimed,
            _balance.bought1 * 10 ** 18,
            _balance.bought2 * 10 ** 18,
            _balance.bought3 * 10 ** 18
        );
    }

    function lastClaimDate() external view returns (uint256) {
        if (block.timestamp < startTime) return 0;
        uint256 periodLargest = 0;
        Balance memory _balance = accountBalance[msg.sender];
        periodLargest = _getLargestPeriod(periodLargest, VESTING_PERIOD1, _balance.totalClaimed, _balance.bought1);
        periodLargest = _getLargestPeriod(periodLargest, VESTING_PERIOD2, _balance.totalClaimed, _balance.bought2);
        periodLargest = _getLargestPeriod(periodLargest, VESTING_PERIOD3, _balance.totalClaimed, _balance.bought3);
        return startTime + periodLargest;
    }

    /****
     **** PRIVATE VIEW
     ****/

    function _getLargestPeriod(
        uint256 _periodLargest,
        uint256 _period,
        uint256 _claimed,
        uint32 _bought
    ) private view returns (uint256 periodLargest) {
        uint256 timeElapsed = block.timestamp - startTime;
        if (timeElapsed > _period) {
            if (_period > _periodLargest) periodLargest = _period;
        } else {
            uint256 tmpPeriod = ((_period * _claimed) / uint256(_bought)) * timeElapsed * _period;
            if (tmpPeriod > _periodLargest) periodLargest = tmpPeriod;
        }
    }

    function _claimableTokens(address _account) private view returns (uint256 claimableAmount) {
        uint256 vestedAmount = _vestedTokens(_account);
        uint256 claimed = accountBalance[_account].totalClaimed;
        if (vestedAmount <= claimed) {
            claimableAmount = 0;
        } else {
            claimableAmount = vestedAmount - claimed;
        }
    }

    function _vestedTokens(address _account) private view returns (uint256 vestedAmount) {
        if (block.timestamp <= startTime) return 0;
        Balance memory _balance = accountBalance[_account];
        uint256 timeElapsed = block.timestamp - startTime;

        if (timeElapsed >= VESTING_PERIOD1) {
            vestedAmount += uint256(_balance.bought1) * 10 ** 18;
        } else {
            vestedAmount += (_balance.bought1 * timeElapsed * 10 ** 18) / VESTING_PERIOD1;
        }
        if (timeElapsed >= VESTING_PERIOD2) {
            vestedAmount += uint256(_balance.bought2) * 10 ** 18;
        } else {
            vestedAmount += (_balance.bought2 * timeElapsed * 10 ** 18) / VESTING_PERIOD2;
        }
        if (timeElapsed >= VESTING_PERIOD3) {
            vestedAmount += uint256(_balance.bought3) * 10 ** 18;
        } else {
            if (timeElapsed < VESTING_PERIOD3_CLIFF) {
                vestedAmount += (uint256(_balance.bought3) * 10 ** 17);
            } else {
                vestedAmount += (_balance.bought3 * timeElapsed * 10 ** 18) / VESTING_PERIOD3;
            }
        }
    }
}
