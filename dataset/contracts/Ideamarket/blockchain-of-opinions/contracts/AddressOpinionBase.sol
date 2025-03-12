//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./interfaces/IAddressOpinionBase.sol";
import "./interfaces/IArbSys.sol";

/**
 * @title AddressOpinionBase
 * @author Kelton Madden
 *
 * @dev Stores and retrieves opinions
 */

contract AddressOpinionBase is IAddressOpinionBase {

    // address => user wallet address => the opinions they have made about that address
    mapping(address => mapping(address => Opinion[])) _userOpinions;

    // wallet address => all opinions made by that address
    mapping(address => Opinion[]) _totalUserOpinions;

    // address => all opinions for a given given address
    mapping(address => Opinion[]) _opinions;

    // address => address[] of users who have made opinions about that address
    mapping(address => address[]) _opinionatorList;

    // address array storing all addresses about which opinions have been made
    address[] _opinionedAddresses;

    uint _totalOpinionNumber;

    IArbSys constant _arbSys = IArbSys(address(100));
    
    event NewOpinion(address addy, address user, uint8 rating, string comment);
    
    function writeOpinion(address addy, uint8 rating, string calldata comment) external override {
        require(rating != 50, "rating must not be 50");
        require(bytes(comment).length <= 10000, "comment must be lte 10000 characters");
        uint blockHeight = _arbSys.arbBlockNumber();
        Opinion memory opinion = Opinion(msg.sender, addy, rating, comment, blockHeight);
        _userOpinions[addy][msg.sender].push(opinion);
        _totalUserOpinions[msg.sender].push(opinion);

        if (_opinions[addy].length == 0) {
            _opinionedAddresses.push(addy);
        }
        _opinions[addy].push(opinion);

        if (_userOpinions[addy][msg.sender].length == 1) {
            _opinionatorList[addy].push(msg.sender);
        }

        _totalOpinionNumber++;
        emit NewOpinion(addy, msg.sender, rating, comment);
    }

    function getOpinion(address addy, address user) external view override returns (Opinion[] memory) {
        return _userOpinions[addy][user];
    }

    function getUsersOpinions(address user) external view override returns (Opinion[] memory) {
        return _totalUserOpinions[user];
    }

    function getOpinionsAboutAddress(address addy) external view override returns (Opinion[] memory) {
        return _opinions[addy];
    }

    function getLatestOpinionsAboutAddress(address addy) external view override returns (Opinion[] memory) {
        Opinion[] memory latestOpinions = new Opinion[](_opinionatorList[addy].length);

        for (uint i = 0; i < _opinionatorList[addy].length; i++) {
            uint latestOpinionIndex = _userOpinions[addy][_opinionatorList[addy][i]].length - 1;
            latestOpinions[i] = _userOpinions[addy][_opinionatorList[addy][i]][latestOpinionIndex];
        }
        return latestOpinions;
    }

    function getOpinionedAddresses() external view override returns (address[] memory) {
        return _opinionedAddresses;
    }
    
    function getAllOpinions() external view override returns (Opinion[] memory) {
        Opinion[] memory allOpinions = new Opinion[](_totalOpinionNumber);
        uint k;
        for (uint i = 0; i < _opinionedAddresses.length; i++) {
            for (uint j = 0; j < _opinions[_opinionedAddresses[i]].length; j++) {
                allOpinions[k] = _opinions[_opinionedAddresses[i]][j];
                k++;
            }
        }
        return allOpinions;
    }

}