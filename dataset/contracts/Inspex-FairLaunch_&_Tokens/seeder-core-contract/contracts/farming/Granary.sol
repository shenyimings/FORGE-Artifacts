// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "../tokens/Leaf.sol";
import "../utils/SafeMath.sol";


contract Granary is OwnableUpgradeable {
    using SafeMath for uint256;

    event Keep(address indexed beneficiary, uint256 amount, uint timestamp);
    event Release(address indexed beneficiary, uint256 amount, uint timestamp);

    struct Record {
        uint createdTimestamp;
        uint releaseTimestamp;
        uint256 amount;
    }

    IERC20Upgradeable public keepToken;
    uint256 public keepPeriodInSecond;
    mapping(address => Record[]) public keepRecords;

    uint256 constant SECOND_PER_DAY = 86400;

    function initialize(IERC20Upgradeable token, uint256 keepPeriodInDay) external {
        __Ownable_init();
        
        keepToken = token;
        keepPeriodInSecond = keepPeriodInDay.mul(SECOND_PER_DAY);
    }

    function getKeepRecordSize(address beneficiary) external view returns (uint256 size) {
        size = keepRecords[beneficiary].length;
    }

    function getKeepRecords(address beneficiary) external view returns (Record[] memory records) {
        return keepRecords[beneficiary];
    }

    function getKeepBalance(address beneficiary) external view returns (uint256 keepBalance) {
        keepBalance = 0;

        for (uint256 index = 0; index < keepRecords[beneficiary].length; index ++) {
            keepBalance = keepBalance.add(keepRecords[beneficiary][index].amount);
        }      
    }

    function getReleasableBalance(address beneficiary) external view returns (uint256 releasableBalance) {
        releasableBalance = 0;

        for (uint256 index = 0; index < keepRecords[beneficiary].length; index ++) {
            Record storage record = keepRecords[beneficiary][index];
            if(record.releaseTimestamp <= block.timestamp) {
                releasableBalance = releasableBalance.add(record.amount);
            } else {
                break;
            }
        }      
    }

    function keep(address beneficiary, uint256 amount) external {
        require(beneficiary != address(0), "Cannot keep record for zero address");

        keepToken.transferFrom(msg.sender, address(this), amount);

        uint256 firstAmount = amount.div(2);
        Record memory firstRecord = Record({
            createdTimestamp: block.timestamp,
            releaseTimestamp: block.timestamp.add(keepPeriodInSecond),
            amount: firstAmount
        });

        Record memory secondRecord = Record({
            createdTimestamp: block.timestamp,
            releaseTimestamp: block.timestamp.add(keepPeriodInSecond.mul(2)),
            amount: amount.sub(firstAmount)
        });

        Record[] memory tmpRecords = keepRecords[beneficiary];
        delete keepRecords[beneficiary];

        uint256 firstLoopIndex = 0;
        for (; firstLoopIndex < tmpRecords.length; firstLoopIndex++) {
            if (tmpRecords[firstLoopIndex].releaseTimestamp <= firstRecord.releaseTimestamp) {
                keepRecords[beneficiary].push(tmpRecords[firstLoopIndex]);
            } else {
                break;
            }
        }
        keepRecords[beneficiary].push(firstRecord);

        uint256 secondLoopIndex = firstLoopIndex;
        for (; secondLoopIndex < tmpRecords.length; secondLoopIndex++) {
            if (tmpRecords[secondLoopIndex].releaseTimestamp <= secondRecord.releaseTimestamp) {
                keepRecords[beneficiary].push(tmpRecords[secondLoopIndex]);
            } else {
                break;
            }
        }
        keepRecords[beneficiary].push(secondRecord);

        uint256 thirdLoopIndex = secondLoopIndex;
        for (; thirdLoopIndex < tmpRecords.length; thirdLoopIndex++) {
            keepRecords[beneficiary].push(tmpRecords[thirdLoopIndex]);
        }

        emit Keep(beneficiary, amount, block.timestamp);
    }

    function release(address beneficiary) external {
        require(keepRecords[beneficiary].length > 0, "No keep record available");
        require(keepRecords[beneficiary][0].releaseTimestamp <= block.timestamp, "No releasable record available");

        Record[] memory existingRecords = keepRecords[beneficiary];
        delete keepRecords[beneficiary];
        uint256 releaseBalance = 0;

        for(uint256 index = 0; index < existingRecords.length; index++) {
            Record memory record = existingRecords[index];
            if(record.releaseTimestamp <= block.timestamp) {
                releaseBalance = releaseBalance.add(record.amount);
            } else {
                keepRecords[beneficiary].push(record);
            }
        }

        if(releaseBalance > 0) {
            keepToken.transfer(beneficiary, releaseBalance);
            emit Release(beneficiary, releaseBalance, block.timestamp);
        }
    }

    //================================
    // Only owner method
    //================================

    function setKeepPeriod(uint256 numberOfDay) external onlyOwner {
        keepPeriodInSecond = numberOfDay.mul(SECOND_PER_DAY);
    }
}