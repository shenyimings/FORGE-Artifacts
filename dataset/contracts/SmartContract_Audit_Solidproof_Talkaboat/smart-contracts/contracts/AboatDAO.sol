// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.7;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IMasterEntertainer.sol";

contract AboatDAO {
    using Address for address;
    using SafeMath for uint256;

    IMasterEntertainer _masterEntertainer;

    constructor(IMasterEntertainer masterEntertainer) {
        _masterEntertainer = masterEntertainer;
    }

    function getMasterEntertainer() public view returns (address) {
        return address(_masterEntertainer);
    }

    function getUserVotingPower(address[] memory userWallets) public view returns (uint256) {
        uint256 overallBalance = 0;
        uint256 thirtyDayBalance = 0;
        uint256 ninetyDayBalance = 0;
        uint256 halfYearBalance = 0;
        uint256 oneYearBalance = 0;
        for(uint i = 0; i < userWallets.length; i++) {
            overallBalance = overallBalance.add(_masterEntertainer.getBalanceOf(userWallets[i], 0));
            thirtyDayBalance = thirtyDayBalance.add(_masterEntertainer.getBalanceOf(userWallets[i], 30));
            ninetyDayBalance = ninetyDayBalance.add(_masterEntertainer.getBalanceOf(userWallets[i], 90));
            halfYearBalance = halfYearBalance.add(_masterEntertainer.getBalanceOf(userWallets[i], 180));
            oneYearBalance = oneYearBalance.add(_masterEntertainer.getBalanceOf(userWallets[i], 360));
        }
        return overallBalance.add(thirtyDayBalance).add(ninetyDayBalance).add(halfYearBalance).add(oneYearBalance);
    }
}