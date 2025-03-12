// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../tokens/Tree.sol";
import "../utils/SafeMath.sol";


contract GreenHouse is OwnableUpgradeable {
    using SafeMath for uint256;

    event Planted(address beneficiary, uint256 fertilizedToken, uint256 tree);

    IERC20Upgradeable public fertilizedToken;
    address public granary;
    Tree public tree;

    uint256 public fertilizedTokenPerTree;
    mapping(address => uint256) public plantAccumulated;

    modifier onlyGranary() {
        require(msg.sender == granary, "GreenHouse: Caller is not Granary");
        _;
    }

    function initialize(address granary_, IERC20Upgradeable fertilizedToken_, Tree tree_, uint256 fertilizedTokenPerTree_) external initializer {
        __Ownable_init();

        granary = granary_;
        fertilizedToken = fertilizedToken_;
        tree = tree_;

        setFertilizedTokenAndTreeRatio(fertilizedTokenPerTree_);
    }

    function plant(address beneficiary, uint256 fertilizedAmount) external onlyGranary {
        require(beneficiary != address(0), "GreenHouse: Cannot plant for zero address");
        require(fertilizedAmount >= fertilizedTokenPerTree, "GreenHouse: Cannot plant for zero tree");

        uint256 treeAmount = fertilizedAmount.div(fertilizedTokenPerTree);

        fertilizedToken.transferFrom(msg.sender, address(this), fertilizedAmount);
        tree.mint(beneficiary, treeAmount);
        plantAccumulated[beneficiary] = plantAccumulated[beneficiary].add(fertilizedAmount);

        emit Planted(beneficiary, fertilizedAmount, treeAmount);
    }

    function getTotalFertilizedToken() external view returns (uint256 totalFertilizedToken) {
        return fertilizedToken.balanceOf(address(this));
    }

    //================================
    // Only owner method
    //================================

    function setFertilizedTokenAndTreeRatio(uint256 fertilizedTokenPerTree_) public onlyOwner {
        fertilizedTokenPerTree = fertilizedTokenPerTree_;
    }
}