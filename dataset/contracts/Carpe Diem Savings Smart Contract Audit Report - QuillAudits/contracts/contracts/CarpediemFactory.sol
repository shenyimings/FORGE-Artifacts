//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Carpediem.sol";

// Created by Carpe Diem Savings and SFXDX

/// @title A factory for carpediem pools
contract CarpediemFactory is Ownable {
    address[] public allPools;
    mapping(address => address[]) public poolsByToken;

    uint256 constant private percentBase = 100;

    event NewPool(
        address indexed token,
        address poolAddress,
        uint256 initialPrice,
        uint256 bBonusAmount,
        uint256 lBonusPeriod,
        uint256 bBonusMaxPercent,
        uint256 lBonusMaxPercent
    );

    /// @notice How many pools were created by factory
    /// @return Number of pools created by factory
    function allPoolsLength() external view returns (uint256) {
        return allPools.length;
    }

    /// @notice How many pools were created by factory for token
    /// @param _token The address of token
    /// @return Number of pools created by factory for token
    function poolsByTokenLength(address _token) external view returns (uint256) {
        return poolsByToken[_token].length;
    }

    /// @notice Create a new pool (admin only)
    /// @param _token The address of token for pool
    /// @param _initialPrice The initial price of shares
    /// @param _bBonusAmount Amount of B bonus
    /// @param _lBonusPeriod Period for maximum L bonus
    /// @param _bBonusMaxPercent Maximum percent of B bonus
    /// @param _lBonusMaxPercent Maximum percent of L bonus
    /// @param _distributionPercents Commissions
    /// @param _distributionAddresses Commission recievers
    function createPool(
        address _token,
        uint256 _initialPrice,
        uint256 _bBonusAmount,
        uint256 _lBonusPeriod,
        uint256 _bBonusMaxPercent,
        uint256 _lBonusMaxPercent,
        uint16[5] memory _distributionPercents,
        address[3] memory _distributionAddresses
    ) external onlyOwner {
        require(_token != address(0), "token cannot be zero");
        require(_initialPrice != 0, "price cannot be zero");
        require(_bBonusAmount != 0, "B bonus amount cannot be zero");
        require(_lBonusPeriod != 0, "L bonus period cannot be zero");
        uint256 sum;
        for (uint256 i = 0; i < _distributionPercents.length; i++) {
            sum += _distributionPercents[i];
        }
        require(sum == percentBase, "percent sum must be == 100");
        for (uint256 i = 0; i < _distributionAddresses.length; i++) {
            require(
                _distributionAddresses[i] != address(0),
                "wallet cannot be == 0"
            );
        }
        CarpeDiem pool = new CarpeDiem(
            _token,
            [
                _initialPrice,
                _bBonusAmount,
                _lBonusPeriod,
                _bBonusMaxPercent,
                _lBonusMaxPercent
            ],
            _distributionPercents,
            _distributionAddresses
        );
        allPools.push(address(pool));
        poolsByToken[_token].push(address(pool));
        emit NewPool(
            _token,
            address(pool),
            _initialPrice,
            _bBonusAmount,
            _lBonusPeriod,
            _bBonusMaxPercent,
            _lBonusMaxPercent
        );
    }
}
