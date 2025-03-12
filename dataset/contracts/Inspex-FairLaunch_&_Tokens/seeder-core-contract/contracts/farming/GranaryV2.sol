// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
import "../tokens/Leaf.sol";
import "../utils/SafeMath.sol";
import "./GreenHouse.sol";


contract GranaryV2 is OwnableUpgradeable {
    using SafeMath for uint256;

    event Keep(address indexed beneficiary, uint256 amount);
    event Release(address indexed beneficiary, uint256 amount);
    event Fertilize(address indexed beneficiary, uint256 amount);

    struct Record {
        uint createdTimestamp;
        uint releaseTimestamp;
        uint256 amount;
    }

    IERC20Upgradeable public keepToken;
    uint256 public keepPeriodInSecond;
    mapping(address => Record[]) public keepRecords;

    uint256 constant SECOND_PER_DAY = 86400;

    // Add in V2
    GreenHouse public greenHouse;

    mapping(address => uint256) public processingIndexes1;   // Beneficiary => Next process index
    mapping(address => uint256[]) public releaseTimes1;  // Beneficiary => ReleaseDate
    mapping(address => mapping(uint256 => uint256)) public releaseAmounts1; // Beneficiary => Release Date => Release Amount

    mapping(address => uint256) public processingIndexes2;   // Beneficiary => Next process index
    mapping(address => uint256[]) public releaseTimes2;  // Beneficiary => ReleaseDate
    mapping(address => mapping(uint256 => uint256)) public releaseAmounts2; // Beneficiary => Release Date => Release Amount

    mapping(address => uint) public keepRecordNextIndex;
    
    function initialize(IERC20Upgradeable token, uint256 keepPeriodInDay) external initializer {
        __Ownable_init();
        
        keepToken = token;
        keepPeriodInSecond = keepPeriodInDay.mul(SECOND_PER_DAY);
    }

    // @notice Get number of ALL the keep records exclude fertilized and released
    function getKeepRecordSize(address beneficiary) public view returns (uint256 v1size, uint256 v2size) {
        v1size = keepRecords[beneficiary].length;

        uint256 release1Size = releaseTimes1[beneficiary].length.sub(processingIndexes1[beneficiary]);
        uint256 release2Size = releaseTimes2[beneficiary].length.sub(processingIndexes2[beneficiary]);
        v2size = release1Size.add(release2Size);
    }

    // @notice Get all keep records. The released or fertilized are not included.
    function getKeepInformations(address beneficiary) public view returns (uint256[] memory v1ReleaseTimes, uint256[] memory v1ReleaseAmounts, 
                                                                            uint256[] memory v2ReleaseTimes, uint256[] memory v2ReleaseAmounts) {
        uint256 v1Size;
        uint256 v2Size;
        (v1Size, v2Size) = getKeepRecordSize(beneficiary);
        
        v1ReleaseTimes = new uint256[](v1Size);
        v1ReleaseAmounts = new uint256[](v1Size);
        v2ReleaseTimes = new uint256[](v2Size);
        v2ReleaseAmounts = new uint256[](v2Size);

        for (uint256 v1Index = 0; v1Index < keepRecords[beneficiary].length; v1Index ++) {
            v1ReleaseTimes[v1Index] = keepRecords[beneficiary][v1Index].releaseTimestamp;
            v1ReleaseAmounts[v1Index] = keepRecords[beneficiary][v1Index].amount;
        }

        uint256 v2Index = 0;
        for (uint256 release1Index = processingIndexes1[beneficiary]; release1Index < releaseTimes1[beneficiary].length; release1Index++) {
            uint256 releaseTime = releaseTimes1[beneficiary][release1Index];
            v2ReleaseTimes[v2Index] = releaseTime.mul(SECOND_PER_DAY);
            v2ReleaseAmounts[v2Index] = releaseAmounts1[beneficiary][releaseTime];
            v2Index = v2Index + 1;
        }

        for (uint256 release2Index = processingIndexes2[beneficiary]; release2Index < releaseTimes2[beneficiary].length; release2Index++) {
            uint256 releaseTime = releaseTimes2[beneficiary][release2Index];
            v2ReleaseTimes[v2Index] = releaseTime.mul(SECOND_PER_DAY);
            v2ReleaseAmounts[v2Index] = releaseAmounts2[beneficiary][releaseTime];
            v2Index = v2Index + 1;
        }
    }

    // @notice Sum balance of records not fertilized and released yet
    function getKeepBalance(address beneficiary) external view returns (uint256 keepBalance) {
        keepBalance = 0;

        for (uint256 index = 0; index < keepRecords[beneficiary].length; index ++) {
            keepBalance = keepBalance.add(keepRecords[beneficiary][index].amount);
        }

        for (uint256 release1Index = processingIndexes1[beneficiary]; release1Index < releaseTimes1[beneficiary].length; release1Index++) {
            uint256 releaseTime = releaseTimes1[beneficiary][release1Index];
            keepBalance = keepBalance.add(releaseAmounts1[beneficiary][releaseTime]);
        }

        for (uint256 release2Index = processingIndexes2[beneficiary]; release2Index < releaseTimes2[beneficiary].length; release2Index++) {
            uint256 releaseTime = releaseTimes2[beneficiary][release2Index];
            keepBalance = keepBalance.add(releaseAmounts2[beneficiary][releaseTime]);
        }
    }

    // @notice Send the amount to keep in Granary
    function keep(address beneficiary, uint256 amount) external {
        require(beneficiary != address(0), "Cannot keep record for zero address");

        keepToken.transferFrom(msg.sender, address(this), amount);

        uint256 releaseTime1 = block.timestamp.add(keepPeriodInSecond).div(SECOND_PER_DAY);
        uint256 releaseTime2 = block.timestamp.add(keepPeriodInSecond.mul(2)).div(SECOND_PER_DAY);

        uint256 amount1 = amount.div(2);
        uint256 amount2 = amount.sub(amount1);

        // Add release time and amount for 1st keep record
        uint256 processingIndex1 = processingIndexes1[beneficiary];
        uint256[] storage ownerReleaseTimes1 = releaseTimes1[beneficiary];
        if (ownerReleaseTimes1.length == 0 ||  
                processingIndex1 >= ownerReleaseTimes1.length || 
                ownerReleaseTimes1[ownerReleaseTimes1.length - 1] != releaseTime1) {
            releaseTimes1[beneficiary].push(releaseTime1);
        }
        releaseAmounts1[beneficiary][releaseTime1] = releaseAmounts1[beneficiary][releaseTime1].add(amount1);

        // Add release time and amount for 2nd keep record
        uint256 processingIndex2 = processingIndexes2[beneficiary];
        uint256[] storage ownerReleaseTimes2 = releaseTimes2[beneficiary];
        if (ownerReleaseTimes2.length == 0 ||  
                processingIndex2 >= ownerReleaseTimes2.length || 
                ownerReleaseTimes2[ownerReleaseTimes2.length - 1] != releaseTime2) {
            releaseTimes2[beneficiary].push(releaseTime2);
        }
        releaseAmounts2[beneficiary][releaseTime2] = releaseAmounts2[beneficiary][releaseTime2].add(amount2);

        emit Keep(beneficiary, amount);
    }

    function release(uint256[] calldata releaseV1Items) external {
        address beneficiary = msg.sender;
        uint256 releaseBalance = 0;

        // V1
        for (uint256 index = 0; index < releaseV1Items.length; index++) {
            uint256 itemIndex = releaseV1Items[index];
            Record storage record = keepRecords[beneficiary][itemIndex];

            require(block.timestamp >= record.releaseTimestamp, "Granary: Release too early");
            releaseBalance = releaseBalance.add(record.amount);

            delete keepRecords[beneficiary][itemIndex];
        }

        // V2
        uint256 currentTime = block.timestamp.div(SECOND_PER_DAY);
        for (uint256 index = processingIndexes1[beneficiary]; index < releaseTimes1[beneficiary].length; index++) {
            uint256 releaseTime = releaseTimes1[beneficiary][index];
            if (currentTime >= releaseTime) {
                releaseBalance = releaseBalance.add(releaseAmounts1[beneficiary][releaseTime]);
                processingIndexes1[beneficiary] = processingIndexes1[beneficiary] + 1;
                delete releaseAmounts1[beneficiary][releaseTime];
            } else {
                break;
            }
        }

        for (uint256 index = processingIndexes2[beneficiary]; index < releaseTimes2[beneficiary].length; index++) {
            uint256 releaseTime = releaseTimes2[beneficiary][index];
            if (currentTime >= releaseTime) {
                releaseBalance = releaseBalance.add(releaseAmounts2[beneficiary][releaseTime]);
                processingIndexes2[beneficiary] = processingIndexes2[beneficiary] + 1;
                delete releaseAmounts2[beneficiary][releaseTime];
            } else {
                break;
            }
        }

        // Release balance
        require(releaseBalance > 0, "GranaryV2: No balance to be released");
        keepToken.transfer(beneficiary, releaseBalance);
        emit Release(beneficiary, releaseBalance);
    }

    function fertilize(uint256[] calldata fertilizeV1Items, uint256 v2UntilTimestamp) external {
        address beneficiary = msg.sender;
        uint256 plantBalance = 0;

        // V1
        for (uint256 index = 0; index < fertilizeV1Items.length; index++) {
            uint256 itemIndex = fertilizeV1Items[index];
            Record storage record = keepRecords[beneficiary][itemIndex];

            plantBalance = plantBalance.add(record.amount);

            delete keepRecords[beneficiary][itemIndex];
        }

        // V2
        uint256 requestTime = v2UntilTimestamp.div(SECOND_PER_DAY);
        for (uint256 index = processingIndexes1[beneficiary]; index < releaseTimes1[beneficiary].length; index++) {
            uint256 releaseTime = releaseTimes1[beneficiary][index];
            if (requestTime >= releaseTime) {
                plantBalance = plantBalance.add(releaseAmounts1[beneficiary][releaseTime]);
                processingIndexes1[beneficiary] = processingIndexes1[beneficiary] + 1;
                delete releaseAmounts1[beneficiary][releaseTime];
            } else {
                break;
            }
        }

        for (uint256 index = processingIndexes2[beneficiary]; index < releaseTimes2[beneficiary].length; index++) {
            uint256 releaseTime = releaseTimes2[beneficiary][index];
            if (requestTime >= releaseTime) {
                plantBalance = plantBalance.add(releaseAmounts2[beneficiary][releaseTime]);
                processingIndexes2[beneficiary] = processingIndexes2[beneficiary] + 1;
                delete releaseAmounts2[beneficiary][releaseTime];
            } else {
                break;
            }
        }

        // Plant
        require(plantBalance > 0, "GranaryV2: No balance to be planted");
        keepToken.approve(address(greenHouse), plantBalance);
        greenHouse.plant(beneficiary, plantBalance);
        emit Fertilize(beneficiary, plantBalance);
    }

    //================================
    // Only owner method
    //================================

    function setKeepPeriod(uint256 numberOfDay) external onlyOwner {
        keepPeriodInSecond = numberOfDay.mul(SECOND_PER_DAY);
    }

    function registerGreenHouse(GreenHouse greenHouseAddr) external onlyOwner {
        greenHouse = greenHouseAddr;
    }
}